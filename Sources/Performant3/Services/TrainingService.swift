import Foundation
import Combine

@MainActor
class TrainingService: ObservableObject {
    static let shared = TrainingService()

    @Published var activeRuns: [String: TrainingRun] = [:]
    @Published var useRealMLX: Bool = true  // Toggle for real vs simulated training

    private var runTasks: [String: Task<Void, Never>] = [:]
    private var cancellables = Set<AnyCancellable>()

    private let storage = StorageManager.shared
    private let mlxService = MLXTrainingService()
    private let pythonEnv = PythonEnvironmentManager.shared

    // Callbacks for UI updates
    var onRunUpdated: ((TrainingRun) -> Void)?
    var onRunCompleted: ((TrainingRun) -> Void)?

    // Store current training config for each run
    private var runConfigs: [String: TrainingConfig] = [:]

    // Store dataset paths for each run (needed for resume)
    private var runDatasetPaths: [String: String?] = [:]

    // MARK: - Training Control

    func startTraining(run: TrainingRun, config: TrainingConfig, dataset: Dataset?) async -> TrainingRun {
        var updatedRun = run
        updatedRun.status = .running
        updatedRun.logs.append(LogEntry(level: .info, message: "Training started"))
        updatedRun.logs.append(LogEntry(level: .info, message: "Architecture: \(config.architecture.displayName)"))
        updatedRun.logs.append(LogEntry(level: .info, message: "Configuration: epochs=\(run.totalEpochs), batch_size=\(run.batchSize), lr=\(run.learningRate)"))
        updatedRun.logs.append(LogEntry(level: .info, message: "Backend: \(useRealMLX ? "MLX (Apple Silicon)" : "Simulated")"))

        if let dataset = dataset {
            updatedRun.logs.append(LogEntry(level: .info, message: "Using dataset: \(dataset.name) (\(dataset.sampleCount) samples)"))
        }

        activeRuns[run.id] = updatedRun
        runConfigs[run.id] = config
        runDatasetPaths[run.id] = dataset?.path
        onRunUpdated?(updatedRun)

        // Start training task
        let runId = run.id
        let datasetPath = dataset?.path
        let architecture = config.architecture
        let task = Task {
            if architecture.requiresPython {
                // Use Python backend for YOLOv8, etc.
                await self.runPythonTraining(runId: runId, datasetPath: datasetPath, architecture: architecture)
            } else if self.useRealMLX {
                await self.runMLXTraining(runId: runId, datasetPath: datasetPath)
            } else {
                await self.runTrainingLoop(runId: runId)
            }
        }
        runTasks[run.id] = task

        return updatedRun
    }

    // MARK: - Python Backend Training (YOLOv8, etc.)

    private func runPythonTraining(runId: String, datasetPath: String?, architecture: ArchitectureType) async {
        guard var run = activeRuns[runId] else { return }
        guard let config = runConfigs[runId] else { return }

        run.logs.append(LogEntry(level: .info, message: "Initializing Python backend for \(architecture.displayName)..."))
        activeRuns[runId] = run
        onRunUpdated?(run)

        // Ensure Python environment is ready
        do {
            run.logs.append(LogEntry(level: .info, message: "Checking Python environment..."))
            activeRuns[runId] = run
            onRunUpdated?(run)

            try await pythonEnv.ensureReady { [weak self] progress in
                Task { @MainActor in
                    guard var currentRun = self?.activeRuns[runId] else { return }
                    currentRun.logs.append(LogEntry(level: .info, message: progress))
                    self?.activeRuns[runId] = currentRun
                    self?.onRunUpdated?(currentRun)
                }
            }

            run = activeRuns[runId] ?? run
            run.logs.append(LogEntry(level: .info, message: "Python environment ready"))
            activeRuns[runId] = run
            onRunUpdated?(run)
        } catch {
            run.logs.append(LogEntry(level: .error, message: "Python environment setup failed: \(error.localizedDescription)"))
            run.status = .failed
            run.finishedAt = Date()
            activeRuns.removeValue(forKey: runId)
            onRunCompleted?(run)
            return
        }

        // Build Python command - search for script in known locations
        let pythonScript: String
        let possiblePaths = [
            // App bundle (when running as .app)
            Bundle.main.url(forResource: "train_yolov8", withExtension: "py", subdirectory: "Scripts")?.path,
            Bundle.main.resourceURL?.appendingPathComponent("Scripts/train_yolov8.py").path,
            // Relative to executable (SPM build)
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("Performant3_Performant3.bundle/Scripts/train_yolov8.py").path,
            // Development path (relative to working directory)
            FileManager.default.currentDirectoryPath + "/Resources/Scripts/train_yolov8.py",
            // Absolute fallback
            "/Users/dsuke/Projects/dev/peformant3/Resources/Scripts/train_yolov8.py"
        ].compactMap { $0 }

        if let validPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            pythonScript = validPath
        } else {
            run.logs.append(LogEntry(level: .error, message: "Python script not found. Searched: \(possiblePaths.first ?? "none")"))
            run.status = .failed
            run.finishedAt = Date()
            activeRuns.removeValue(forKey: runId)
            onRunCompleted?(run)
            return
        }

