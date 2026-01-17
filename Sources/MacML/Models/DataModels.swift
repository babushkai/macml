import Foundation
import SwiftUI

// MARK: - ML Model

struct MLModel: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var framework: MLFramework
    var status: ModelStatus
    var accuracy: Double
    var fileSize: Int64
    var filePath: String?
    var createdAt: Date
    var updatedAt: Date
    var metadata: [String: String]

    init(
        id: String = UUID().uuidString,
        name: String,
        framework: MLFramework,
        status: ModelStatus = .draft,
        accuracy: Double = 0,
        fileSize: Int64 = 0,
        filePath: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.framework = framework
        self.status = status
        self.accuracy = accuracy
        self.fileSize = fileSize
        self.filePath = filePath
        self.createdAt = Date()
        self.updatedAt = Date()
        self.metadata = metadata
    }
}

enum ModelStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case importing = "Importing"
    case ready = "Ready"
    case training = "Training"
    case deployed = "Deployed"
    case failed = "Failed"
    case archived = "Archived"
    case deprecated = "Deprecated"

    var color: Color {
        switch self {
        case .draft: return .gray
        case .importing: return .orange
        case .ready: return .green
        case .training: return .blue
        case .deployed: return .purple
        case .failed: return .red
        case .archived: return .secondary
        case .deprecated: return .brown
        }
    }

    var icon: String {
        switch self {
        case .draft: return "doc"
        case .importing: return "arrow.down.circle"
        case .ready: return "checkmark.circle"
        case .training: return "gear"
        case .deployed: return "icloud"
        case .failed: return "xmark.circle"
        case .archived: return "archivebox"
        case .deprecated: return "exclamationmark.triangle"
        }
    }

    var isActive: Bool {
        switch self {
        case .archived, .deprecated: return false
        default: return true
        }
    }
}

enum MLFramework: String, Codable, CaseIterable {
    case coreML = "Core ML"
    case pytorch = "PyTorch"
    case tensorflow = "TensorFlow"
    case mlx = "MLX"
    case onnx = "ONNX"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .coreML: return "apple.logo"
        case .pytorch: return "flame"
        case .tensorflow: return "brain"
        case .mlx: return "cpu"
        case .onnx: return "square.stack.3d.up"
        case .custom: return "cube"
        }
    }

    var color: Color {
        switch self {
        case .coreML: return .blue
        case .pytorch: return .orange
        case .tensorflow: return .red
        case .mlx: return .purple
        case .onnx: return .green
        case .custom: return .gray
        }
    }

    var fileExtension: String {
        switch self {
        case .coreML: return "mlmodel"
        case .pytorch: return "pt"
        case .tensorflow: return "pb"
        case .mlx: return "safetensors"
        case .onnx: return "onnx"
        case .custom: return "*"
        }
    }
}

// MARK: - Training Run

struct TrainingRun: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var modelId: String
    var modelName: String
    var experimentId: String?  // Optional experiment this run belongs to
    var status: RunStatus
    var progress: Double
    var currentEpoch: Int
    var totalEpochs: Int
    var batchSize: Int
    var learningRate: Double
    var architectureType: String  // Store as string for Codable compatibility
    var loss: Double?
    var accuracy: Double?
    var precision: Double?
    var recall: Double?
    var f1Score: Double?
    var startedAt: Date
    var finishedAt: Date?
    var logs: [LogEntry]
    var metrics: [MetricPoint]

    init(
        id: String = UUID().uuidString,
        name: String,
        modelId: String,
        modelName: String,
        epochs: Int = 10,
        batchSize: Int = 32,
        learningRate: Double = 0.001,
        architecture: String = "MLP",
        experimentId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.modelId = modelId
        self.modelName = modelName
        self.experimentId = experimentId
        self.status = .queued
        self.progress = 0
        self.currentEpoch = 0
        self.totalEpochs = epochs
        self.batchSize = batchSize
        self.learningRate = learningRate
        self.architectureType = architecture
        self.startedAt = Date()
        self.logs = []
        self.metrics = []
    }

    var duration: String {
        let end = finishedAt ?? Date()
        let interval = end.timeIntervalSince(startedAt)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        }
        return String(format: "%ds", seconds)
    }
}

enum RunStatus: String, Codable, CaseIterable {
    case queued = "Queued"
    case running = "Running"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"

