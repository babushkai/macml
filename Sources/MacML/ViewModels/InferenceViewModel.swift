import SwiftUI

/// ViewModel for managing inference operations
/// Extracts inference-related logic from AppState for better separation of concerns
@MainActor
class InferenceViewModel: ObservableObject {
    // MARK: - Constants

    private enum Constants {
        static let maxHistoryCount = 100
    }

    // MARK: - Published Properties

    @Published var inferenceHistory: [InferenceResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastResult: InferenceResult?

    // MARK: - Dependencies

    private let storage: StorageManager
    private let mlService: MLService
    private let mlxInferenceService: MLXInferenceService

    // MARK: - Computed Properties

    var recentResults: [InferenceResult] {
        Array(inferenceHistory.prefix(10))
    }

    var averageInferenceTime: Double {
        guard !inferenceHistory.isEmpty else { return 0 }
        return inferenceHistory.map(\.inferenceTimeMs).reduce(0, +) / Double(inferenceHistory.count)
    }

    // MARK: - Initialization

    init(
        storage: StorageManager = .shared,
        mlService: MLService = .shared,
        mlxInferenceService: MLXInferenceService = .shared
    ) {
        self.storage = storage
        self.mlService = mlService
        self.mlxInferenceService = mlxInferenceService
    }

    // MARK: - Data Loading

    func loadHistory(databaseInitialized: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if databaseInitialized {
                Log.debug("Loading inference history from database...", category: .database)
                let repo = InferenceResultRepository()
                inferenceHistory = (try? await repo.findAll(limit: Constants.maxHistoryCount)) ?? []
                Log.debug("Loaded \(inferenceHistory.count) inference results from database", category: .database)
            }

            if inferenceHistory.isEmpty {
                Log.debug("Loading inference history from JSON...", category: .database)
                inferenceHistory = try await storage.loadInferenceHistory()
                Log.debug("Loaded \(inferenceHistory.count) inference results from JSON", category: .database)
            }
        } catch {
            Log.error("Failed to load inference history", error: error, category: .database)
            errorMessage = "Failed to load inference history: \(error.localizedDescription)"
        }
    }

    // MARK: - Inference

    func runInference(model: MLModel, imageURL: URL) async throws -> InferenceResult {
        isLoading = true
        defer { isLoading = false }

        do {
            let result: InferenceResult

            if model.framework == .mlx {
                result = try await mlxInferenceService.runInference(model: model, imageURL: imageURL)
            } else {
                result = try await mlService.classifyImage(model: model, imageURL: imageURL)
            }

            // Update history
            inferenceHistory.insert(result, at: 0)
            if inferenceHistory.count > Constants.maxHistoryCount {
                inferenceHistory = Array(inferenceHistory.prefix(Constants.maxHistoryCount))
            }

            // Persist
            Task {
                let repo = InferenceResultRepository()
                try? await repo.create(result)
                try? await repo.pruneToLimit(Constants.maxHistoryCount)
            }

            await saveHistory()
            lastResult = result

            // Log result
            if let topPrediction = result.predictions.first {
                Log.inferenceResult(
                    modelId: model.id,
                    prediction: topPrediction.label,
                    confidence: topPrediction.confidence,
                    timeMs: result.inferenceTimeMs
                )
            }

            return result
        } catch {
            Log.error("Inference failed", error: error, category: .inference)
            errorMessage = "Inference failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - History Management

    func clearHistory() async {
        inferenceHistory.removeAll()
        lastResult = nil
        await saveHistory()
        Log.info("Inference history cleared", category: .app)
    }

    func deleteResult(_ result: InferenceResult) async {
        inferenceHistory.removeAll { $0.id == result.id }
        await saveHistory()
    }

    // MARK: - Private

    private func saveHistory() async {
        do {
            try await storage.saveInferenceHistory(inferenceHistory)
        } catch {
            Log.error("Failed to save inference history", error: error, category: .database)
            errorMessage = "Failed to save inference history: \(error.localizedDescription)"
        }
    }
}
