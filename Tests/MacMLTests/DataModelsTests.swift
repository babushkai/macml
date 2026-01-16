import XCTest
@testable import MacML

final class DataModelsTests: XCTestCase {
    
    // MARK: - MLModel Tests
    
    func testMLModelInitialization() {
        let model = MLModel(
            name: "TestModel",
            framework: .mlx,
            status: .ready,
            accuracy: 0.95
        )
        
        XCTAssertEqual(model.name, "TestModel")
        XCTAssertEqual(model.framework, .mlx)
        XCTAssertEqual(model.status, .ready)
        XCTAssertEqual(model.accuracy, 0.95)
        XCTAssertFalse(model.id.isEmpty)
    }
    
    func testMLModelDefaultValues() {
        let model = MLModel(name: "Default", framework: .coreML)
        
        XCTAssertEqual(model.status, .draft)
        XCTAssertEqual(model.accuracy, 0)
        XCTAssertEqual(model.fileSize, 0)
        XCTAssertNil(model.filePath)
        XCTAssertTrue(model.metadata.isEmpty)
    }
    
    func testMLModelHashable() {
        let model1 = MLModel(id: "same-id", name: "Model1", framework: .mlx)
        let model2 = MLModel(id: "same-id", name: "Model1", framework: .mlx)
        
        // Identical models should be equal
        XCTAssertEqual(model1.id, model2.id)
        
        // Test that models can be used in a Set
        var modelSet: Set<MLModel> = []
        modelSet.insert(model1)
        XCTAssertTrue(modelSet.contains(model1))
    }
    
    // MARK: - ModelStatus Tests
    
    func testModelStatusIsActive() {
        XCTAssertTrue(ModelStatus.draft.isActive)
        XCTAssertTrue(ModelStatus.ready.isActive)
        XCTAssertTrue(ModelStatus.training.isActive)
        XCTAssertTrue(ModelStatus.deployed.isActive)
        XCTAssertFalse(ModelStatus.archived.isActive)
        XCTAssertFalse(ModelStatus.deprecated.isActive)
    }
    
    func testModelStatusAllCases() {
        XCTAssertEqual(ModelStatus.allCases.count, 8)
    }
    
    // MARK: - MLFramework Tests
    
    func testMLFrameworkFileExtensions() {
        XCTAssertEqual(MLFramework.coreML.fileExtension, "mlmodel")
        XCTAssertEqual(MLFramework.pytorch.fileExtension, "pt")
        XCTAssertEqual(MLFramework.tensorflow.fileExtension, "pb")
        XCTAssertEqual(MLFramework.mlx.fileExtension, "safetensors")
        XCTAssertEqual(MLFramework.onnx.fileExtension, "onnx")
        XCTAssertEqual(MLFramework.custom.fileExtension, "*")
    }
    
    // MARK: - TrainingRun Tests
    
    func testTrainingRunInitialization() {
        let run = TrainingRun(
            name: "TestRun",
            modelId: "model-123",
            modelName: "TestModel",
            epochs: 20,
            batchSize: 64,
            learningRate: 0.01
        )
        
        XCTAssertEqual(run.name, "TestRun")
        XCTAssertEqual(run.modelId, "model-123")
        XCTAssertEqual(run.totalEpochs, 20)
        XCTAssertEqual(run.batchSize, 64)
        XCTAssertEqual(run.learningRate, 0.01)
        XCTAssertEqual(run.status, .queued)
        XCTAssertEqual(run.currentEpoch, 0)
        XCTAssertEqual(run.progress, 0)
    }
    
    func testTrainingRunDurationFormat() {
        var run = TrainingRun(
            name: "TestRun",
            modelId: "model-123",
            modelName: "TestModel"
        )
        
        // Test short duration (seconds only)
        run.finishedAt = run.startedAt.addingTimeInterval(45)
        XCTAssertEqual(run.duration, "45s")
        
        // Test medium duration (minutes)
        run.finishedAt = run.startedAt.addingTimeInterval(125) // 2m 5s
        XCTAssertEqual(run.duration, "2m 5s")
        
        // Test long duration (hours)
        run.finishedAt = run.startedAt.addingTimeInterval(3725) // 1h 2m 5s
        XCTAssertEqual(run.duration, "1h 2m 5s")
    }
    