        // Determine dataset argument
        let datasetArg: String
        if let path = datasetPath {
            datasetArg = path
        } else {
            // Default to COCO128 for demo
            datasetArg = "coco128"
        }

        // Determine YOLOv8 variant based on model complexity
        let yoloVariant: String
        switch config.batchSize {
        case 1...8: yoloVariant = "yolov8n"    // nano for small batches
        case 9...16: yoloVariant = "yolov8s"   // small
        case 17...32: yoloVariant = "yolov8m"  // medium
        default: yoloVariant = "yolov8l"       // large
        }

        let arguments = [
            pythonScript,
            "--model", yoloVariant,
            "--dataset", datasetArg,
            "--epochs", String(config.epochs),
            "--batch-size", String(config.batchSize),
            "--learning-rate", String(config.learningRate),
            "--device", "mps"  // Use Metal on Mac
        ]

        // Use the managed Python environment
        let pythonPath = await pythonEnv.pythonPath

        run.logs.append(LogEntry(level: .info, message: "Running: \(pythonPath) \(arguments.joined(separator: " "))"))
        activeRuns[runId] = run
        onRunUpdated?(run)

        do {
            let pythonExecutor = PythonExecutor()

            try await pythonExecutor.runScript(
                python: pythonPath,
                arguments: arguments
            ) { [weak self] event in
                Task { @MainActor in
                    guard var currentRun = self?.activeRuns[runId] else { return }

                    switch event {
                    case .metric(let epoch, _, let loss, let accuracy):
                        currentRun.currentEpoch = epoch
                        currentRun.loss = loss
                        currentRun.accuracy = accuracy
                        currentRun.progress = Double(epoch) / Double(config.epochs)

                        if let acc = accuracy {
                            let metric = MetricPoint(epoch: epoch, loss: loss, accuracy: acc)
                            currentRun.metrics.append(metric)
                        }

                    case .log(let level, let message):
                        let logLevel: LogLevel = level == "error" ? .error : (level == "warning" ? .warning : .info)
                        currentRun.logs.append(LogEntry(level: logLevel, message: message))

                    case .progress(let epoch, let totalEpochs, let step, let totalSteps):
                        currentRun.currentEpoch = epoch
                        if let s = step, let ts = totalSteps {
                            let epochProgress = Double(s) / Double(ts)
                            currentRun.progress = (Double(epoch - 1) + epochProgress) / Double(totalEpochs)
                        } else {
                            currentRun.progress = Double(epoch) / Double(totalEpochs)
                        }

                    case .checkpoint(let path, _):
                        currentRun.logs.append(LogEntry(level: .info, message: "Checkpoint saved: \(path)"))

                    case .completed(let finalLoss, let finalAccuracy, let duration):
                        currentRun.status = .completed
                        currentRun.progress = 1.0
                        currentRun.loss = finalLoss
                        currentRun.accuracy = finalAccuracy
                        currentRun.finishedAt = Date()
                        currentRun.logs.append(LogEntry(
                            level: .info,
                            message: String(format: "Training completed in %.1fs - mAP50: %.2f%%", duration, (finalAccuracy ?? 0) * 100)
                        ))

                    case .error(let message):
                        currentRun.logs.append(LogEntry(level: .error, message: message))
                    }

                    self?.activeRuns[runId] = currentRun
                    self?.onRunUpdated?(currentRun)
                }
            }

            // Training completed
            run = activeRuns[runId] ?? run
            if run.status != .completed {
                run.status = .completed
                run.finishedAt = Date()
            }
            activeRuns.removeValue(forKey: runId)
            runTasks.removeValue(forKey: runId)
            onRunCompleted?(run)

        } catch {
            run = activeRuns[runId] ?? run
            run.status = .failed
            run.finishedAt = Date()
            run.logs.append(LogEntry(level: .error, message: "Python training failed: \(error.localizedDescription)"))

            activeRuns.removeValue(forKey: runId)
            runTasks.removeValue(forKey: runId)
            onRunCompleted?(run)
        }
    }

    // MARK: - Real MLX Training

    private func runMLXTraining(runId: String, datasetPath: String?) async {
        guard var run = activeRuns[runId] else { return }
        guard let config = runConfigs[runId] else { return }

        // Get model architecture from config
        let modelConfig = config.architecture.toModelArchitecture()

        run.logs.append(LogEntry(level: .info, message: "Initializing MLX training on Apple Silicon..."))
        activeRuns[runId] = run
        onRunUpdated?(run)

        do {
            let result = try await mlxService.train(
                config: config,
                modelConfig: modelConfig,
                datasetPath: datasetPath,
                runId: runId
            ) { [weak self] progress in
                Task { @MainActor in
                    guard var currentRun = self?.activeRuns[runId] else { return }

                    currentRun.currentEpoch = progress.epoch
                    currentRun.progress = progress.progress
                    currentRun.loss = progress.loss
                    currentRun.accuracy = progress.accuracy

                    // Add metric point
                    if let accuracy = progress.accuracy {
                        let metric = MetricPoint(epoch: progress.epoch, loss: progress.loss, accuracy: accuracy)
                        currentRun.metrics.append(metric)
                    }

                    // Add log message if present
                    if let message = progress.message {
                        currentRun.logs.append(LogEntry(level: .info, message: message))
                    }

                    self?.activeRuns[runId] = currentRun
                    self?.onRunUpdated?(currentRun)
                }
            }

            // Training completed successfully
            run = activeRuns[runId] ?? run
            run.status = .completed
            run.progress = 1.0
            run.finishedAt = Date()
            run.loss = result.finalLoss
            run.accuracy = result.finalAccuracy
            run.logs.append(LogEntry(level: .info, message: "Training completed successfully"))
            run.logs.append(LogEntry(
                level: .info,
                message: String(format: "Final metrics - loss: %.4f, accuracy: %.2f%%, time: %.1fs",
                               result.finalLoss, (result.finalAccuracy ?? 0) * 100, result.totalTime)
            ))

            activeRuns.removeValue(forKey: runId)
            runTasks.removeValue(forKey: runId)
            onRunCompleted?(run)

        } catch {
            run = activeRuns[runId] ?? run
            run.status = .failed
            run.finishedAt = Date()
            run.logs.append(LogEntry(level: .error, message: "Training failed: \(error.localizedDescription)"))

            activeRuns.removeValue(forKey: runId)
            runTasks.removeValue(forKey: runId)
            onRunCompleted?(run)
        }
    }

    func pauseTraining(runId: String) {
        guard var run = activeRuns[runId] else { return }
        run.status = .paused
        run.logs.append(LogEntry(level: .info, message: "Training paused at epoch \(run.currentEpoch)"))
        activeRuns[runId] = run
        onRunUpdated?(run)

        // Cancel the task but keep the run
        runTasks[runId]?.cancel()
        runTasks.removeValue(forKey: runId)
    }

    func resumeTraining(runId: String) {
        guard var run = activeRuns[runId], run.status == .paused else { return }
        run.status = .running
        run.logs.append(LogEntry(level: .info, message: "Training resumed from epoch \(run.currentEpoch)"))
        activeRuns[runId] = run
        onRunUpdated?(run)

        // Resume training task based on architecture
        let capturedRunId = runId
        let datasetPath = runDatasetPaths[runId] ?? nil
        let config = runConfigs[runId]
        let task = Task {
            if let config = config, config.architecture.requiresPython {
                await self.runPythonTraining(runId: capturedRunId, datasetPath: datasetPath, architecture: config.architecture)
            } else if self.useRealMLX {
                await self.runMLXTraining(runId: capturedRunId, datasetPath: datasetPath)
            } else {
                await self.runTrainingLoop(runId: capturedRunId)
            }
        }
        runTasks[runId] = task
    }

    /// Resume training from a checkpoint file
    func resumeFromCheckpoint(checkpointPath: String, run: TrainingRun, config: TrainingConfig, dataset: Dataset?) async -> TrainingRun {
        var updatedRun = run
        updatedRun.status = .running
        updatedRun.logs.append(LogEntry(level: .info, message: "Resuming training from checkpoint: \(checkpointPath)"))

        activeRuns[run.id] = updatedRun
        runConfigs[run.id] = config
        runDatasetPaths[run.id] = dataset?.path
        onRunUpdated?(updatedRun)

        let runId = run.id
        let datasetPath = dataset?.path
        let architecture = config.architecture

        let task = Task {
            if architecture.requiresPython {
                await self.runPythonTrainingWithResume(
                    runId: runId,
                    datasetPath: datasetPath,
                    architecture: architecture,
                    checkpointPath: checkpointPath
                )
            } else {
                // For MLX training, we need to load the checkpoint
                await self.runMLXTraining(runId: runId, datasetPath: datasetPath)
            }
        }
        runTasks[run.id] = task

        return updatedRun
    }

    /// Run Python training with resume from checkpoint
    private func runPythonTrainingWithResume(
        runId: String,
        datasetPath: String?,
        architecture: ArchitectureType,
        checkpointPath: String
    ) async {
        guard var run = activeRuns[runId] else { return }
        guard let config = runConfigs[runId] else { return }

        run.logs.append(LogEntry(level: .info, message: "Loading checkpoint for resume..."))
        activeRuns[runId] = run
        onRunUpdated?(run)

        // Ensure Python environment is ready
        do {
            try await pythonEnv.ensureReady()
        } catch {
            run.logs.append(LogEntry(level: .error, message: "Python environment setup failed: \(error.localizedDescription)"))
            run.status = .failed
            run.finishedAt = Date()
            activeRuns.removeValue(forKey: runId)
            onRunCompleted?(run)
            return
        }

        // Build Python command with resume flag
        let pythonScript: String
        let possiblePaths = [
            Bundle.main.url(forResource: "train_yolov8", withExtension: "py", subdirectory: "Scripts")?.path,
            Bundle.main.resourceURL?.appendingPathComponent("Scripts/train_yolov8.py").path,
            FileManager.default.currentDirectoryPath + "/Resources/Scripts/train_yolov8.py",
            "/Users/dsuke/Projects/dev/peformant3/Resources/Scripts/train_yolov8.py"
        ].compactMap { $0 }

        if let validPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            pythonScript = validPath
        } else {
            run.logs.append(LogEntry(level: .error, message: "Python script not found"))
            run.status = .failed
            run.finishedAt = Date()
            activeRuns.removeValue(forKey: runId)
            onRunCompleted?(run)
            return
        }

        let datasetArg = datasetPath ?? "coco128"

        // Calculate remaining epochs
        let remainingEpochs = config.epochs - run.currentEpoch

        let arguments = [
            pythonScript,
            "--model", checkpointPath,  // Use checkpoint as model
            "--dataset", datasetArg,
            "--epochs", String(remainingEpochs),
            "--batch-size", String(config.batchSize),
            "--learning-rate", String(config.learningRate),
            "--device", "mps",
            "--resume"  // Add resume flag
        ]

        let pythonPath = await pythonEnv.pythonPath
        run.logs.append(LogEntry(level: .info, message: "Resuming from epoch \(run.currentEpoch + 1)"))
        activeRuns[runId] = run
        onRunUpdated?(run)

        do {
            let pythonExecutor = PythonExecutor()
            try await pythonExecutor.runScript(python: pythonPath, arguments: arguments) { [weak self] event in
                Task { @MainActor in
                    self?.handlePythonTrainingEvent(event, runId: runId, totalEpochs: config.epochs)
                }
            }

            run = activeRuns[runId] ?? run
            if run.status != .completed {
                run.status = .completed
                run.finishedAt = Date()
            }
            activeRuns.removeValue(forKey: runId)
            runTasks.removeValue(forKey: runId)
            onRunCompleted?(run)

        } catch {
            run = activeRuns[runId] ?? run
            run.status = .failed
            run.finishedAt = Date()
            run.logs.append(LogEntry(level: .error, message: "Resume failed: \(error.localizedDescription)"))
            activeRuns.removeValue(forKey: runId)
            runTasks.removeValue(forKey: runId)
            onRunCompleted?(run)
        }
    }

    /// Handle Python training events (extracted for reuse)
    private func handlePythonTrainingEvent(_ event: PythonExecutor.TrainingEvent, runId: String, totalEpochs: Int) {
        guard var currentRun = activeRuns[runId] else { return }

        switch event {
        case .metric(let epoch, _, let loss, let accuracy):
            currentRun.currentEpoch = epoch
            currentRun.loss = loss
            currentRun.accuracy = accuracy
            currentRun.progress = Double(epoch) / Double(totalEpochs)
            if let acc = accuracy {
                let metric = MetricPoint(epoch: epoch, loss: loss, accuracy: acc)
                currentRun.metrics.append(metric)
            }

        case .log(let level, let message):
            let logLevel: LogLevel = level == "error" ? .error : (level == "warning" ? .warning : .info)
            currentRun.logs.append(LogEntry(level: logLevel, message: message))

        case .progress(let epoch, let totalEpochs, let step, let totalSteps):
            currentRun.currentEpoch = epoch
            if let s = step, let ts = totalSteps {
                let epochProgress = Double(s) / Double(ts)
                currentRun.progress = (Double(epoch - 1) + epochProgress) / Double(totalEpochs)
            } else {
                currentRun.progress = Double(epoch) / Double(totalEpochs)
            }

        case .checkpoint(let path, _):
            currentRun.logs.append(LogEntry(level: .info, message: "Checkpoint saved: \(path)"))

        case .completed(let finalLoss, let finalAccuracy, let duration):
            currentRun.status = .completed
            currentRun.progress = 1.0
            currentRun.loss = finalLoss
            currentRun.accuracy = finalAccuracy
            currentRun.finishedAt = Date()
            currentRun.logs.append(LogEntry(
                level: .info,
                message: String(format: "Training completed in %.1fs - mAP50: %.2f%%", duration, (finalAccuracy ?? 0) * 100)
            ))

        case .error(let message):
            currentRun.logs.append(LogEntry(level: .error, message: message))
        }

        activeRuns[runId] = currentRun
        onRunUpdated?(currentRun)
    }

    func cancelTraining(runId: String) {
        runTasks[runId]?.cancel()
        runTasks.removeValue(forKey: runId)

        guard var run = activeRuns[runId] else { return }
        run.status = .cancelled
        run.finishedAt = Date()
        run.logs.append(LogEntry(level: .warning, message: "Training cancelled by user"))
        activeRuns.removeValue(forKey: runId)
        onRunCompleted?(run)
    }

    // MARK: - Training Loop

    private func runTrainingLoop(runId: String) async {
        // Get the current state of the run
        guard var run = activeRuns[runId] else { return }

        // Simulate training epochs
        while run.currentEpoch < run.totalEpochs && !Task.isCancelled {
            // Re-check state from activeRuns in case it was modified (e.g., paused)
            guard let currentRun = activeRuns[runId], currentRun.status == .running else {
                break
            }
            run = currentRun

            run.currentEpoch += 1

            // Simulate epoch training time (1-3 seconds per epoch for demo)
            let epochDuration = Double.random(in: 1.0...3.0)

            // Simulate batch progress within epoch
            let batchCount = 10
            for batch in 1...batchCount {
                // Check if cancelled or paused
                if Task.isCancelled { break }
                if let current = activeRuns[runId], current.status != .running { break }

                try? await Task.sleep(nanoseconds: UInt64(epochDuration / Double(batchCount) * 1_000_000_000))

                // Update progress
                let epochProgress = Double(batch) / Double(batchCount)
                run.progress = (Double(run.currentEpoch - 1) + epochProgress) / Double(run.totalEpochs)
                activeRuns[runId] = run

                // Update UI
                onRunUpdated?(run)
            }

            // Check again if we should continue
            if Task.isCancelled { break }
            if let current = activeRuns[runId], current.status != .running { break }

            // Simulate metrics for this epoch
            let baseLoss = 2.5 * exp(-0.3 * Double(run.currentEpoch))
            let noise = Double.random(in: -0.1...0.1)
            let loss = max(0.01, baseLoss + noise)

            let baseAccuracy = 1.0 - exp(-0.4 * Double(run.currentEpoch))
            let accNoise = Double.random(in: -0.02...0.02)
            let accuracy = min(0.99, max(0.1, baseAccuracy + accNoise))

            let metric = MetricPoint(epoch: run.currentEpoch, loss: loss, accuracy: accuracy)
            run.metrics.append(metric)
            run.loss = loss
            run.accuracy = accuracy

            run.logs.append(LogEntry(
                level: .info,
                message: String(format: "Epoch %d/%d - loss: %.4f, accuracy: %.2f%%",
                               run.currentEpoch, run.totalEpochs, loss, accuracy * 100)
            ))

            activeRuns[runId] = run
            onRunUpdated?(run)
        }

        // Training completed
        if !Task.isCancelled {
            // Check if it was paused (status changed) vs completed
            if let currentRun = activeRuns[runId], currentRun.status == .paused {
                // Just update the stored run with current metrics
                return
            }

            // Check if still running (completed all epochs)
            if run.currentEpoch >= run.totalEpochs {
                run.status = .completed
                run.progress = 1.0
                run.finishedAt = Date()
                run.logs.append(LogEntry(level: .info, message: "Training completed successfully"))
                run.logs.append(LogEntry(
                    level: .info,
                    message: String(format: "Final metrics - loss: %.4f, accuracy: %.2f%%",
                                   run.loss ?? 0, (run.accuracy ?? 0) * 100)
                ))

                activeRuns.removeValue(forKey: runId)
                runTasks.removeValue(forKey: runId)

                onRunCompleted?(run)
            }
        }
    }

    // MARK: - Queries

    func isRunning(_ runId: String) -> Bool {
        activeRuns[runId]?.status == .running
    }

    func getActiveRuns() -> [TrainingRun] {
        Array(activeRuns.values)
    }

    func getRunProgress(_ runId: String) -> Double {
        activeRuns[runId]?.progress ?? 0
    }
}

