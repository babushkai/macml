import Foundation

// MARK: - Training Backend Protocol

/// Protocol for training backend implementations (MLX, simulated, etc.)
protocol TrainingBackend: Actor {
    /// Start training with the given configuration
    func train(
        config: TrainingConfig,
        modelConfig: ModelArchitecture,
        datasetPath: String?,
        runId: String,
        progressHandler: @escaping (TrainingProgress) -> Void
    ) async throws -> TrainingResult

    /// Cancel ongoing training
    func cancel() async

    /// Check if training is currently running
    var isTraining: Bool { get async }
}

// MARK: - Training Progress

/// Progress updates during training
struct TrainingProgress: Sendable {
    let epoch: Int
    let totalEpochs: Int
    let step: Int?
    let totalSteps: Int?
    let loss: Double
    let accuracy: Double?
    let learningRate: Double?
    let message: String?

    var progress: Double {
        let epochProgress = Double(epoch) / Double(totalEpochs)
        if let step = step, let total = totalSteps, total > 0 {
            let stepProgress = Double(step) / Double(total)
            return (Double(epoch - 1) + stepProgress) / Double(totalEpochs)
        }
        return epochProgress
    }
}

// MARK: - Training Result

/// Final result of training
struct TrainingResult: Sendable {
    let finalLoss: Double
    let finalAccuracy: Double?
    let totalEpochs: Int
    let totalTime: TimeInterval
    let modelPath: String?
    let checkpoints: [TrainingCheckpoint]
}

/// Lightweight checkpoint info for training results
struct TrainingCheckpoint: Sendable {
    let epoch: Int
    let path: String
    let loss: Double
    let accuracy: Double?
}

// MARK: - Model Architecture Configuration

/// Configuration for neural network architecture
enum ModelArchitecture: Codable, Sendable {
    case mlp(MLPConfig)
    case cnn(CNNConfig)
    case resnet(ResNetConfig)
    case transformer(TransformerConfig)
    case custom(name: String)

    static var defaultMLP: ModelArchitecture {
        .mlp(MLPConfig(
            inputSize: 784,
            hiddenSizes: [512, 256, 128],  // Larger network for better accuracy
            outputSize: 10,
            activation: .relu,
            dropout: 0.1  // Lower dropout for MNIST
        ))
    }

    static var defaultCNN: ModelArchitecture {
        .cnn(CNNConfig(
            inputChannels: 1,
            imageSize: 28,
            convLayers: [
                .init(outChannels: 32, kernelSize: 3, stride: 1, padding: 1),
                .init(outChannels: 64, kernelSize: 3, stride: 1, padding: 1)
            ],
            fcSizes: [128],
            outputSize: 10,
            dropout: 0.25
        ))
    }

    static var defaultResNet: ModelArchitecture {
        .resnet(ResNetConfig(
            inputSize: 784,
            hiddenSize: 256,
            numBlocks: 3,
            outputSize: 10,
            dropout: 0.1
        ))
    }

    static var defaultTransformer: ModelArchitecture {
        .transformer(TransformerConfig(
            inputDim: 784,
            modelDim: 128,
            numHeads: 4,
            ffnDim: 256,
            numLayers: 2,
            seqLength: 1,
            outputSize: 10,
            dropout: 0.1
        ))
    }
}

struct MLPConfig: Codable, Sendable {
    let inputSize: Int
    let hiddenSizes: [Int]
    let outputSize: Int
    let activation: ActivationType
    let dropout: Double
}

struct CNNConfig: Codable, Sendable {
    let inputChannels: Int
    let imageSize: Int
    let convLayers: [ConvLayerConfig]
    let fcSizes: [Int]
    let outputSize: Int
    let dropout: Double
}

struct ConvLayerConfig: Codable, Sendable {
    let outChannels: Int
    let kernelSize: Int
    let stride: Int
    let padding: Int
}

struct ResNetConfig: Codable, Sendable {
    let inputSize: Int
    let hiddenSize: Int
    let numBlocks: Int
    let outputSize: Int
    let dropout: Double
}

struct TransformerConfig: Codable, Sendable {
    let inputDim: Int
    let modelDim: Int
    let numHeads: Int
    let ffnDim: Int
    let numLayers: Int
    let seqLength: Int
    let outputSize: Int
    let dropout: Double
}

enum ActivationType: String, Codable, Sendable, CaseIterable {
    case relu = "ReLU"
    case gelu = "GELU"
    case silu = "SiLU"
    case tanh = "Tanh"
    case sigmoid = "Sigmoid"
}

// MARK: - Training Errors

enum TrainingError: Error, LocalizedError {
    case datasetNotFound(String)
    case invalidDataset(String)
    case datasetLoadFailed(String)
    case modelCreationFailed(String)
    case trainingCancelled
    case outOfMemory
    case gpuNotAvailable
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .datasetNotFound(let path):
            return "Dataset not found at path: \(path)"
        case .invalidDataset(let reason):
            return "Invalid dataset: \(reason)"
        case .datasetLoadFailed(let reason):
            return "Dataset load failed: \(reason)"
        case .modelCreationFailed(let reason):
            return "Failed to create model: \(reason)"
        case .trainingCancelled:
            return "Training was cancelled"
        case .outOfMemory:
            return "Out of memory during training"
        case .gpuNotAvailable:
            return "GPU is not available for training"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        }
    }
}
