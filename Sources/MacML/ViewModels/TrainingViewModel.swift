import SwiftUI

/// ViewModel for managing training runs
/// Extracts training-related logic from AppState for better separation of concerns
@MainActor
class TrainingViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var runs: [TrainingRun] = []
    @Published var selectedRunId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let storage: StorageManager
    private let trainingService: TrainingService

    // MARK: - Computed Properties

    var selectedRun: TrainingRun? {
        selectedRunId.flatMap { id in runs.first { $0.id == id } }
    }

    var activeRuns: [TrainingRun] {
        runs.filter { $0.status == .running || $0.status == .queued || $0.status == .paused }
    }

    var completedRuns: [TrainingRun] {
        runs.filter { $0.status == .completed }
    }

    var failedRuns: [TrainingRun] {
        runs.filter { $0.status == .failed }
    }

    var hasActiveRuns: Bool {
        !activeRuns.isEmpty
    }

    // MARK: - Callbacks

    var onRunCompleted: ((TrainingRun) -> Void)?

    // MARK: - Initialization

    init(storage: StorageManager = .shared, trainingService: TrainingService = .shared) {
        self.storage = storage
        self.trainingService = trainingService
        setupCallbacks()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        trainingService.onRunUpdated = { [weak self] run in
            Task { @MainActor in
                if let index = self?.runs.firstIndex(where: { $0.id == run.id }) {
                    self?.runs[index] = run
                }
            }
        }

        trainingService.onRunCompleted = { [weak self] run in
            Task { @MainActor in
                if let index = self?.runs.firstIndex(where: { $0.id == run.id }) {
                    self?.runs[index] = run
                }
                await self?.saveRuns()
                self?.onRunCompleted?(run)
            }
        }
    }

    // MARK: - Data Loading

    func loadRuns() async {
        isLoading = true
        defer { isLoading = false }

        do {
            runs = try await storage.loadRuns()
            Log.debug("Loaded \(runs.count) runs", category: .database)
            await cleanupStaleRuns()
        } catch {
            Log.error("Failed to load runs", error: error, category: .database)
            errorMessage = "Failed to load runs: \(error.localizedDescription)"
        }
    }

    private func cleanupStaleRuns() async {
        var modified = false
        var staleCount = 0

        for i in runs.indices {
            if runs[i].status == .running || runs[i].status == .queued {
                runs[i].status = .cancelled
                runs[i].finishedAt = Date()
                runs[i].logs.append(LogEntry(
                    level: .warning,
                    message: "Training was terminated due to application restart"
                ))
                modified = true
                staleCount += 1
            }
        }

        if modified {
            await saveRuns()
            Log.debug("Cleaned up \(staleCount) stale training run(s) from previous session", category: .training)
        }
    }

    // MARK: - Training Control

    func startTraining(
        modelId: String,
        modelName: String,
        name: String,
        config: TrainingConfig,
        dataset: Dataset?,
        experimentId: String? = nil
    ) async {
        var run = TrainingRun(
            name: name,
            modelId: modelId,
            modelName: modelName,
            epochs: config.epochs,
            batchSize: config.batchSize,
            learningRate: config.learningRate,
            architecture: config.architecture.rawValue
        )
        run.experimentId = experimentId

        runs.insert(run, at: 0)

        if let expId = experimentId {
            Task {
                let repo = TrainingRunRepository()
                try? await repo.create(run, experimentId: expId)
            }
        }

        let updatedRun = await trainingService.startTraining(run: run, config: config, dataset: dataset)

        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = updatedRun
        }

        await saveRuns()
        Log.info("Training started: \(name)", category: .training)
    }

    func pauseTraining(runId: String) {
        trainingService.pauseTraining(runId: runId)
        Log.info("Training paused", category: .training)
    }

    func resumeTraining(runId: String) {
        trainingService.resumeTraining(runId: runId)
        Log.info("Training resumed", category: .training)
    }

    func cancelTraining(runId: String) {
        trainingService.cancelTraining(runId: runId)
        Log.info("Training cancelled", category: .training)
    }

    // MARK: - Run Management

    func deleteRun(_ run: TrainingRun) async {
        if trainingService.isRunning(run.id) {
            trainingService.cancelTraining(runId: run.id)
        }
        // Clean up checkpoints and artifacts for this run
        await cleanupRunResources(runId: run.id)
        runs.removeAll { $0.id == run.id }
        await saveRuns()
        Log.info("Run deleted", category: .training)
    }

    func deleteRuns(_ runsToDelete: [TrainingRun]) async {
        for run in runsToDelete {
            if trainingService.isRunning(run.id) {
                trainingService.cancelTraining(runId: run.id)
            }
            // Clean up checkpoints and artifacts for each run
            await cleanupRunResources(runId: run.id)
        }

        let idsToDelete = Set(runsToDelete.map { $0.id })
        runs.removeAll { idsToDelete.contains($0.id) }
        await saveRuns()
        Log.info("\(runsToDelete.count) runs deleted", category: .training)
    }

    func deleteFailedRuns() async {
        await deleteRuns(failedRuns)
    }

    func deleteAllRuns() async {
        for run in runs {
            if trainingService.isRunning(run.id) {
                trainingService.cancelTraining(runId: run.id)
            }
            // Clean up checkpoints and artifacts for each run
            await cleanupRunResources(runId: run.id)
        }
        runs.removeAll()
        await saveRuns()
        Log.info("All runs deleted", category: .training)
    }

    /// Clean up checkpoints and artifacts associated with a training run
    private func cleanupRunResources(runId: String) async {
        // Delete checkpoints
        do {
            try await CheckpointManager.shared.deleteCheckpoints(runId: runId)
        } catch {
            Log.warning("Failed to delete checkpoints for run \(runId): \(error.localizedDescription)", category: .training)
        }

        // Delete artifacts
        do {
            let artifactRepo = ArtifactRepository()
            try await artifactRepo.deleteByRun(runId)
        } catch {
            Log.warning("Failed to delete artifacts for run \(runId): \(error.localizedDescription)", category: .training)
        }
    }

    // MARK: - Queries

    func runsForModel(_ modelId: String) -> [TrainingRun] {
        runs.filter { $0.modelId == modelId }
    }

    func runsForExperiment(_ experimentId: String) -> [TrainingRun] {
        runs.filter { $0.experimentId == experimentId }
    }

    func isRunning(_ runId: String) -> Bool {
        trainingService.isRunning(runId)
    }

    // MARK: - Private

    private func saveRuns() async {
        do {
            try await storage.saveRuns(runs)
        } catch {
            Log.error("Failed to save runs", error: error, category: .database)
            errorMessage = "Failed to save runs: \(error.localizedDescription)"
        }
    }
}
