import Foundation
import MLX
import MLXRandom
import AppKit
import Compression

// MARK: - MLX Dataset Protocol

/// Protocol for datasets that can be used with MLX training
protocol MLXDataset: Sendable {
    /// Total number of samples
    var count: Int { get }

    /// Number of classes for classification
    var numClasses: Int { get }

    /// Class labels
    var classLabels: [String] { get }

    /// Input shape (e.g., [28, 28, 1] for MNIST)
    var inputShape: [Int] { get }

    /// Get a batch of samples
    func getBatch(indices: [Int]) -> (inputs: MLXArray, labels: MLXArray)

    /// Generate batches for an epoch
    func batches(batchSize: Int, shuffle: Bool) -> BatchIterator
}

// MARK: - Batch Iterator

/// Iterator for generating batches
struct BatchIterator: Sequence, IteratorProtocol {
    private let dataset: any MLXDataset
    private let batchSize: Int
    private var indices: [Int]
    private var currentIndex: Int = 0

    init(dataset: any MLXDataset, batchSize: Int, shuffle: Bool) {
        self.dataset = dataset
        self.batchSize = batchSize
        self.indices = Array(0..<dataset.count)
        if shuffle {
            self.indices.shuffle()
        }
    }

    var totalBatches: Int {
        (indices.count + batchSize - 1) / batchSize
    }

    mutating func next() -> (inputs: MLXArray, labels: MLXArray, batchIndex: Int)? {
        guard currentIndex < indices.count else { return nil }

        let batchEnd = Swift.min(currentIndex + batchSize, indices.count)
        let batchIndices = Array(indices[currentIndex..<batchEnd])
        let batch = dataset.getBatch(indices: batchIndices)
        let batchIdx = currentIndex / batchSize

        currentIndex = batchEnd
        return (batch.inputs, batch.labels, batchIdx)
    }
}

// MARK: - Image Classification Dataset

/// Dataset for image classification from folder structure
/// Expected structure: root/class1/image1.jpg, root/class2/image2.jpg, etc.
final class ImageClassificationDataset: MLXDataset, @unchecked Sendable {
    let rootPath: String
    let classLabels: [String]
    let imagePaths: [(path: String, label: Int)]
    let imageSize: Int
    let channels: Int

    var count: Int { imagePaths.count }
    var numClasses: Int { classLabels.count }
    var inputShape: [Int] { [imageSize, imageSize, channels] }

    init(rootPath: String, imageSize: Int = 28, channels: Int = 1) throws {
        self.rootPath = rootPath
        self.imageSize = imageSize
        self.channels = channels

        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: rootPath)

        // Discover class directories
        var classes: [String] = []
        var paths: [(String, Int)] = []

        let contents = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey])

        for item in contents {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                let className = item.lastPathComponent
                if !className.hasPrefix(".") {
                    classes.append(className)
                }
            }
        }

        classes.sort()
        self.classLabels = classes

        // Collect image paths
        for (labelIdx, className) in classes.enumerated() {
            let classDir = rootURL.appendingPathComponent(className)
            if let files = try? fileManager.contentsOfDirectory(at: classDir, includingPropertiesForKeys: nil) {
                for file in files {
                    let ext = file.pathExtension.lowercased()
                    if ["jpg", "jpeg", "png", "bmp", "gif"].contains(ext) {
                        paths.append((file.path, labelIdx))
                    }
                }
            }
        }

        self.imagePaths = paths

        if paths.isEmpty {
            throw TrainingError.invalidDataset("No images found in dataset")
        }
    }

    func getBatch(indices: [Int]) -> (inputs: MLXArray, labels: MLXArray) {
        var imageData: [[Float]] = []
        var labelData: [Int32] = []

        for idx in indices {
            let (path, label) = imagePaths[idx]
            if let image = loadAndPreprocessImage(path: path) {
                imageData.append(image)
                labelData.append(Int32(label))
            }
        }

        let batchSize = imageData.count
        let flattenedSize = imageSize * imageSize * channels

        // Create MLXArrays
        let inputArray = MLXArray(imageData.flatMap { $0 })
            .reshaped([batchSize, imageSize, imageSize, channels])

        let labelArray = MLXArray(labelData)

        return (inputArray, labelArray)
    }

    private func loadAndPreprocessImage(path: String) -> [Float]? {
        guard let nsImage = NSImage(contentsOfFile: path),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Resize and convert to grayscale or RGB
        let width = imageSize
        let height = imageSize
        let bytesPerPixel = channels == 1 ? 1 : 4
        let bytesPerRow = width * bytesPerPixel

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = channels == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = channels == 1
            ? CGBitmapInfo(rawValue: 0)
            : CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Normalize to [0, 1]
        return pixelData.map { Float($0) / 255.0 }
    }

    func batches(batchSize: Int, shuffle: Bool = true) -> BatchIterator {
        BatchIterator(dataset: self, batchSize: batchSize, shuffle: shuffle)
    }
}

// MARK: - Synthetic Dataset (for testing)

