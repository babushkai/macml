import XCTest
@testable import MacML

final class TrainingConfigTests: XCTestCase {
    
    // MARK: - TrainingConfig Tests
    
    func testDefaultConfig() {
        let config = TrainingConfig.default
        
        XCTAssertEqual(config.epochs, 30)
        XCTAssertEqual(config.batchSize, 64)
        XCTAssertEqual(config.learningRate, 0.001)
        XCTAssertEqual(config.optimizer, .adam)
        XCTAssertEqual(config.lossFunction, .crossEntropy)
        XCTAssertEqual(config.validationSplit, 0.2)
        XCTAssertTrue(config.earlyStopping)
        XCTAssertEqual(config.patience, 5)
        XCTAssertEqual(config.architecture, .mlp)
        XCTAssertTrue(config.saveCheckpoints)
    }
    
    func testTrainingConfigCodable() throws {
        let config = TrainingConfig.default
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(TrainingConfig.self, from: data)
        
        XCTAssertEqual(config.epochs, decoded.epochs)
        XCTAssertEqual(config.batchSize, decoded.batchSize)
        XCTAssertEqual(config.learningRate, decoded.learningRate)
        XCTAssertEqual(config.optimizer, decoded.optimizer)
        XCTAssertEqual(config.architecture, decoded.architecture)
    }
    
    // MARK: - ArchitectureType Tests
    
    func testArchitectureTypeDisplayNames() {
        XCTAssertEqual(ArchitectureType.mlp.displayName, "Multi-Layer Perceptron")
        XCTAssertEqual(ArchitectureType.cnn.displayName, "Convolutional Neural Network")
        XCTAssertEqual(ArchitectureType.resnet.displayName, "ResNet (Residual Network)")
        XCTAssertEqual(ArchitectureType.transformer.displayName, "Transformer")
        XCTAssertEqual(ArchitectureType.yolov8.displayName, "YOLOv8 (Object Detection)")
    }
    
    func testArchitectureTypeRequiresPython() {
        XCTAssertFalse(ArchitectureType.mlp.requiresPython)
        XCTAssertFalse(ArchitectureType.cnn.requiresPython)
        XCTAssertFalse(ArchitectureType.resnet.requiresPython)
        XCTAssertFalse(ArchitectureType.transformer.requiresPython)
        XCTAssertTrue(ArchitectureType.yolov8.requiresPython)
    }
    
    func testArchitectureTypeIsObjectDetection() {
        XCTAssertFalse(ArchitectureType.mlp.isObjectDetection)
        XCTAssertFalse(ArchitectureType.cnn.isObjectDetection)
        XCTAssertFalse(ArchitectureType.resnet.isObjectDetection)
        XCTAssertFalse(ArchitectureType.transformer.isObjectDetection)
        XCTAssertTrue(ArchitectureType.yolov8.isObjectDetection)
    }
    
    func testArchitectureTypeAllCases() {
        XCTAssertEqual(ArchitectureType.allCases.count, 5)
    }
    
    func testArchitectureToModelArchitecture() {
        // Verify conversion doesn't crash
        let _ = ArchitectureType.mlp.toModelArchitecture()
        let _ = ArchitectureType.cnn.toModelArchitecture()
        let _ = ArchitectureType.resnet.toModelArchitecture()
        let _ = ArchitectureType.transformer.toModelArchitecture()
        let _ = ArchitectureType.yolov8.toModelArchitecture()
    }
    
    // MARK: - Optimizer Tests
    
    func testOptimizerAllCases() {
        XCTAssertEqual(Optimizer.allCases.count, 4)
        XCTAssertTrue(Optimizer.allCases.contains(.sgd))
        XCTAssertTrue(Optimizer.allCases.contains(.adam))
        XCTAssertTrue(Optimizer.allCases.contains(.adamw))
        XCTAssertTrue(Optimizer.allCases.contains(.rmsprop))
    }
    
    func testOptimizerRawValues() {
        XCTAssertEqual(Optimizer.sgd.rawValue, "SGD")
        XCTAssertEqual(Optimizer.adam.rawValue, "Adam")
        XCTAssertEqual(Optimizer.adamw.rawValue, "AdamW")
        XCTAssertEqual(Optimizer.rmsprop.rawValue, "RMSprop")
    }
    
    // MARK: - LossFunction Tests
    
    func testLossFunctionAllCases() {
        XCTAssertEqual(LossFunction.allCases.count, 4)
        XCTAssertTrue(LossFunction.allCases.contains(.crossEntropy))
        XCTAssertTrue(LossFunction.allCases.contains(.mse))
        XCTAssertTrue(LossFunction.allCases.contains(.bce))
        XCTAssertTrue(LossFunction.allCases.contains(.huber))
    }
    
    func testLossFunctionRawValues() {
        XCTAssertEqual(LossFunction.crossEntropy.rawValue, "Cross Entropy")
        XCTAssertEqual(LossFunction.mse.rawValue, "Mean Squared Error")
        XCTAssertEqual(LossFunction.bce.rawValue, "Binary Cross Entropy")
        XCTAssertEqual(LossFunction.huber.rawValue, "Huber Loss")
    }
    
    // MARK: - LRScheduler Tests
    
    func testLRSchedulerAllCases() {
        XCTAssertEqual(LRScheduler.allCases.count, 6)
    }
    
    func testLRSchedulerDescriptions() {
        // Verify all schedulers have descriptions
        for scheduler in LRScheduler.allCases {
            XCTAssertFalse(scheduler.description.isEmpty, "Scheduler \(scheduler) should have a description")
        }
    }
    
    func testLRSchedulerIcons() {
        // Verify all schedulers have icons
        for scheduler in LRScheduler.allCases {
            XCTAssertFalse(scheduler.icon.isEmpty, "Scheduler \(scheduler) should have an icon")
        }
    }
    
    // MARK: - DataAugmentationConfig Tests
    
    func testDefaultAugmentationConfig() {
        let config = DataAugmentationConfig.default
        
        XCTAssertFalse(config.enabled)
        XCTAssertTrue(config.horizontalFlip)
        XCTAssertFalse(config.verticalFlip)
        XCTAssertEqual(config.rotation, 15.0)
        XCTAssertEqual(config.zoom, 0.1)
    }
    
    func testMNISTAugmentationConfig() {
        let config = DataAugmentationConfig.mnist
        
        XCTAssertTrue(config.enabled)
        XCTAssertFalse(config.horizontalFlip) // Don't flip digits
        XCTAssertFalse(config.verticalFlip)
        XCTAssertEqual(config.rotation, 15.0)
    }
    
    func testAugmentationConfigEquatable() {
        let config1 = DataAugmentationConfig.default
        let config2 = DataAugmentationConfig.default
        
        XCTAssertEqual(config1, config2)
    }
    
    func testAugmentationConfigCodable() throws {
        let config = DataAugmentationConfig.mnist
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(DataAugmentationConfig.self, from: data)
        
        XCTAssertEqual(config, decoded)
    }
}