    // MARK: - RunStatus Tests
    
    func testRunStatusAllCases() {
        XCTAssertEqual(RunStatus.allCases.count, 6)
        XCTAssertTrue(RunStatus.allCases.contains(.queued))
        XCTAssertTrue(RunStatus.allCases.contains(.running))
        XCTAssertTrue(RunStatus.allCases.contains(.paused))
        XCTAssertTrue(RunStatus.allCases.contains(.completed))
        XCTAssertTrue(RunStatus.allCases.contains(.failed))
        XCTAssertTrue(RunStatus.allCases.contains(.cancelled))
    }
    
    // MARK: - LogEntry Tests
    
    func testLogEntryInitialization() {
        let entry = LogEntry(level: .error, message: "Test error message")
        
        XCTAssertEqual(entry.level, .error)
        XCTAssertEqual(entry.message, "Test error message")
        XCTAssertFalse(entry.id.isEmpty)
    }
    
    func testLogLevelPrefix() {
        XCTAssertEqual(LogLevel.info.prefix, "[INFO]")
        XCTAssertEqual(LogLevel.warning.prefix, "[WARN]")
        XCTAssertEqual(LogLevel.error.prefix, "[ERROR]")
        XCTAssertEqual(LogLevel.debug.prefix, "[DEBUG]")
    }
    
    // MARK: - MetricPoint Tests
    
    func testMetricPointInitialization() {
        let metric = MetricPoint(
            epoch: 5,
            loss: 0.25,
            accuracy: 0.92,
            precision: 0.91,
            recall: 0.93,
            f1Score: 0.92
        )
        
        XCTAssertEqual(metric.epoch, 5)
        XCTAssertEqual(metric.loss, 0.25)
        XCTAssertEqual(metric.accuracy, 0.92)
        XCTAssertEqual(metric.precision, 0.91)
        XCTAssertEqual(metric.recall, 0.93)
        XCTAssertEqual(metric.f1Score, 0.92)
    }
    
    func testMetricPointOptionalFields() {
        let metric = MetricPoint(epoch: 1, loss: 1.5, accuracy: 0.5)
        
        XCTAssertNil(metric.precision)
        XCTAssertNil(metric.recall)
        XCTAssertNil(metric.f1Score)
    }
    
    // MARK: - ExtendedMetrics Tests
    
    func testExtendedMetricsCalculation() {
        // Simple binary classification test
        let predictions = [0, 0, 1, 1, 0, 1]
        let labels =      [0, 1, 1, 0, 0, 1]
        
        let metrics = ExtendedMetrics.calculate(
            predictions: predictions,
            labels: labels,
            numClasses: 2
        )
        
        // Verify metrics are calculated (non-zero)
        XCTAssertGreaterThan(metrics.precision, 0)
        XCTAssertGreaterThan(metrics.recall, 0)
        XCTAssertGreaterThan(metrics.f1Score, 0)
        
        // Verify per-class metrics exist
        XCTAssertNotNil(metrics.perClassMetrics)
        XCTAssertEqual(metrics.perClassMetrics?.count, 2)
    }
    
    func testExtendedMetricsEmptyInput() {
        let metrics = ExtendedMetrics.calculate(predictions: [], labels: [], numClasses: 2)
        
        XCTAssertEqual(metrics.precision, 0)
        XCTAssertEqual(metrics.recall, 0)
        XCTAssertEqual(metrics.f1Score, 0)
    }
    
    func testExtendedMetricsMismatchedInput() {
        let metrics = ExtendedMetrics.calculate(
            predictions: [0, 1, 2],
            labels: [0, 1], // Different length
            numClasses: 3
        )
        
        XCTAssertEqual(metrics.precision, 0)
        XCTAssertEqual(metrics.recall, 0)
        XCTAssertEqual(metrics.f1Score, 0)
    }
    
    // MARK: - Dataset Tests
    
