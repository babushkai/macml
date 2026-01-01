import Foundation
import MLX
import MLXNN
import AppKit
import os.log

private let inferenceLogger = Logger(subsystem: "com.performant3", category: "Inference")

// Helper to log to both console and file
private func debugLog(_ message: String) {
    inferenceLogger.info("\(message)")
    // Also write to file for easy access
    let logFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Performant3/inference_debug.log")
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logLine = "[\(timestamp)] \(message)\n"
    if let data = logLine.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFile)
        }
    }
}


// MARK: - MLX Inference Service

/// Service for running inference on trained MLX models
actor MLXInferenceService {
    static let shared = MLXInferenceService()

    private var loadedModels: [String: Module] = [:]
    private var modelClassLabels: [String: [String]] = [:]
    private let checkpointManager = CheckpointManager.shared

    // MARK: - Inference

    func runInference(model: MLModel, imageURL: URL) async throws -> InferenceResult {
        let startTime = Date()

        debugLog("[Inference] Starting inference for model: \(model.name)")
        debugLog("[Inference] Model ID: \(model.id)")
        debugLog("[Inference] Model file path: \(model.filePath ?? "nil")")
        debugLog("[Inference] Model metadata: \(model.metadata)")

        // Load the model if not already loaded
        let mlxModel = try await loadModel(model)
        debugLog("[Inference] Model loaded: \(type(of: mlxModel))")

        // Get class labels for this model
        let classLabels = getClassLabels(for: model)
        debugLog("[Inference] Class labels: \(classLabels)")

        // Load and preprocess the image
        let inputArray = try preprocessImage(at: imageURL, for: model)
        debugLog("[Inference] Input array shape: \(inputArray.shape)")

        // Run forward pass
        let logits = forwardPass(model: mlxModel, inputs: inputArray, training: false)
        eval(logits)
        debugLog("[Inference] Logits shape: \(logits.shape)")

        // Debug: Print raw logits values
        let logitsFlat = logits.reshaped([-1])
        var logitsValues: [Float] = []
        for i in 0..<min(10, logitsFlat.dim(0)) {
            logitsValues.append(logitsFlat[i].item(Float.self))
        }
        debugLog("[Inference] Raw logits: \(logitsValues.map { String(format: "%.3f", $0) }.joined(separator: ", "))")

        // Debug: Check if all logits are similar (indicates model not learning/wrong weights)
        let logitsMax = logitsValues.max() ?? 0
        let logitsMin = logitsValues.min() ?? 0
        debugLog("[Inference] Logits range: [\(String(format: "%.3f", logitsMin)), \(String(format: "%.3f", logitsMax))], spread: \(String(format: "%.3f", logitsMax - logitsMin))")

        // Get predictions with real class labels
        let predictions = extractPredictions(from: logits, classLabels: classLabels)

        let inferenceTime = Date().timeIntervalSince(startTime) * 1000 // ms

        return InferenceResult(
            id: UUID().uuidString,
            requestId: UUID().uuidString,
            modelId: model.id,
            predictions: predictions,
            inferenceTimeMs: inferenceTime,
            timestamp: Date()
        )
    }

    /// Get class labels from model metadata
    private func getClassLabels(for model: MLModel) -> [String] {
        // Try cached labels first
        if let cached = modelClassLabels[model.id] {
            return cached
        }

        // Try to load from model metadata
        if let labelsJson = model.metadata["classLabels"],
           let labelsData = labelsJson.data(using: .utf8),
           let labels = try? JSONDecoder().decode([String].self, from: labelsData) {
            modelClassLabels[model.id] = labels
            return labels
        }

        // Fallback to generic labels based on numClasses
        let numClasses = Int(model.metadata["numClasses"] ?? "10") ?? 10
        let fallbackLabels = (0..<numClasses).map { "Class \($0)" }
        return fallbackLabels
    }

    // MARK: - Model Loading

    private func loadModel(_ model: MLModel) async throws -> Module {
        // Return cached model if available
        if let cached = loadedModels[model.id] {
            return cached
        }

        guard let filePath = model.filePath else {
            throw MLXInferenceError.modelNotFound(model.name)
        }

        // Determine model architecture from metadata
        let modelArchitecture = getModelArchitecture(for: model)
        let mlxModel = try ModelFactory.create(from: modelArchitecture)

        // Load weights from checkpoint
        let checkpointURL = URL(fileURLWithPath: filePath)
        let loadedArrays = try MLX.loadArrays(url: checkpointURL)

        // Update model parameters - need to unflatten dot-separated keys
        // When saving, flattened() creates keys like "layers.0.weight"
        // We need to parse these back into nested structure for update()
        var flatParams: [String: MLXArray] = [:]
        for (key, array) in loadedArrays {
            flatParams[key] = array
        }

        // Debug: Print loaded parameter keys and shapes
        debugLog("[Inference] Loaded \(loadedArrays.count) parameter arrays:")
        for (key, array) in loadedArrays.sorted(by: { $0.key < $1.key }).prefix(5) {
            debugLog("[Inference]   \(key): shape \(array.shape)")
        }
        if loadedArrays.count > 5 {
            debugLog("[Inference]   ... and \(loadedArrays.count - 5) more")
        }

        // Use MLX's unflattened to convert flat dict to nested structure
        let nestedParams = NestedDictionary<String, MLXArray>.unflattened(flatParams)
        mlxModel.update(parameters: nestedParams)

        // Debug: Verify model parameters were updated
        let modelParams = mlxModel.parameters()
        let verifyParams = modelParams.flattened()
        debugLog("[Inference] Model now has \(verifyParams.count) parameter tensors after update")

        // Cache the model
        loadedModels[model.id] = mlxModel

        return mlxModel
    }

    /// Get model architecture from metadata
    private func getModelArchitecture(for model: MLModel) -> ModelArchitecture {
        guard let archType = model.metadata["architectureType"] else {
            return .defaultMLP
        }

        switch archType {
        case "MLP":
            return .defaultMLP
        case "CNN":
            return .defaultCNN
        case "ResNet":
            return .defaultResNet
        case "Transformer":
            return .defaultTransformer
        default:
            return .defaultMLP
        }
    }

    // MARK: - Image Preprocessing

    private func preprocessImage(at url: URL, for model: MLModel) throws -> MLXArray {
        guard let image = NSImage(contentsOf: url) else {
            throw MLXInferenceError.imageLoadFailed
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw MLXInferenceError.imageLoadFailed
        }

        debugLog("[Inference] Original image size: \(cgImage.width)x\(cgImage.height)")

        // Determine target size based on architecture
        let archType = model.metadata["architectureType"] ?? "MLP"
        debugLog("[Inference] Architecture type: \(archType)")
        let targetSize: Int
        switch archType {
        case "CNN":
            targetSize = 28
        case "ResNet":
            targetSize = 28
        case "Transformer":
            targetSize = 28
        default:
            targetSize = 28
        }

        let resizedImage = resizeImage(cgImage, to: CGSize(width: targetSize, height: targetSize))

        // Convert to grayscale float array
        let pixelData = getPixelData(from: resizedImage)

        // Calculate average pixel value from CENTER region (to ignore borders/axes)
        // Use center 14x14 region (50% of image) to determine inversion
        let centerSize = 14
        let startOffset = (targetSize - centerSize) / 2  // Start at pixel 7
        var centerSum = 0
        var centerCount = 0
        for row in startOffset..<(startOffset + centerSize) {
            for col in startOffset..<(startOffset + centerSize) {
                let idx = row * targetSize + col
                centerSum += Int(pixelData[idx])
                centerCount += 1
            }
        }
        let centerAvgPixel = centerSum / max(centerCount, 1)

        // Also calculate overall average for logging
        let overallAvgPixel = pixelData.reduce(0) { $0 + Int($1) } / max(pixelData.count, 1)
        debugLog("[Inference] Overall average pixel (0-255): \(overallAvgPixel)")
        debugLog("[Inference] Center region average pixel (0-255): \(centerAvgPixel)")

        // IMPORTANT: MNIST has white digits on black background (high values = digit)
        // Use CENTER average to decide inversion (avoids being fooled by borders)
        // If center average > 127, the center background is likely white, so we invert
        let shouldInvert = centerAvgPixel > 127
        debugLog("[Inference] Should invert: \(shouldInvert) (centerAvgPixel > 127)")

        let mean: Float = 0.1307
        let std: Float = 0.3081
        let normalizedData = pixelData.map { pixel -> Float in
            var value = Float(pixel) / 255.0
            if shouldInvert {
                value = 1.0 - value  // Invert for MNIST format
            }
            return (value - mean) / std  // Same normalization as training
        }

        // Debug: Print min/max of normalized values
        let minVal = normalizedData.min() ?? 0
        let maxVal = normalizedData.max() ?? 0
        debugLog("[Inference] Normalized range: [\(minVal), \(maxVal)]")

        // Debug: Print a sample of the normalized values (center of image)
        let centerStart = (14 * 28 + 10)  // Row 14, starting at column 10
        let centerValues = Array(normalizedData[centerStart..<min(centerStart+8, normalizedData.count)])
        debugLog("[Inference] Center row sample (normalized): \(centerValues.map { String(format: "%.2f", $0) }.joined(separator: ", "))")

        // Debug: Check non-zero pixels (after normalization, background ~= -0.42, digit ~= 2.82)
        let significantPixels = normalizedData.filter { $0 > 0.5 }.count
        debugLog("[Inference] Pixels with value > 0.5 (likely digit): \(significantPixels) / \(normalizedData.count)")

        // Create MLXArray with shape [batch, height, width, channels] to match training
        return MLXArray(normalizedData).reshaped([1, targetSize, targetSize, 1])
    }

    private func resizeImage(_ image: CGImage, to size: CGSize) -> CGImage {
        let targetColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: targetColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            // Fallback: return original image if context creation fails
            return image
        }

        // Clear the context with black background
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))

        context.interpolationQuality = .high

        // Flip the context to match MNIST coordinate system (origin at top-left)
        // CGContext has origin at bottom-left by default, which would flip the image
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        // Draw the image - Core Graphics will handle color space conversion automatically
        context.draw(image, in: CGRect(origin: .zero, size: size))

        guard let resizedImage = context.makeImage() else {
            // Fallback: return original image if makeImage fails
            return image
        }
        
        return resizedImage
    }

    private func getPixelData(from image: CGImage) -> [UInt8] {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert RGBA to grayscale
        var grayscale = [UInt8]()
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = Float(pixelData[i])
            let g = Float(pixelData[i + 1])
            let b = Float(pixelData[i + 2])
            let gray = UInt8(0.299 * r + 0.587 * g + 0.114 * b)
            grayscale.append(gray)
        }

        return grayscale
    }

    // MARK: - Prediction Extraction

    private func extractPredictions(from logits: MLXArray, classLabels: [String]) -> [Prediction] {
        // Apply softmax to get probabilities
        let maxLogit = logits.max(axis: -1, keepDims: true)
        let expLogits = exp(logits - maxLogit)
        let sumExp = expLogits.sum(axis: -1, keepDims: true)
        let probabilities = expLogits / sumExp
        eval(probabilities)

        // Get number of classes
        let numClasses = logits.dim(-1)

        // Extract all predictions with real class labels
        var predictions: [Prediction] = []
        let probsFlat = probabilities.reshaped([-1])

        for i in 0..<numClasses {
            let prob = probsFlat[i].item(Float.self)
            let label = i < classLabels.count ? classLabels[i] : "Class \(i)"
            predictions.append(Prediction(
                label: label,
                confidence: Double(prob)
            ))
        }

        // Sort by confidence (highest first)
        predictions.sort { $0.confidence > $1.confidence }

        // Return top 5 predictions
        return Array(predictions.prefix(5))
    }

    // MARK: - Cache Management

    func clearCache() {
        loadedModels.removeAll()
    }

    func unloadModel(_ modelId: String) {
        loadedModels.removeValue(forKey: modelId)
    }
}

// MARK: - Errors

enum MLXInferenceError: Error, LocalizedError {
    case modelNotFound(String)
    case imageLoadFailed
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model '\(name)' not found or has no weights file"
        case .imageLoadFailed:
            return "Failed to load or process the input image"
        case .inferenceFailed(let reason):
            return "Inference failed: \(reason)"
        }
    }
}