    var color: Color {
        switch self {
        case .queued: return .gray
        case .running: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .queued: return "clock"
        case .running: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }
}

struct LogEntry: Identifiable, Codable, Hashable {
    let id: String
    let timestamp: Date
    let level: LogLevel
    let message: String

    init(level: LogLevel, message: String) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.level = level
        self.message = message
    }
}

enum LogLevel: String, Codable {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case debug = "DEBUG"

    var color: Color {
        switch self {
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .debug: return .gray
        }
    }

    var prefix: String {
        switch self {
        case .info: return "[INFO]"
        case .warning: return "[WARN]"
        case .error: return "[ERROR]"
        case .debug: return "[DEBUG]"
        }
    }
}

struct MetricPoint: Identifiable, Codable, Hashable {
    let id: String
    let epoch: Int
    let loss: Double
    let accuracy: Double
    let precision: Double?
    let recall: Double?
    let f1Score: Double?
    let timestamp: Date

    init(epoch: Int, loss: Double, accuracy: Double, precision: Double? = nil, recall: Double? = nil, f1Score: Double? = nil) {
        self.id = UUID().uuidString
        self.epoch = epoch
        self.loss = loss
        self.accuracy = accuracy
        self.precision = precision
        self.recall = recall
        self.f1Score = f1Score
        self.timestamp = Date()
    }
}

// MARK: - Extended Metrics

/// Extended metrics for multi-class classification
struct ExtendedMetrics: Codable, Equatable {
    var precision: Double
    var recall: Double
    var f1Score: Double
    var perClassMetrics: [ClassMetrics]?

    init(precision: Double = 0, recall: Double = 0, f1Score: Double = 0, perClassMetrics: [ClassMetrics]? = nil) {
        self.precision = precision
        self.recall = recall
        self.f1Score = f1Score
        self.perClassMetrics = perClassMetrics
    }

    /// Calculate from confusion matrix
    static func calculate(predictions: [Int], labels: [Int], numClasses: Int) -> ExtendedMetrics {
        guard !predictions.isEmpty, predictions.count == labels.count else {
            return ExtendedMetrics()
        }

        var perClass: [ClassMetrics] = []
        var totalTP = 0
        var totalFP = 0
        var totalFN = 0

        for classIdx in 0..<numClasses {
            var tp = 0, fp = 0, fn = 0

            for (pred, label) in zip(predictions, labels) {
                if pred == classIdx && label == classIdx {
                    tp += 1
                } else if pred == classIdx && label != classIdx {
                    fp += 1
                } else if pred != classIdx && label == classIdx {
                    fn += 1
                }
            }

            let precision = (tp + fp) > 0 ? Double(tp) / Double(tp + fp) : 0
            let recall = (tp + fn) > 0 ? Double(tp) / Double(tp + fn) : 0
            let f1 = (precision + recall) > 0 ? 2 * precision * recall / (precision + recall) : 0

            perClass.append(ClassMetrics(classIndex: classIdx, precision: precision, recall: recall, f1Score: f1, support: tp + fn))

            totalTP += tp
            totalFP += fp
            totalFN += fn
        }

        // Macro-average
        let macroPrecision = perClass.map { $0.precision }.reduce(0, +) / Double(max(1, numClasses))
        let macroRecall = perClass.map { $0.recall }.reduce(0, +) / Double(max(1, numClasses))
        let macroF1 = (macroPrecision + macroRecall) > 0 ? 2 * macroPrecision * macroRecall / (macroPrecision + macroRecall) : 0

        return ExtendedMetrics(precision: macroPrecision, recall: macroRecall, f1Score: macroF1, perClassMetrics: perClass)
    }
}

/// Per-class metrics for detailed analysis
struct ClassMetrics: Codable, Equatable, Identifiable {
    var id: Int { classIndex }
    let classIndex: Int
    let precision: Double
    let recall: Double
    let f1Score: Double
    let support: Int  // Number of samples in this class
}

// MARK: - Dataset

struct Dataset: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    var type: DatasetType
    var status: DatasetStatus
    var path: String?
    var sampleCount: Int
    var size: Int64
    var classes: [String]
    var createdAt: Date
    var updatedAt: Date
    var metadata: [String: String]

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        type: DatasetType,
        status: DatasetStatus = .active,
        path: String? = nil,
        sampleCount: Int = 0,
        size: Int64 = 0,
        classes: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.status = status
        self.path = path
        self.sampleCount = sampleCount
        self.size = size
        self.classes = classes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.metadata = metadata
    }
}

