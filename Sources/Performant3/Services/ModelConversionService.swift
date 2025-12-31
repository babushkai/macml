import Foundation

// MARK: - Conversion Configuration

struct ConversionConfig {
    let inputPath: URL
    let outputPath: URL
    let targetFormat: ConversionFormat
    let inputShape: [Int]
    let modelName: String

    var inputShapeString: String {
        inputShape.map(String.init).joined(separator: ",")
    }
}

enum ConversionFormat: String, CaseIterable, Identifiable {
    case coreml = "coreml"
    case mlx = "mlx"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coreml: return "Core ML"
        case .mlx: return "MLX"
        }
    }

    var fileExtension: String {
        switch self {
        case .coreml: return "mlpackage"
        case .mlx: return "safetensors"
        }
    }

    var framework: MLFramework {
        switch self {
        case .coreml: return .coreML
        case .mlx: return .mlx
        }
    }

    var description: String {
        switch self {
        case .coreml: return "Apple's Core ML format, optimized for Vision framework"
        case .mlx: return "MLX safetensors format for Apple Silicon"
        }
    }
}

// MARK: - Input Shape Presets

enum InputShapePreset: String, CaseIterable, Identifiable {
    case image224 = "224×224"
    case image384 = "384×384"
    case image640 = "640×640"
    case grayscale28 = "28×28 (Grayscale)"
    case custom = "Custom"

    var id: String { rawValue }

    var shape: [Int]? {
        switch self {
        case .image224: return [1, 3, 224, 224]
        case .image384: return [1, 3, 384, 384]
        case .image640: return [1, 3, 640, 640]
        case .grayscale28: return [1, 1, 28, 28]
        case .custom: return nil
        }
    }

    var description: String {
        switch self {
        case .image224: return "Standard for ResNet, VGG, etc."
        case .image384: return "Higher resolution models"
        case .image640: return "YOLO and detection models"
        case .grayscale28: return "MNIST and similar"
        case .custom: return "Specify custom dimensions"
        }
    }
}

// MARK: - Conversion Events

enum ConversionEvent {
    case log(level: String, message: String)
    case progress(percent: Double, step: String)
    case completed(outputPath: String, format: String, metadata: [String: Any])
    case error(message: String, code: String)
}

// MARK: - Conversion Service