/// Synthetic dataset for testing training pipeline
final class SyntheticDataset: MLXDataset, @unchecked Sendable {
    let sampleCount: Int
    let inputSize: Int
    let numClasses: Int
    let classLabels: [String]
    var inputShape: [Int] { [inputSize] }
    var count: Int { sampleCount }

    private let data: MLXArray
    private let labels: MLXArray

    init(sampleCount: Int = 1000, inputSize: Int = 784, numClasses: Int = 10) {
        self.sampleCount = sampleCount
        self.inputSize = inputSize
        self.numClasses = numClasses
        self.classLabels = (0..<numClasses).map { "Class \($0)" }

        // Generate random data
        self.data = MLXRandom.uniform(low: 0, high: 1, [sampleCount, inputSize])
        self.labels = MLXRandom.randInt(low: 0, high: Int32(numClasses), [sampleCount])
    }

    func getBatch(indices: [Int]) -> (inputs: MLXArray, labels: MLXArray) {
        let indicesArray = MLXArray(indices.map { Int32($0) })
        let batchInputs = data[indicesArray]
        let batchLabels = labels[indicesArray]
        return (batchInputs, batchLabels)
    }

    func batches(batchSize: Int, shuffle: Bool = true) -> BatchIterator {
        BatchIterator(dataset: self, batchSize: batchSize, shuffle: shuffle)
    }
}

// MARK: - MNIST Dataset (built-in)

/// MNIST dataset loader
/// Downloads and caches real MNIST data locally
final class MNISTDataset: MLXDataset, @unchecked Sendable {
    static let imageSize = 28
    static let channels = 1

    // MNIST file URLs (using reliable mirror)
    private static let baseURL = "https://storage.googleapis.com/cvdf-datasets/mnist/"
    private static let trainImagesFile = "train-images-idx3-ubyte.gz"
    private static let trainLabelsFile = "train-labels-idx1-ubyte.gz"
    private static let testImagesFile = "t10k-images-idx3-ubyte.gz"
    private static let testLabelsFile = "t10k-labels-idx1-ubyte.gz"

    let isTrain: Bool
    let classLabels = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    var numClasses: Int { 10 }
    var inputShape: [Int] { [Self.imageSize, Self.imageSize, Self.channels] }

    private var images: MLXArray
    private var labelsArray: MLXArray
    var count: Int { Int(images.dim(0)) }

    init(train: Bool = true) throws {
        self.isTrain = train

        // Get cache directory
        let cacheDir = try MNISTDataset.getCacheDirectory()

        // Download files if needed
        let imagesFile = train ? Self.trainImagesFile : Self.testImagesFile
        let labelsFile = train ? Self.trainLabelsFile : Self.testLabelsFile

        let imagesPath = cacheDir.appendingPathComponent(imagesFile)
        let labelsPath = cacheDir.appendingPathComponent(labelsFile)

        // Download if not cached
        if !FileManager.default.fileExists(atPath: imagesPath.path) {
            try MNISTDataset.downloadFile(
                from: URL(string: Self.baseURL + imagesFile)!,
                to: imagesPath
            )
        }

        if !FileManager.default.fileExists(atPath: labelsPath.path) {
            try MNISTDataset.downloadFile(
                from: URL(string: Self.baseURL + labelsFile)!,
                to: labelsPath
            )
        }

        // Load and parse the data
        let imageData = try MNISTDataset.loadImages(from: imagesPath)
        let labelData = try MNISTDataset.loadLabels(from: labelsPath)

        let sampleCount = imageData.count
        guard sampleCount == labelData.count else {
            throw TrainingError.invalidDataset("MNIST image/label count mismatch: \(sampleCount) vs \(labelData.count)")
        }

        // Convert to MLXArray
        // Images: normalize to [0, 1] and reshape to [N, 28, 28, 1]
        let flatImages = imageData.flatMap { $0 }
        self.images = MLXArray(flatImages)
            .reshaped([sampleCount, Self.imageSize, Self.imageSize, Self.channels])

        self.labelsArray = MLXArray(labelData.map { Int32($0) })
    }

    // MARK: - File Operations

