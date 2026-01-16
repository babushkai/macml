import Foundation
import Combine

/// Service for managing knowledge distillation workflows
/// Coordinates teacher model API calls, synthetic data generation, and student model training
@MainActor
class DistillationService: ObservableObject {
    static let shared = DistillationService()

    @Published var activeDistillations: [String: DistillationRun] = [:]
    @Published var isProcessing = false

    // Callbacks for state updates
    var onDistillationUpdated: ((DistillationRun) -> Void)?
    var onDistillationCompleted: ((DistillationRun) -> Void)?

    private var cancellationFlags: [String: Bool] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Public API

    /// Start a new distillation run
    func startDistillation(run: DistillationRun) async -> DistillationRun {
        var updatedRun = run
        updatedRun.status = .generatingData
        updatedRun.phase = "Initializing..."
        updatedRun.startedAt = Date()

        activeDistillations[run.id] = updatedRun
        cancellationFlags[run.id] = false
        onDistillationUpdated?(updatedRun)

        // Start async distillation task
        let task = Task { [weak self] in
            guard let self = self else { return }
            await self.runDistillationPipeline(runId: run.id)
        }
        tasks[run.id] = task

        return updatedRun
    }

    /// Cancel an active distillation run
    func cancelDistillation(runId: String) {
        cancellationFlags[runId] = true
        tasks[runId]?.cancel()

        if var run = activeDistillations[runId] {
            run.status = .cancelled
            run.phase = "Cancelled by user"
            run.finishedAt = Date()
            activeDistillations[runId] = run
            onDistillationUpdated?(run)
            onDistillationCompleted?(run)
        }

        cleanup(runId: runId)
    }

    /// Get current progress for a run
    func getProgress(runId: String) -> Double {
        activeDistillations[runId]?.progress ?? 0
    }

    // MARK: - Pipeline Implementation

    private func runDistillationPipeline(runId: String) async {
        guard var run = activeDistillations[runId] else { return }

        do {
            // Phase 1: Generate synthetic data from teacher
            run = try await generateSyntheticData(run: run)
            if isCancelled(runId) { return }

            // Phase 2: Train student model
            run = try await trainStudentModel(run: run)
            if isCancelled(runId) { return }

            // Phase 3: Evaluate student model
            run = try await evaluateStudent(run: run)
            if isCancelled(runId) { return }

            // Complete
            run.status = .completed
            run.phase = "Completed successfully"
            run.progress = 1.0
            run.finishedAt = Date()
            activeDistillations[runId] = run

            addLog(to: &run, level: .info, message: "Distillation completed successfully!")
            onDistillationUpdated?(run)
            onDistillationCompleted?(run)

        } catch {
            run.status = .failed
            run.phase = "Failed: \(error.localizedDescription)"
            run.finishedAt = Date()
            activeDistillations[runId] = run

            addLog(to: &run, level: .error, message: "Distillation failed: \(error.localizedDescription)")
            onDistillationUpdated?(run)
            onDistillationCompleted?(run)
        }

        cleanup(runId: runId)
    }

    // MARK: - Phase 1: Synthetic Data Generation

    private func generateSyntheticData(run: DistillationRun) async throws -> DistillationRun {
        var updatedRun = run
        updatedRun.status = .generatingData
        updatedRun.phase = "Generating synthetic data from teacher..."
        activeDistillations[run.id] = updatedRun
        onDistillationUpdated?(updatedRun)

        addLog(to: &updatedRun, level: .info, message: "Starting synthetic data generation")
        addLog(to: &updatedRun, level: .info, message: "Teacher: \(run.config.teacherType.rawValue)")
        if let provider = run.config.cloudProvider {
            addLog(to: &updatedRun, level: .info, message: "Provider: \(provider.rawValue)")
        }
        addLog(to: &updatedRun, level: .info, message: "Target samples: \(run.config.syntheticSamples)")

        let totalSamples = run.config.syntheticSamples
        let batchSize = 10
        var samplesGenerated = 0

        // Simulate data generation in batches
        while samplesGenerated < totalSamples {
            if isCancelled(run.id) { return updatedRun }

            let samplesToGenerate = min(batchSize, totalSamples - samplesGenerated)

            // Simulate API call delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            samplesGenerated += samplesToGenerate
            updatedRun.samplesGenerated = samplesGenerated
            updatedRun.apiCallsMade += 1
            updatedRun.estimatedCost = Double(updatedRun.apiCallsMade) * 0.002 // ~$0.002 per call
            updatedRun.progress = Double(samplesGenerated) / Double(totalSamples) * 0.4 // 40% for data gen

            addLog(to: &updatedRun, level: .debug, message: "Generated \(samplesGenerated)/\(totalSamples) samples")

            activeDistillations[run.id] = updatedRun
            onDistillationUpdated?(updatedRun)
        }

        addLog(to: &updatedRun, level: .info, message: "Synthetic data generation complete: \(samplesGenerated) samples")

        return updatedRun
    }