// MARK: - Training Configuration

struct TrainingConfig: Codable {
    var epochs: Int
    var batchSize: Int
    var learningRate: Double
    var optimizer: Optimizer
    var lossFunction: LossFunction
    var validationSplit: Double
    var earlyStopping: Bool
    var patience: Int
    var architecture: ArchitectureType
    var saveCheckpoints: Bool
    var checkpointFrequency: Int
    var keepCheckpoints: Int
    var allowSyntheticFallback: Bool  // If true, allows fallback to synthetic data when dataset fails

    static var `default`: TrainingConfig {
        TrainingConfig(
            epochs: 30,  // Increased from 10 - MNIST needs more epochs for >95% accuracy
            batchSize: 64,  // Larger batches for better gradient estimates
            learningRate: 0.001,
            optimizer: .adam,
            lossFunction: .crossEntropy,
            validationSplit: 0.2,
            earlyStopping: true,
            patience: 5,  // More patience before stopping
            architecture: .mlp,
            saveCheckpoints: true,
            checkpointFrequency: 5,
            keepCheckpoints: 3,
            allowSyntheticFallback: true  // Enable by default for easier testing
        )
    }
}

enum ArchitectureType: String, Codable, CaseIterable {
    case mlp = "MLP"
    case cnn = "CNN"
    case resnet = "ResNet"
    case transformer = "Transformer"
    case yolov8 = "YOLOv8"