enum DatasetStatus: String, Codable, CaseIterable {
    case active = "Active"
    case processing = "Processing"
    case archived = "Archived"
    case deprecated = "Deprecated"

    var color: Color {
        switch self {
        case .active: return .green
        case .processing: return .orange
        case .archived: return .secondary
        case .deprecated: return .brown
        }
    }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle"
        case .processing: return "arrow.triangle.2.circlepath"
        case .archived: return "archivebox"
        case .deprecated: return "exclamationmark.triangle"
        }
    }

    var isActive: Bool {
        switch self {
        case .archived, .deprecated: return false
        default: return true
        }
    }
}

enum DatasetType: String, Codable, CaseIterable {
    case images = "Images"
    case text = "Text"
    case audio = "Audio"
    case video = "Video"
    case tabular = "Tabular"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .images: return "photo.stack"
        case .text: return "doc.text"
        case .audio: return "waveform"
        case .video: return "video"
        case .tabular: return "tablecells"
        case .custom: return "folder"
        }
    }

    var color: Color {
        switch self {
        case .images: return .blue
        case .text: return .green
        case .audio: return .purple
        case .video: return .red
        case .tabular: return .orange
        case .custom: return .gray
        }
    }
}

// MARK: - Inference

struct InferenceRequest: Identifiable, Codable {
    let id: String
    let modelId: String
    let inputPath: String
    let timestamp: Date

    init(modelId: String, inputPath: String) {
        self.id = UUID().uuidString
        self.modelId = modelId
        self.inputPath = inputPath
        self.timestamp = Date()
    }
}

struct InferenceResult: Identifiable, Codable, Hashable {
    let id: String
    let requestId: String
    let modelId: String
    let predictions: [Prediction]
    let inferenceTimeMs: Double
    let timestamp: Date
}

struct Prediction: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let confidence: Double

    init(label: String, confidence: Double) {
        self.id = UUID().uuidString
        self.label = label
        self.confidence = confidence
    }
}

// MARK: - App Settings

struct AppSettings: Codable, Equatable {
    var gpuEnabled: Bool
    var autoSave: Bool
    var autoSaveCheckpoints: Bool
    var showNotifications: Bool
    var cacheModels: Bool
    var maxConcurrentRuns: Int
    var defaultEpochs: Int
    var defaultBatchSize: Int
    var defaultLearningRate: Double
    var theme: String
    var modelsDirectory: String
    var datasetsDirectory: String

    static var `default`: AppSettings {
        AppSettings(
            gpuEnabled: true,
            autoSave: true,
            autoSaveCheckpoints: true,
            showNotifications: true,
            cacheModels: true,
            maxConcurrentRuns: 2,
            defaultEpochs: 10,
            defaultBatchSize: 32,
            defaultLearningRate: 0.001,
            theme: "system",
            modelsDirectory: "Models",
            datasetsDirectory: "Datasets"
        )
    }
}

// MARK: - Helpers

func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60
    if hours > 0 {
        return String(format: "%dh %dm", hours, minutes)
    } else if minutes > 0 {
        return String(format: "%dm %ds", minutes, secs)
    }
    return String(format: "%ds", secs)
}

// MARK: - Knowledge Distillation

enum TeacherType: String, Codable, CaseIterable, Hashable {
    case cloudLLM = "Cloud LLM"
    case localModel = "Local Model"
    case customAPI = "Custom API"

    var icon: String {
        switch self {
        case .cloudLLM: return "cloud"
        case .localModel: return "laptopcomputer"
        case .customAPI: return "server.rack"
        }
    }

    var description: String {
        switch self {
        case .cloudLLM: return "Use a cloud-based LLM (Claude, GPT-4, etc.) as teacher"
        case .localModel: return "Use an existing local model as teacher"
        case .customAPI: return "Connect to a custom API endpoint"
        }
    }
}

enum CloudProvider: String, Codable, CaseIterable, Hashable {
    case anthropic = "Anthropic"
    case openai = "OpenAI"
    case google = "Google"

    var icon: String {
        switch self {
        case .anthropic: return "a.circle"
        case .openai: return "circle.hexagonpath"
        case .google: return "g.circle"
        }
    }