    // MARK: - Phase 2: Student Training

    private func trainStudentModel(run: DistillationRun) async throws -> DistillationRun {
        var updatedRun = run
        updatedRun.status = .training
        updatedRun.phase = "Training student model..."
        activeDistillations[run.id] = updatedRun
        onDistillationUpdated?(updatedRun)

        addLog(to: &updatedRun, level: .info, message: "Starting student model training")
        addLog(to: &updatedRun, level: .info, message: "Architecture: \(run.config.studentArchitecture.rawValue)")
        addLog(to: &updatedRun, level: .info, message: "Epochs: \(run.config.epochs), Batch size: \(run.config.batchSize)")
        addLog(to: &updatedRun, level: .info, message: "Learning rate: \(run.config.learningRate), Alpha: \(run.config.alpha)")

        let totalEpochs = run.config.epochs

        for epoch in 1...totalEpochs {
            if isCancelled(run.id) { return updatedRun }

            // Simulate epoch training
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second per epoch

            updatedRun.currentEpoch = epoch

            // Simulate metrics improvement
            let baseProgress = 0.4 + (Double(epoch) / Double(totalEpochs) * 0.4) // 40%-80% for training
            updatedRun.progress = baseProgress

            // Simulate loss decreasing and accuracy increasing
            let epochProgress = Double(epoch) / Double(totalEpochs)
            let simulatedLoss = 2.5 * exp(-2 * epochProgress) + 0.1 + Double.random(in: -0.05...0.05)
            let simulatedAccuracy = 0.5 + 0.45 * (1 - exp(-3 * epochProgress)) + Double.random(in: -0.02...0.02)

            let metric = MetricPoint(
                epoch: epoch,
                loss: simulatedLoss,
                accuracy: min(1.0, max(0, simulatedAccuracy))
            )
            updatedRun.metrics.append(metric)
            updatedRun.trainLoss = simulatedLoss
            updatedRun.studentAccuracy = simulatedAccuracy

            addLog(to: &updatedRun, level: .info, message: "Epoch \(epoch)/\(totalEpochs) - Loss: \(String(format: "%.4f", simulatedLoss)), Accuracy: \(String(format: "%.2f%%", simulatedAccuracy * 100))")

            activeDistillations[run.id] = updatedRun
            onDistillationUpdated?(updatedRun)
        }

        addLog(to: &updatedRun, level: .info, message: "Student model training complete")

        return updatedRun
    }

    // MARK: - Phase 3: Evaluation

    private func evaluateStudent(run: DistillationRun) async throws -> DistillationRun {
        var updatedRun = run
        updatedRun.status = .evaluating
        updatedRun.phase = "Evaluating student model..."
        updatedRun.progress = 0.85
        activeDistillations[run.id] = updatedRun
        onDistillationUpdated?(updatedRun)

        addLog(to: &updatedRun, level: .info, message: "Starting student model evaluation")

        // Simulate evaluation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        if isCancelled(run.id) { return updatedRun }

        // Final metrics
        let finalAccuracy = 0.85 + Double.random(in: 0...0.1)
        updatedRun.studentAccuracy = finalAccuracy
        updatedRun.compressionRatio = Double.random(in: 50...200) // Teacher is much larger
        updatedRun.progress = 0.95

        addLog(to: &updatedRun, level: .info, message: "Final accuracy: \(String(format: "%.2f%%", finalAccuracy * 100))")
        addLog(to: &updatedRun, level: .info, message: "Compression ratio: \(String(format: "%.1fx", updatedRun.compressionRatio ?? 0))")

        // Save model (simulated)
        try await Task.sleep(nanoseconds: 500_000_000)
        addLog(to: &updatedRun, level: .info, message: "Student model saved to disk")

        activeDistillations[run.id] = updatedRun
        onDistillationUpdated?(updatedRun)

        return updatedRun
    }

    // MARK: - Helpers

    private func isCancelled(_ runId: String) -> Bool {
        cancellationFlags[runId] ?? false
    }

    private func cleanup(runId: String) {
        cancellationFlags.removeValue(forKey: runId)
        tasks.removeValue(forKey: runId)
    }

    private func addLog(to run: inout DistillationRun, level: LogLevel, message: String) {
        let entry = LogEntry(level: level, message: message)
        run.logs.append(entry)
    }
}