    var displayName: String {
        switch self {
        case .mlp: return "Multi-Layer Perceptron"
        case .cnn: return "Convolutional Neural Network"
        case .resnet: return "ResNet (Residual Network)"
        case .transformer: return "Transformer"
        case .yolov8: return "YOLOv8 (Object Detection)"
        }
    }

    var description: String {
        switch self {
        case .mlp: return "Simple dense layers, good for tabular data"
        case .cnn: return "Image classification with spatial features"
        case .resnet: return "Deep network with skip connections"
        case .transformer: return "Attention-based architecture"
        case .yolov8: return "Real-time object detection (COCO, custom)"
        }
    }

    var icon: String {
        switch self {
        case .mlp: return "point.3.connected.trianglepath.dotted"
        case .cnn: return "square.grid.3x3.topleft.filled"
        case .resnet: return "arrow.triangle.branch"
        case .transformer: return "brain.head.profile"
        case .yolov8: return "viewfinder"
        }
    }

    /// Whether this architecture requires Python backend
    var requiresPython: Bool {
        switch self {
        case .yolov8: return true
        default: return false
        }
    }

    /// Whether this is an object detection architecture
    var isObjectDetection: Bool {
        switch self {
        case .yolov8: return true
        default: return false
        }
    }

    func toModelArchitecture() -> ModelArchitecture {
        switch self {
        case .mlp: return .defaultMLP
        case .cnn: return .defaultCNN
        case .resnet: return .defaultResNet
        case .transformer: return .defaultTransformer
        case .yolov8: return .defaultMLP // Placeholder - uses Python backend
        }
    }
}

enum Optimizer: String, Codable, CaseIterable {
    case sgd = "SGD"
    case adam = "Adam"
    case adamw = "AdamW"
    case rmsprop = "RMSprop"
}

enum LossFunction: String, Codable, CaseIterable {
    case crossEntropy = "Cross Entropy"
    case mse = "Mean Squared Error"
    case bce = "Binary Cross Entropy"
    case huber = "Huber Loss"
}