    func testDatasetInitialization() {
        let dataset = Dataset(
            name: "MNIST",
            description: "Handwritten digits",
            type: .images,
            sampleCount: 60000,
            classes: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        )
        
        XCTAssertEqual(dataset.name, "MNIST")
        XCTAssertEqual(dataset.description, "Handwritten digits")
        XCTAssertEqual(dataset.type, .images)
        XCTAssertEqual(dataset.sampleCount, 60000)
        XCTAssertEqual(dataset.classes.count, 10)
        XCTAssertEqual(dataset.status, .active)
    }
    
    func testDatasetStatusIsActive() {
        XCTAssertTrue(DatasetStatus.active.isActive)
        XCTAssertTrue(DatasetStatus.processing.isActive)
        XCTAssertFalse(DatasetStatus.archived.isActive)
        XCTAssertFalse(DatasetStatus.deprecated.isActive)
    }
    
    // MARK: - Prediction Tests
    
    func testPredictionInitialization() {
        let prediction = Prediction(label: "cat", confidence: 0.95)
        
        XCTAssertEqual(prediction.label, "cat")
        XCTAssertEqual(prediction.confidence, 0.95)
        XCTAssertFalse(prediction.id.isEmpty)
    }
    
    // MARK: - AppSettings Tests
    
    func testAppSettingsDefault() {
        let settings = AppSettings.default
        
        XCTAssertTrue(settings.gpuEnabled)
        XCTAssertTrue(settings.autoSave)
        XCTAssertTrue(settings.showNotifications)
        XCTAssertEqual(settings.maxConcurrentRuns, 2)
        XCTAssertEqual(settings.defaultEpochs, 10)
        XCTAssertEqual(settings.defaultBatchSize, 32)
        XCTAssertEqual(settings.defaultLearningRate, 0.001)
    }
    
    // MARK: - Helper Function Tests
    
    func testFormatBytes() {
        XCTAssertEqual(formatBytes(0), "Zero KB")
        XCTAssertTrue(formatBytes(1024).contains("1"))
        XCTAssertTrue(formatBytes(1048576).contains("1"))  // 1 MB
    }
    
    func testFormatDuration() {
        XCTAssertEqual(formatDuration(45), "45s")
        XCTAssertEqual(formatDuration(125), "2m 5s")
        XCTAssertEqual(formatDuration(3725), "1h 2m")
    }
    
    // MARK: - Codable Tests
    
    func testMLModelCodable() throws {
        let model = MLModel(
            name: "TestModel",
            framework: .mlx,
            status: .ready,
            accuracy: 0.95
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(model)
        let decoded = try decoder.decode(MLModel.self, from: data)
        
        XCTAssertEqual(model.id, decoded.id)
        XCTAssertEqual(model.name, decoded.name)
        XCTAssertEqual(model.framework, decoded.framework)
        XCTAssertEqual(model.status, decoded.status)
        XCTAssertEqual(model.accuracy, decoded.accuracy)
    }
    
    func testTrainingRunCodable() throws {
        let run = TrainingRun(
            name: "TestRun",
            modelId: "model-123",
            modelName: "TestModel",
            epochs: 20,
            batchSize: 64,
            learningRate: 0.01
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(run)
        let decoded = try decoder.decode(TrainingRun.self, from: data)
        
        XCTAssertEqual(run.id, decoded.id)
        XCTAssertEqual(run.name, decoded.name)
        XCTAssertEqual(run.totalEpochs, decoded.totalEpochs)
        XCTAssertEqual(run.batchSize, decoded.batchSize)
    }
    
    func testDatasetCodable() throws {
        let dataset = Dataset(
            name: "TestDataset",
            type: .images,
            sampleCount: 1000,
            classes: ["a", "b", "c"]
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(dataset)
        let decoded = try decoder.decode(Dataset.self, from: data)
        
        XCTAssertEqual(dataset.id, decoded.id)
        XCTAssertEqual(dataset.name, decoded.name)
        XCTAssertEqual(dataset.sampleCount, decoded.sampleCount)
        XCTAssertEqual(dataset.classes, decoded.classes)
    }
}
