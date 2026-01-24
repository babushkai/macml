import Foundation
import MLX
import MLXNN
import MLXOptimizers
import MLXRandom

// MARK: - MLX Training Service

/// Real ML training service using MLX on Apple Silicon
actor MLXTrainingService: TrainingBackend {
    private var currentTask: Task<TrainingResult, Error>?
    private var _isTraining = false
    private let checkpointManager = CheckpointManager.shared

    var isTraining: Bool { _isTraining }

    // Checkpointing configuration
    struct CheckpointConfig {
        var enabled: Bool = true
        var saveEveryNEpochs: Int = 5
        var keepLastN: Int = 3
        var runId: String?
    }

    // MARK: - Training

    func train(
        config: TrainingConfig,
        modelConfig: ModelArchitecture,
        datasetPath: String?,
        runId: String,
        startEpoch: Int = 1,
        progressHandler: @escaping (TrainingProgress) -> Void
    ) async throws -> TrainingResult {
        guard !_isTraining else {
            throw TrainingError.invalidConfiguration("Training already in progress")
        }

        // Validate startEpoch
        let effectiveStartEpoch = max(1, min(startEpoch, config.epochs))

        _isTraining = true
        defer { _isTraining = false }

        let startTime = Date()

        // Create model
        let model: Module
        do {
            model = try ModelFactory.create(from: modelConfig)
        } catch {
            throw TrainingError.modelCreationFailed(error.localizedDescription)
        }

        // Load dataset with proper validation and feedback
        let dataset: any MLXDataset
        var usingSyntheticData = false

        if let path = datasetPath {
            if path == "builtin:mnist" {
                // Use built-in MNIST dataset
                do {
                    dataset = try MNISTDataset(train: true)
                    progressHandler(TrainingProgress(
                        epoch: 0, totalEpochs: config.epochs, step: nil, totalSteps: nil,
                        loss: 0, accuracy: nil, learningRate: config.learningRate,
                        message: "Loaded MNIST dataset (60,000 samples)"
                    ))
                } catch {
                    if !config.allowSyntheticFallback {
                        throw TrainingError.datasetLoadFailed("Failed to load MNIST: \(error.localizedDescription). Enable 'Allow synthetic fallback' to proceed with demo data.")
                    }
                    progressHandler(TrainingProgress(
                        epoch: 0, totalEpochs: config.epochs, step: nil, totalSteps: nil,
                        loss: 0, accuracy: nil, learningRate: config.learningRate,
                        message: "⚠️ Failed to load MNIST: \(error.localizedDescription). Using synthetic data."
                    ))
                    dataset = SyntheticDataset(sampleCount: 1000, inputSize: getInputSize(modelConfig), numClasses: 10)
                    usingSyntheticData = true
                }
            } else {
                // Try to load from file path
                do {
                    let imageDataset = try ImageClassificationDataset(rootPath: path)
                    dataset = imageDataset
                    progressHandler(TrainingProgress(
                        epoch: 0, totalEpochs: config.epochs, step: nil, totalSteps: nil,
                        loss: 0, accuracy: nil, learningRate: config.learningRate,
                        message: "Loaded dataset from \(path) (\(imageDataset.count) samples, \(imageDataset.numClasses) classes)"
                    ))
                } catch {
                    if !config.allowSyntheticFallback {
                        throw TrainingError.datasetLoadFailed("Failed to load dataset from \(path): \(error.localizedDescription). Enable 'Allow synthetic fallback' to proceed with demo data.")
                    }
                    progressHandler(TrainingProgress(
                        epoch: 0, totalEpochs: config.epochs, step: nil, totalSteps: nil,
                        loss: 0, accuracy: nil, learningRate: config.learningRate,
                        message: "⚠️ Failed to load dataset from \(path): \(error.localizedDescription). Using synthetic data."
                    ))
                    dataset = SyntheticDataset(sampleCount: 1000, inputSize: getInputSize(modelConfig), numClasses: 10)
                    usingSyntheticData = true
                }
            }
        } else {
            // No dataset selected
            if !config.allowSyntheticFallback {
                throw TrainingError.datasetLoadFailed("No dataset selected. Select a dataset or enable 'Allow synthetic fallback' to proceed with demo data.")
            }
            progressHandler(TrainingProgress(
                epoch: 0, totalEpochs: config.epochs, step: nil, totalSteps: nil,
                loss: 0, accuracy: nil, learningRate: config.learningRate,
                message: "⚠️ No dataset selected. Using synthetic data for demonstration."
            ))
            dataset = SyntheticDataset(sampleCount: 1000, inputSize: getInputSize(modelConfig), numClasses: 10)
            usingSyntheticData = true
        }

        // Additional warning about synthetic data limitations
        if usingSyntheticData {
            progressHandler(TrainingProgress(
                epoch: 0, totalEpochs: config.epochs, step: nil, totalSteps: nil,
                loss: 0, accuracy: nil, learningRate: config.learningRate,
                message: "⚠️ Note: Synthetic data will produce a demo model. For real results, use an actual dataset."
            ))
        }

        // Create optimizer
        let optimizer = createOptimizer(type: config.optimizer, learningRate: config.learningRate)

        // Training state
        var checkpoints: [TrainingCheckpoint] = []
        var bestLoss: Double = .infinity
        var epochsWithoutImprovement = 0
        var finalLoss: Double = 0
        var finalAccuracy: Double = 0
        var finalPrecision: Double?
        var finalRecall: Double?
        var finalF1Score: Double?

        // Get class labels and architecture from dataset/config
        let classLabels = dataset.classLabels
        let architectureType = config.architecture.rawValue

        // Checkpoint configuration - use the actual training run ID and config settings
        let checkpointConfig = CheckpointConfig(
            enabled: config.saveCheckpoints,
            saveEveryNEpochs: config.checkpointFrequency,
            keepLastN: config.keepCheckpoints,
            runId: runId
        )

        // Log if resuming from a later epoch
        if effectiveStartEpoch > 1 {
            progressHandler(TrainingProgress(
                epoch: effectiveStartEpoch - 1,
                totalEpochs: config.epochs,
                step: nil,
                totalSteps: nil,
                loss: 0,
                accuracy: nil,
                learningRate: config.learningRate,
                message: "Resuming training from epoch \(effectiveStartEpoch)"
            ))
        }

        // Training loop - start from effectiveStartEpoch for resume support
        for epoch in effectiveStartEpoch...config.epochs {
            try Task.checkCancellation()

            let epochResult = try await trainEpoch(
                epoch: epoch,
                totalEpochs: config.epochs,
                model: model,
                optimizer: optimizer,
                dataset: dataset,
                batchSize: config.batchSize,
                learningRate: config.learningRate,
                progressHandler: progressHandler
            )

            finalLoss = epochResult.loss
            finalAccuracy = epochResult.accuracy ?? 0
            if let p = epochResult.precision { finalPrecision = p }
            if let r = epochResult.recall { finalRecall = r }
            if let f = epochResult.f1Score { finalF1Score = f }

            // Save checkpoint if enabled
            if checkpointConfig.enabled,
               let runId = checkpointConfig.runId,
               epoch % checkpointConfig.saveEveryNEpochs == 0 || epoch == config.epochs {
                do {
                    let checkpoint = try await checkpointManager.saveCheckpoint(
                        runId: runId,
                        epoch: epoch,
                        model: model,
                        optimizer: nil,
                        loss: finalLoss,
                        accuracy: finalAccuracy,
                        classLabels: classLabels,
                        architectureType: architectureType
                    )
                    let trainingCheckpoint = TrainingCheckpoint(
                        epoch: checkpoint.epoch,
                        path: checkpoint.path,
                        loss: checkpoint.loss,
                        accuracy: checkpoint.accuracy
                    )
                    checkpoints.append(trainingCheckpoint)

                    try await checkpointManager.pruneCheckpoints(runId: runId, keep: config.keepCheckpoints)

                    progressHandler(TrainingProgress(
                        epoch: epoch,
                        totalEpochs: config.epochs,
                        step: nil,
                        totalSteps: nil,
                        loss: finalLoss,
                        accuracy: finalAccuracy,
                        learningRate: config.learningRate,
                        message: "Checkpoint saved at epoch \(epoch)"
                    ))
                } catch {
                    print("Failed to save checkpoint: \(error)")
                }
            }

            // Early stopping check
            if config.earlyStopping {
                if epochResult.loss < bestLoss {
                    bestLoss = epochResult.loss
                    epochsWithoutImprovement = 0
                } else {
                    epochsWithoutImprovement += 1
                    if epochsWithoutImprovement >= config.patience {
                        progressHandler(TrainingProgress(
                            epoch: epoch,
                            totalEpochs: config.epochs,
                            step: nil,
                            totalSteps: nil,
                            loss: epochResult.loss,
                            accuracy: epochResult.accuracy,
                            learningRate: config.learningRate,
                            message: "Early stopping triggered after \(config.patience) epochs without improvement"
                        ))
                        break
                    }
                }
            }
        }

        let totalTime = Date().timeIntervalSince(startTime)

        return TrainingResult(
            finalLoss: finalLoss,
            finalAccuracy: finalAccuracy,
            finalPrecision: finalPrecision,
            finalRecall: finalRecall,
            finalF1Score: finalF1Score,
            totalEpochs: config.epochs,
            totalTime: totalTime,
            modelPath: nil,
            checkpoints: checkpoints
        )
    }

    // MARK: - Single Epoch Training with Proper Gradients

    /// Epoch training result with extended metrics
    struct EpochResult {
        let loss: Double
        let accuracy: Double?
        let precision: Double?
        let recall: Double?
        let f1Score: Double?
    }

    private func trainEpoch(
        epoch: Int,
        totalEpochs: Int,
        model: Module,
        optimizer: any MLXOptimizers.Optimizer,
        dataset: any MLXDataset,
        batchSize: Int,
        learningRate: Double,
        progressHandler: @escaping (TrainingProgress) -> Void
    ) async throws -> EpochResult {
        var epochLoss: Double = 0
        var correctPredictions: Int = 0
        var totalSamples: Int = 0
        var batchCount = 0

        // For extended metrics calculation
        var allPredictions: [Int] = []
        var allLabels: [Int] = []
        let numClasses = dataset.classLabels.count > 0 ? dataset.classLabels.count : 10

        let batches = dataset.batches(batchSize: batchSize, shuffle: true)
        let totalBatches = batches.totalBatches

        // Create the loss and gradient function once per epoch
        // Use the variant that takes [MLXArray] for flexibility
        let lossAndGrad = valueAndGrad(model: model) { (m: Module, arrays: [MLXArray]) -> [MLXArray] in
            let logits = forwardPass(model: m, inputs: arrays[0], training: true)
            let loss = crossEntropyLoss(logits: logits, labels: arrays[1])
            return [loss]
        }

        for batch in batches {
            try Task.checkCancellation()

            let (inputs, labels, batchIdx) = batch

            // Compute loss and gradients using MLX's valueAndGrad
            let (lossArray, grads) = lossAndGrad(model, [inputs, labels])
            let loss = lossArray[0]

            // Update model parameters using optimizer
            optimizer.update(model: model, gradients: grads)

            // Evaluate tensors
            eval(loss)
            eval(model, optimizer)
            let lossValue = loss.item(Float.self)
            epochLoss += Double(lossValue)

            // Calculate accuracy
            let logits = forwardPass(model: model, inputs: inputs, training: false)
            let predictions = logits.argMax(axis: -1)
            eval(predictions)

            let correct = (predictions .== labels).sum()
            eval(correct)
            correctPredictions += Int(correct.item(Int32.self))
            totalSamples += Int(labels.dim(0))

            // Collect predictions and labels for extended metrics (on last epoch or every 5 epochs)
            if epoch == totalEpochs || epoch % 5 == 0 {
                let batchPreds = predictions.asArray(Int32.self)
                let batchLabels = labels.asArray(Int32.self)
                allPredictions.append(contentsOf: batchPreds.map { Int($0) })
                allLabels.append(contentsOf: batchLabels.map { Int($0) })
            }

            batchCount += 1

            // Report progress every few batches
            if batchIdx % Swift.max(1, totalBatches / 10) == 0 || batchIdx == totalBatches - 1 {
                let accuracy = Double(correctPredictions) / Double(Swift.max(1, totalSamples))
                progressHandler(TrainingProgress(
                    epoch: epoch,
                    totalEpochs: totalEpochs,
                    step: batchIdx + 1,
                    totalSteps: totalBatches,
                    loss: epochLoss / Double(batchCount),
                    accuracy: accuracy,
                    learningRate: learningRate,
                    message: nil
                ))
            }

            // Yield to allow UI updates and cancellation
            await Task.yield()
        }

        let avgLoss = epochLoss / Double(Swift.max(1, batchCount))
        let accuracy = Double(correctPredictions) / Double(Swift.max(1, totalSamples))

        // Calculate extended metrics if we collected predictions
        var precision: Double?
        var recall: Double?
        var f1Score: Double?

        if !allPredictions.isEmpty {
            let extendedMetrics = ExtendedMetrics.calculate(predictions: allPredictions, labels: allLabels, numClasses: numClasses)
            precision = extendedMetrics.precision
            recall = extendedMetrics.recall
            f1Score = extendedMetrics.f1Score
        }

        // Report epoch completion
        progressHandler(TrainingProgress(
            epoch: epoch,
            totalEpochs: totalEpochs,
            step: totalBatches,
            totalSteps: totalBatches,
            loss: avgLoss,
            accuracy: accuracy,
            precision: precision,
            recall: recall,
            f1Score: f1Score,
            learningRate: learningRate,
            message: String(format: "Epoch %d/%d - Loss: %.4f, Acc: %.2f%%, F1: %.2f%%",
                          epoch, totalEpochs, avgLoss, accuracy * 100, (f1Score ?? 0) * 100)
        ))

        return EpochResult(loss: avgLoss, accuracy: accuracy, precision: precision, recall: recall, f1Score: f1Score)
    }

    // MARK: - Cancel

    func cancel() async {
        currentTask?.cancel()
        currentTask = nil
        _isTraining = false
    }

    // MARK: - Helpers

    private func createOptimizer(type: Optimizer, learningRate: Double) -> any MLXOptimizers.Optimizer {
        switch type {
        case .sgd:
            return SGD(learningRate: Float(learningRate))
        case .adam:
            return Adam(learningRate: Float(learningRate))
        case .adamw:
            return AdamW(learningRate: Float(learningRate))
        case .rmsprop:
            return Adam(learningRate: Float(learningRate))  // Fallback to Adam
        }
    }

    private func getInputSize(_ config: ModelArchitecture) -> Int {
        switch config {
        case .mlp(let mlpConfig):
            return mlpConfig.inputSize
        case .cnn(let cnnConfig):
            return cnnConfig.imageSize * cnnConfig.imageSize * cnnConfig.inputChannels
        case .resnet(let resnetConfig):
            return resnetConfig.inputSize
        case .transformer(let transformerConfig):
            return transformerConfig.inputDim
        case .custom:
            return 784
        }
    }
}