    var models: [String] {
        switch self {
        case .anthropic: return ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku"]
        case .openai: return ["gpt-4", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .google: return ["gemini-pro", "gemini-ultra"]
        }
    }

    var baseURL: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com"
        case .openai: return "https://api.openai.com"
        case .google: return "https://generativelanguage.googleapis.com"
        }
    }
}

enum StudentArchitecture: String, Codable, CaseIterable, Hashable {
    case mlp = "MLP"
    case cnn = "CNN"
    case transformer = "Transformer"
    case lstm = "LSTM"

    var icon: String {
        switch self {
        case .mlp: return "brain"
        case .cnn: return "square.grid.3x3"
        case .transformer: return "arrow.triangle.branch"
        case .lstm: return "arrow.uturn.backward"
        }
    }

    var description: String {
        switch self {
        case .mlp: return "Multi-layer Perceptron - simple, fast, good for tabular data"
        case .cnn: return "Convolutional Neural Network - best for image tasks"
        case .transformer: return "Transformer - best for sequence/text tasks"
        case .lstm: return "Long Short-Term Memory - good for time series"
        }
    }

    var parameterCount: String {
        switch self {
        case .mlp: return "~100K"
        case .cnn: return "~1M"
        case .transformer: return "~10M"
        case .lstm: return "~500K"
        }
    }
}

enum DistillationStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case generatingData = "Generating Data"
    case training = "Training"
    case evaluating = "Evaluating"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"

    var color: Color {
        switch self {
        case .pending: return .gray
        case .generatingData: return .orange
        case .training: return .blue
        case .evaluating: return .purple
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .generatingData: return "arrow.down.circle"
        case .training: return "brain"
        case .evaluating: return "chart.bar"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }

    var isActive: Bool {
        switch self {
        case .pending, .generatingData, .training, .evaluating:
            return true
        default:
            return false
        }
    }
}

struct DistillationConfig: Codable, Equatable, Hashable {
    var taskDescription: String
    var teacherType: TeacherType
    var cloudProvider: CloudProvider?
    var teacherModelId: String?
    var studentArchitecture: StudentArchitecture
    var temperature: Double
    var alpha: Double
    var syntheticSamples: Int
    var epochs: Int
    var batchSize: Int
    var learningRate: Double
    var datasetId: String?

    static var `default`: DistillationConfig {
        DistillationConfig(
            taskDescription: "",
            teacherType: .cloudLLM,
            cloudProvider: .anthropic,
            teacherModelId: "claude-3-sonnet",
            studentArchitecture: .mlp,
            temperature: 2.0,
            alpha: 0.5,
            syntheticSamples: 1000,
            epochs: 10,
            batchSize: 32,
            learningRate: 0.001
        )
    }
}

struct DistillationRun: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var config: DistillationConfig
    var status: DistillationStatus
    var progress: Double
    var phase: String
    var samplesGenerated: Int
    var apiCallsMade: Int
    var estimatedCost: Double
    var currentEpoch: Int
    var trainLoss: Double?
    var studentAccuracy: Double?
    var compressionRatio: Double?
    var startedAt: Date?
    var finishedAt: Date?
    var logs: [LogEntry]
    var metrics: [MetricPoint]

    init(
        id: String = UUID().uuidString,
        name: String,
        config: DistillationConfig
    ) {
        self.id = id
        self.name = name
        self.config = config
        self.status = .pending
        self.progress = 0
        self.phase = "Pending"
        self.samplesGenerated = 0
        self.apiCallsMade = 0
        self.estimatedCost = 0
        self.currentEpoch = 0
        self.logs = []
        self.metrics = []
    }

    var duration: String {
        guard let start = startedAt else { return "0s" }
        let end = finishedAt ?? Date()
        let interval = end.timeIntervalSince(start)
        return formatDuration(interval)
    }
}

struct DistillationSample: Identifiable, Codable, Hashable {
    let id: String
    var input: String
    var teacherOutput: String
    var teacherLogits: [Double]?
    var label: Int?
    var confidence: Double?

    init(input: String, teacherOutput: String, teacherLogits: [Double]? = nil, label: Int? = nil, confidence: Double? = nil) {
        self.id = UUID().uuidString
        self.input = input
        self.teacherOutput = teacherOutput
        self.teacherLogits = teacherLogits
        self.label = label
        self.confidence = confidence
    }
}