    private static func getCacheDirectory() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let cacheDir = appSupport.appendingPathComponent("Performant3/MNIST", isDirectory: true)

        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }

        return cacheDir
    }

    private static func downloadFile(from url: URL, to destination: URL) throws {
        print("[MNIST] Downloading \(url.lastPathComponent)...")

        let semaphore = DispatchSemaphore(value: 0)
        var downloadError: Error?
        var downloadedData: Data?

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                downloadError = error
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                downloadError = TrainingError.datasetLoadFailed("HTTP \(httpResponse.statusCode) downloading \(url.lastPathComponent)")
            } else {
                downloadedData = data
            }
            semaphore.signal()
        }
        task.resume()

        let timeout = semaphore.wait(timeout: .now() + 120) // 2 minute timeout
        if timeout == .timedOut {
            task.cancel()
            throw TrainingError.datasetLoadFailed("Download timed out for \(url.lastPathComponent)")
        }

        if let error = downloadError {
            throw error
        }

        guard let data = downloadedData else {
            throw TrainingError.datasetLoadFailed("No data received for \(url.lastPathComponent)")
        }

        try data.write(to: destination)
        print("[MNIST] Downloaded \(url.lastPathComponent) (\(data.count) bytes)")
    }

    private static func loadImages(from path: URL) throws -> [[Float]] {
        // Load and decompress gzip data
        let compressedData = try Data(contentsOf: path)
        let data = try decompressGzip(compressedData)

        // Parse IDX file format
        // Magic number: 0x00000803 (2051) for images
        guard data.count > 16 else {
            throw TrainingError.invalidDataset("MNIST images file too small")
        }

        let magic = data.withUnsafeBytes { ptr -> UInt32 in
            ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian
        }

        guard magic == 2051 else {
            throw TrainingError.invalidDataset("Invalid MNIST images magic number: \(magic)")
        }

        let numImages = data.withUnsafeBytes { ptr -> Int in
            Int(ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian)
        }

        let numRows = data.withUnsafeBytes { ptr -> Int in
            Int(ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian)
        }

        let numCols = data.withUnsafeBytes { ptr -> Int in
            Int(ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian)
        }

        guard numRows == 28 && numCols == 28 else {
            throw TrainingError.invalidDataset("Unexpected MNIST image size: \(numRows)x\(numCols)")
        }

        let pixelsPerImage = numRows * numCols
        let headerSize = 16

        guard data.count >= headerSize + numImages * pixelsPerImage else {
            throw TrainingError.invalidDataset("MNIST images file truncated")
        }

        var images: [[Float]] = []
        images.reserveCapacity(numImages)

        for i in 0..<numImages {
            let offset = headerSize + i * pixelsPerImage
            var pixels: [Float] = []
            pixels.reserveCapacity(pixelsPerImage)

            for j in 0..<pixelsPerImage {
                let byte = data[offset + j]
                // Normalize to [0, 1]
                pixels.append(Float(byte) / 255.0)
            }
            images.append(pixels)
        }

        print("[MNIST] Loaded \(numImages) images")
        return images
    }

    private static func loadLabels(from path: URL) throws -> [UInt8] {
        // Load and decompress gzip data
        let compressedData = try Data(contentsOf: path)
        let data = try decompressGzip(compressedData)

        // Parse IDX file format
        // Magic number: 0x00000801 (2049) for labels
        guard data.count > 8 else {
            throw TrainingError.invalidDataset("MNIST labels file too small")
        }

        let magic = data.withUnsafeBytes { ptr -> UInt32 in
            ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian
        }

        guard magic == 2049 else {
            throw TrainingError.invalidDataset("Invalid MNIST labels magic number: \(magic)")
        }

        let numLabels = data.withUnsafeBytes { ptr -> Int in
            Int(ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian)
        }

        let headerSize = 8

        guard data.count >= headerSize + numLabels else {
            throw TrainingError.invalidDataset("MNIST labels file truncated")
        }

        var labels: [UInt8] = []
        labels.reserveCapacity(numLabels)

        for i in 0..<numLabels {
            labels.append(data[headerSize + i])
        }

        print("[MNIST] Loaded \(numLabels) labels")
        return labels
    }

    private static func decompressGzip(_ data: Data) throws -> Data {
        // Use zlib to decompress gzip data
        guard data.count > 2 else {
            throw TrainingError.invalidDataset("Data too small to be gzip")
        }

        // Check gzip magic number
        guard data[0] == 0x1f && data[1] == 0x8b else {
            throw TrainingError.invalidDataset("Not a gzip file")
        }

        // Skip gzip header (minimum 10 bytes for standard header)
        // Header structure: magic(2) + method(1) + flags(1) + mtime(4) + xfl(1) + os(1)
        let headerSize = 10
        let compressedPayload = Array(data.dropFirst(headerSize))

        // Allocate destination buffer (MNIST files decompress to ~47MB max)
        let decompressedSize = 50_000_000  // 50MB should be enough
        let decompressedBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: decompressedSize)
        defer { decompressedBuffer.deallocate() }

        let actualSize = compressedPayload.withUnsafeBufferPointer { srcBuffer -> Int in
            compression_decode_buffer(
                decompressedBuffer,
                decompressedSize,
                srcBuffer.baseAddress!,
                srcBuffer.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard actualSize > 0 else {
            throw TrainingError.invalidDataset("Decompression failed")
        }

        return Data(bytes: decompressedBuffer, count: actualSize)
    }

    // MARK: - Dataset Protocol

    func getBatch(indices: [Int]) -> (inputs: MLXArray, labels: MLXArray) {
        let indicesArray = MLXArray(indices.map { Int32($0) })
        let batchInputs = images[indicesArray]
        let batchLabels = labelsArray[indicesArray]
        return (batchInputs, batchLabels)
    }

    func batches(batchSize: Int, shuffle: Bool = true) -> BatchIterator {
        BatchIterator(dataset: self, batchSize: batchSize, shuffle: shuffle)
    }
}
