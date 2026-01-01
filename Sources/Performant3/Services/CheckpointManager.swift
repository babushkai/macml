import Foundation
import MLX
import MLXNN
import MLXOptimizers

// MARK: - Checkpoint Manager

/// Manages saving and loading of model checkpoints during training
actor CheckpointManager {
    static let shared = CheckpointManager()

    private let fileManager = FileManager.default
    private let checkpointDirectory: URL

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.checkpointDirectory = appSupport
            .appendingPathComponent("Performant3", isDirectory: true)
            .appendingPathComponent("checkpoints", isDirectory: true)

        try? fileManager.createDirectory(at: checkpointDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Checkpoint Saving

    /// Save a checkpoint for a training run
    func saveCheckpoint(
        runId: String,
        epoch: Int,
        model: Module,
        optimizer: Optimizer?,
        loss: Double,
        accuracy: Double?,
        classLabels: [String]? = nil,
        architectureType: String? = nil
    ) async throws -> CheckpointInfo {
        let runDir = checkpointDirectory.appendingPathComponent(runId, isDirectory: true)
        try fileManager.createDirectory(at: runDir, withIntermediateDirectories: true)

        let checkpointName = "checkpoint_epoch_\(epoch)"
        let checkpointPath = runDir.appendingPathComponent(checkpointName)

        // Get model parameters and flatten them
        let parameters = model.parameters()
        let flatParams = flattenNestedDictionary(parameters)

        // Save parameters to safetensors format
        try MLX.save(arrays: flatParams, url: checkpointPath.appendingPathExtension("safetensors"))

        // Save metadata
        let metadata = CheckpointMetadata(
            runId: runId,
            epoch: epoch,
            loss: loss,
            accuracy: accuracy,
            timestamp: Date(),
            classLabels: classLabels,
            architectureType: architectureType
        )

        let metadataPath = checkpointPath.appendingPathExtension("json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataPath)

        let fullPath = checkpointPath.appendingPathExtension("safetensors").path

        return CheckpointInfo(
            id: UUID().uuidString,
            runId: runId,
            epoch: epoch,
            loss: loss,
            accuracy: accuracy,
            path: fullPath,
            timestamp: Date(),
            classLabels: classLabels,
            architectureType: architectureType
        )
    }

    /// Flatten nested parameter dictionary for saving
    private func flattenNestedDictionary(_ params: NestedDictionary<String, MLXArray>, prefix: String = "") -> [String: MLXArray] {
        var result: [String: MLXArray] = [:]

        // Use flattened() method which returns [(String, MLXArray)]
        let flattened = params.flattened()
        for (key, array) in flattened {
            result[key] = array
        }

        return result
    }

    // MARK: - Checkpoint Loading

    /// Load a checkpoint for a model
    func loadCheckpoint(
        runId: String,
        epoch: Int,
        into model: Module
    ) async throws {
        let checkpointPath = checkpointDirectory
            .appendingPathComponent(runId, isDirectory: true)
            .appendingPathComponent("checkpoint_epoch_\(epoch)")
            .appendingPathExtension("safetensors")

        guard fileManager.fileExists(atPath: checkpointPath.path) else {
            throw CheckpointError.notFound(runId: runId, epoch: epoch)
        }

        // Load parameters
        let loadedArrays = try MLX.loadArrays(url: checkpointPath)

        // Update model with loaded parameters
        // Convert flat dictionary back to nested structure using MLX's unflattened
        let nestedParams = NestedDictionary<String, MLXArray>.unflattened(loadedArrays)
        model.update(parameters: nestedParams)
    }

    // MARK: - Checkpoint Listing

    /// List all checkpoints for a run
    func listCheckpoints(runId: String) async throws -> [CheckpointInfo] {
        let runDir = checkpointDirectory.appendingPathComponent(runId, isDirectory: true)

        guard fileManager.fileExists(atPath: runDir.path) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(at: runDir, includingPropertiesForKeys: nil)
        let metadataFiles = contents.filter { $0.pathExtension == "json" }

        var checkpoints: [CheckpointInfo] = []
        let decoder = JSONDecoder()

        for metadataFile in metadataFiles {
            if let data = try? Data(contentsOf: metadataFile),
               let metadata = try? decoder.decode(CheckpointMetadata.self, from: data) {
                let checkpointPath = metadataFile.deletingPathExtension().appendingPathExtension("safetensors")
                checkpoints.append(CheckpointInfo(
                    id: UUID().uuidString,
                    runId: metadata.runId,
                    epoch: metadata.epoch,
                    loss: metadata.loss,
                    accuracy: metadata.accuracy,
                    path: checkpointPath.path,
                    timestamp: metadata.timestamp,
                    classLabels: metadata.classLabels,
                    architectureType: metadata.architectureType
                ))
            }
        }

        return checkpoints.sorted { $0.epoch > $1.epoch }
    }

    /// Get the latest checkpoint for a run
    func getLatestCheckpoint(runId: String) async throws -> CheckpointInfo? {
        let checkpoints = try await listCheckpoints(runId: runId)
        return checkpoints.first
    }

    // MARK: - Cleanup

    /// Delete all checkpoints for a run
    func deleteCheckpoints(runId: String) async throws {
        let runDir = checkpointDirectory.appendingPathComponent(runId, isDirectory: true)
        if fileManager.fileExists(atPath: runDir.path) {
            try fileManager.removeItem(at: runDir)
        }
    }

    /// Delete old checkpoints, keeping only the N most recent
    func pruneCheckpoints(runId: String, keep: Int) async throws {
        var checkpoints = try await listCheckpoints(runId: runId)
        guard checkpoints.count > keep else { return }

        // Sort by epoch descending
        checkpoints.sort { $0.epoch > $1.epoch }

        // Delete older ones
        for checkpoint in checkpoints.dropFirst(keep) {
            try? fileManager.removeItem(atPath: checkpoint.path)
            let metadataPath = URL(fileURLWithPath: checkpoint.path)
                .deletingPathExtension()
                .appendingPathExtension("json")
            try? fileManager.removeItem(at: metadataPath)
        }
    }

    // MARK: - Export

    /// Export a checkpoint to a specified location
    func exportCheckpoint(_ checkpoint: CheckpointInfo, to destination: URL) async throws {
        let sourcePath = URL(fileURLWithPath: checkpoint.path)
        try fileManager.copyItem(at: sourcePath, to: destination)
    }

    /// Export the best checkpoint (lowest loss or highest accuracy)
    func exportBestCheckpoint(runId: String, to destination: URL, byMetric: CheckpointMetric = .loss) async throws {
        let checkpoints = try await listCheckpoints(runId: runId)
        guard !checkpoints.isEmpty else {
            throw CheckpointError.noCheckpoints(runId: runId)
        }

        let best: CheckpointInfo?
        switch byMetric {
        case .loss:
            best = checkpoints.min { $0.loss < $1.loss }
        case .accuracy:
            best = checkpoints.max { ($0.accuracy ?? 0) < ($1.accuracy ?? 0) }
        }

        guard let bestCheckpoint = best else {
            throw CheckpointError.noCheckpoints(runId: runId)
        }

        try await exportCheckpoint(bestCheckpoint, to: destination)
    }
}

// MARK: - Supporting Types

struct CheckpointInfo: Identifiable, Codable, Sendable {
    let id: String
    let runId: String
    let epoch: Int
    let loss: Double
    let accuracy: Double?
    let path: String
    let timestamp: Date
    let classLabels: [String]?
    let architectureType: String?
}

struct CheckpointMetadata: Codable {
    let runId: String
    let epoch: Int
    let loss: Double
    let accuracy: Double?
    let timestamp: Date
    let classLabels: [String]?
    let architectureType: String?
    let numClasses: Int?

    init(runId: String, epoch: Int, loss: Double, accuracy: Double?, timestamp: Date, classLabels: [String]? = nil, architectureType: String? = nil) {
        self.runId = runId
        self.epoch = epoch
        self.loss = loss
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.classLabels = classLabels
        self.architectureType = architectureType
        self.numClasses = classLabels?.count
    }
}

enum CheckpointMetric {
    case loss
    case accuracy
}

enum CheckpointError: Error, LocalizedError {
    case notFound(runId: String, epoch: Int)
    case noCheckpoints(runId: String)
    case saveFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let runId, let epoch):
            return "Checkpoint not found for run \(runId) at epoch \(epoch)"
        case .noCheckpoints(let runId):
            return "No checkpoints found for run \(runId)"
        case .saveFailed(let reason):
            return "Failed to save checkpoint: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load checkpoint: \(reason)"
        }
    }
}