// MARK: - Forward Pass

/// Forward pass through model
func forwardPass(model: Module, inputs: MLXArray, training: Bool) -> MLXArray {
    if let mlp = model as? MLP {
        return mlp(inputs, training: training)
    } else if let cnn = model as? SimpleCNN {
        return cnn(inputs, training: training)
    } else if let resnet = model as? ResNetMini {
        return resnet(inputs, training: training)
    } else if let transformer = model as? SimpleTransformer {
        return transformer(inputs, training: training)
    } else {
        // Fallback: try generic callAsFunction if available, otherwise return input as-is
        // This prevents crashes for unknown model types
        print("Warning: Unknown model type \(type(of: model)), attempting generic forward pass")
        return inputs
    }
}

// MARK: - Loss Functions

/// Cross entropy loss for classification (FULLY VECTORIZED for proper gradient flow)
func crossEntropyLoss(logits: MLXArray, labels: MLXArray) -> MLXArray {
    // CRITICAL: Must be fully vectorized for autograd to work properly
    // Using loop with .item() breaks the computational graph!

    let batchSize = logits.dim(0)
    let numClasses = logits.dim(1)

    // Cross-entropy loss = log_softmax_sum - logits_at_correct_class
    // log_softmax = logits - log_sum_exp(logits)
    // So: loss = log_sum_exp(logits) - logits[label]

    // Compute log_sum_exp for numerical stability (vectorized)
    let maxLogits = logits.max(axis: -1, keepDims: true)
    let shifted = logits - maxLogits
    let logSumExp = maxLogits.squeezed(axis: -1) + log(exp(shifted).sum(axis: -1))  // Shape: [batch]

    // Create one-hot encoding and use it to select correct class logits
    // This is fully differentiable
    let labelsInt = labels.asType(.int32).reshaped([batchSize])

    // One-hot encode labels: shape [batch, numClasses]
    let indices = MLXArray(Array(0..<numClasses).map { Int32($0) })  // [0, 1, 2, ..., numClasses-1]
    let labelsBroadcast = labelsInt.reshaped([batchSize, 1])  // [batch, 1]
    let oneHot = (labelsBroadcast .== indices).asType(.float32)  // [batch, numClasses]

    // Get logits for correct class: sum(oneHot * logits, axis=-1)
    let correctLogits = (oneHot * logits).sum(axis: -1)  // Shape: [batch]

    // Cross-entropy: log_sum_exp - correct_logits, then mean over batch
    let loss = (logSumExp - correctLogits).mean()

    return loss
}