actor ModelConversionService {
    static let shared = ModelConversionService()

    private let pythonEnv = PythonEnvironmentManager.shared
    private var currentTask: Task<MLModel, Error>?
    private var isCancelled = false

    // Required packages for conversion
    private let conversionPackages = ["coremltools", "safetensors"]

    // MARK: - Public API

    /// Convert a PyTorch model to CoreML or MLX format
    func convert(
        config: ConversionConfig,
        progressHandler: @escaping @Sendable (Double, String) -> Void
    ) async throws -> MLModel {
        isCancelled = false

        // Step 1: Ensure Python environment has required packages
        progressHandler(0.05, "Checking Python environment...")
        try await ensureConversionPackages(progressHandler: progressHandler)

        if isCancelled { throw ConversionError.cancelled }

        // Step 2: Locate conversion script
        guard let scriptPath = findConversionScript() else {
            throw ConversionError.scriptNotFound
        }

        // Step 3: Build arguments
        let pythonPath = await pythonEnv.pythonPath
        let arguments = [
            scriptPath,
            "--input", config.inputPath.path,
            "--output", config.outputPath.path,
            "--format", config.targetFormat.rawValue,
            "--input-shape", config.inputShapeString,
            "--name", config.modelName
        ]

        progressHandler(0.1, "Starting conversion...")

        // Step 4: Execute conversion script
        var conversionMetadata: [String: Any] = [:]
        var errorMessage: String?
        var errorCode: String?

        // Create process manually to parse conversion-specific events
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [pythonPath] + arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment

        try process.run()

        // Read stdout in background
        let stdoutHandle = stdoutPipe.fileHandleForReading

        await withTaskGroup(of: Void.self) { group in
            // Stdout reader - parse JSON events
            group.addTask {
                var buffer = Data()

                while true {
                    let availableData = stdoutHandle.availableData
                    if availableData.isEmpty { break }

                    buffer.append(availableData)

                    // Process complete lines
                    while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                        buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                        // Parse as conversion event
                        if let event = self.parseConversionEvent(from: lineData) {
                            switch event {
                            case .progress(let percent, let step):
                                // Scale progress from script (0.1-1.0) to overall (0.1-0.95)
                                let scaledProgress = 0.1 + (percent * 0.85)
                                progressHandler(scaledProgress, step)
                            case .log(let level, let message):
                                if level == "info" {
                                    progressHandler(-1, message) // -1 means don't update progress
                                }
                                print("[Performant3] [\(level)] \(message)")
                            case .completed(_, _, let metadata):
                                conversionMetadata = metadata
                            case .error(let message, let code):
                                errorMessage = message
                                errorCode = code
                            }
                        }
                    }
                }
            }

            // Stderr reader
            group.addTask {
                let stderrHandle = stderrPipe.fileHandleForReading
                while true {
                    let data = stderrHandle.availableData
                    if data.isEmpty { break }
                    if let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !line.isEmpty {
                        print("[Performant3] [stderr] \(line)")
                    }
                }
            }
        }

        // Wait for process to complete
        process.waitUntilExit()

        if isCancelled {
            throw ConversionError.cancelled
        }

        let exitCode = process.terminationStatus
        if exitCode != 0 {
            if let msg = errorMessage, let code = errorCode {
                throw ConversionError.conversionFailed(message: msg, code: code)
            }
            throw ConversionError.scriptFailed(exitCode: Int(exitCode))
        }

        progressHandler(0.98, "Finalizing...")

        // Step 5: Create MLModel entry
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: config.outputPath.path)[.size] as? Int64) ?? 0

        var metadata: [String: String] = [
            "sourceFormat": "pytorch",
            "inputShape": config.inputShapeString
        ]

        // Add architecture type from conversion metadata
        if let archType = conversionMetadata["architectureType"] as? String {
            metadata["architectureType"] = archType
        }

        if let layerCount = conversionMetadata["layerCount"] as? Int {
            metadata["layerCount"] = String(layerCount)
        }

        if let totalParams = conversionMetadata["totalParameters"] as? Int {
            metadata["totalParameters"] = String(totalParams)
        }

        let model = MLModel(
            name: config.modelName,
            framework: config.targetFormat.framework,
            status: .ready,
            fileSize: fileSize,
            filePath: config.outputPath.path,
            metadata: metadata
        )

        progressHandler(1.0, "Complete")

        return model
    }

    /// Cancel ongoing conversion
    func cancel() {
        isCancelled = true
        currentTask?.cancel()
    }

    // MARK: - Private Methods

    private nonisolated func parseConversionEvent(from data: Data) -> ConversionEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        switch type {
        case "log":
            guard let level = json["level"] as? String,
                  let message = json["message"] as? String else { return nil }
            return .log(level: level, message: message)

        case "progress":
            guard let percent = json["percent"] as? Double,
                  let step = json["step"] as? String else { return nil }
            return .progress(percent: percent, step: step)

        case "completed":
            guard let outputPath = json["outputPath"] as? String,
                  let format = json["format"] as? String else { return nil }
            let metadata = json["metadata"] as? [String: Any] ?? [:]
            return .completed(outputPath: outputPath, format: format, metadata: metadata)

        case "error":
            guard let message = json["message"] as? String else { return nil }
            let code = json["code"] as? String ?? "UNKNOWN"
            return .error(message: message, code: code)

        default:
            return nil
        }
    }

    private func ensureConversionPackages(progressHandler: @escaping @Sendable (Double, String) -> Void) async throws {
        // Check if packages are installed
        let installedPackages = await pythonEnv.getPackageVersions()

        var missingPackages: [String] = []
        for package in conversionPackages {
            if installedPackages[package.lowercased()] == nil {
                missingPackages.append(package)
            }
        }

        if !missingPackages.isEmpty {
            progressHandler(0.02, "Installing \(missingPackages.joined(separator: ", "))...")

            // Install missing packages
            for package in missingPackages {
                try await installPackage(package)
            }
        }
    }

    private func installPackage(_ package: String) async throws {
        let pipPath = await pythonEnv.pipPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pipPath)
        process.arguments = ["install", package]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice // Suppress output

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ConversionError.packageInstallFailed(package: package, message: errorMessage)
        }
    }

    private func findConversionScript() -> String? {
        let possiblePaths: [String?] = [
            Bundle.main.url(forResource: "convert_pytorch", withExtension: "py", subdirectory: "Scripts")?.path,
            Bundle.main.resourceURL?.appendingPathComponent("Scripts/convert_pytorch.py").path,
            // Development fallback
            FileManager.default.currentDirectoryPath + "/Resources/Scripts/convert_pytorch.py",
            // Absolute fallback for development
            "/Users/dsuke/Projects/dev/peformant3/Resources/Scripts/convert_pytorch.py"
        ]

        return possiblePaths.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0) }
    }
}

// MARK: - Errors

enum ConversionError: Error, LocalizedError {
    case scriptNotFound
    case pythonEnvironmentNotReady
    case packageInstallFailed(package: String, message: String)
    case conversionFailed(message: String, code: String)
    case scriptFailed(exitCode: Int)
    case unsupportedModel(reason: String)
    case invalidInputShape
    case cancelled

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "Conversion script not found. Please reinstall the application."
        case .pythonEnvironmentNotReady:
            return "Python environment is not ready. Please check settings."
        case .packageInstallFailed(let package, let message):
            return "Failed to install \(package): \(message)"
        case .conversionFailed(let message, let code):
            return "Conversion failed (\(code)): \(message)"
        case .scriptFailed(let exitCode):
            return "Conversion script failed with exit code \(exitCode)"
        case .unsupportedModel(let reason):
            return "This model cannot be converted: \(reason)"
        case .invalidInputShape:
            return "Invalid input shape specified"
        case .cancelled:
            return "Conversion was cancelled"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .conversionFailed(_, let code):
            switch code {
            case "STATE_DICT_ONLY":
                return "Try using MLX format instead, which can handle state_dict checkpoints."
            case "UNSUPPORTED_OP":
                return "This model uses operations not supported by Core ML. Try MLX format."
            case "SHAPE_MISMATCH":
                return "Check the input shape matches what the model expects."
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

// MARK: - File Type Detection

extension URL {
    var isPyTorchModel: Bool {
        let ext = pathExtension.lowercased()
        return ext == "pt" || ext == "pth"
    }
}
