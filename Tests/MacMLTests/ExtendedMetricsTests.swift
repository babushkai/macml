import XCTest
@testable import MacML

final class ExtendedMetricsTests: XCTestCase {

    // MARK: - Basic Metrics Tests

    func testExtendedMetricsInitialization() {
        let metrics = ExtendedMetrics(precision: 0.9, recall: 0.85, f1Score: 0.87)

        XCTAssertEqual(metrics.precision, 0.9)
        XCTAssertEqual(metrics.recall, 0.85)
        XCTAssertEqual(metrics.f1Score, 0.87)
        XCTAssertNil(metrics.perClassMetrics)
    }

    func testExtendedMetricsDefaultValues() {
        let metrics = ExtendedMetrics()

        XCTAssertEqual(metrics.precision, 0)
        XCTAssertEqual(metrics.recall, 0)
        XCTAssertEqual(metrics.f1Score, 0)
    }

    // MARK: - Calculate from Predictions Tests

    func testCalculatePerfectPredictions() {
        // All predictions correct
        let predictions = [0, 1, 2, 0, 1, 2]
        let labels = [0, 1, 2, 0, 1, 2]

        let metrics = ExtendedMetrics.calculate(predictions: predictions, labels: labels, numClasses: 3)

        XCTAssertEqual(metrics.precision, 1.0, accuracy: 0.001)
        XCTAssertEqual(metrics.recall, 1.0, accuracy: 0.001)
        XCTAssertEqual(metrics.f1Score, 1.0, accuracy: 0.001)
    }

    func testCalculateAllWrongPredictions() {
        // All predictions wrong
        let predictions = [1, 2, 0, 1, 2, 0]
        let labels = [0, 0, 1, 2, 1, 2]

        let metrics = ExtendedMetrics.calculate(predictions: predictions, labels: labels, numClasses: 3)

        XCTAssertEqual(metrics.precision, 0.0, accuracy: 0.001)
        XCTAssertEqual(metrics.recall, 0.0, accuracy: 0.001)
        XCTAssertEqual(metrics.f1Score, 0.0, accuracy: 0.001)
    }

    func testCalculatePartiallyCorrectPredictions() {
        // 50% correct for each class
        let predictions = [0, 0, 1, 1]
        let labels = [0, 1, 1, 0]

        let metrics = ExtendedMetrics.calculate(predictions: predictions, labels: labels, numClasses: 2)

        // For class 0: TP=1, FP=1, FN=1 -> precision=0.5, recall=0.5
        // For class 1: TP=1, FP=1, FN=1 -> precision=0.5, recall=0.5
        // Macro average: precision=0.5, recall=0.5
        XCTAssertEqual(metrics.precision, 0.5, accuracy: 0.001)
        XCTAssertEqual(metrics.recall, 0.5, accuracy: 0.001)
    }

    func testCalculateEmptyPredictions() {
        let metrics = ExtendedMetrics.calculate(predictions: [], labels: [], numClasses: 3)

        XCTAssertEqual(metrics.precision, 0)
        XCTAssertEqual(metrics.recall, 0)
        XCTAssertEqual(metrics.f1Score, 0)
    }

    func testCalculateMismatchedLengths() {
        let predictions = [0, 1, 2]
        let labels = [0, 1]

        let metrics = ExtendedMetrics.calculate(predictions: predictions, labels: labels, numClasses: 3)

        // Should return zero metrics for mismatched lengths
        XCTAssertEqual(metrics.precision, 0)
        XCTAssertEqual(metrics.recall, 0)
    }

    // MARK: - Per-Class Metrics Tests

    func testPerClassMetrics() {
        let predictions = [0, 0, 0, 1, 1, 1, 2, 2, 2]
        let labels = [0, 0, 1, 1, 1, 2, 2, 2, 0]

        let metrics = ExtendedMetrics.calculate(predictions: predictions, labels: labels, numClasses: 3)

        XCTAssertNotNil(metrics.perClassMetrics)
        XCTAssertEqual(metrics.perClassMetrics?.count, 3)

        // Verify per-class metrics exist
        if let perClass = metrics.perClassMetrics {
            XCTAssertEqual(perClass[0].classIndex, 0)
            XCTAssertEqual(perClass[1].classIndex, 1)
            XCTAssertEqual(perClass[2].classIndex, 2)
        }
    }

    func testClassMetricsSupport() {
        let predictions = [0, 0, 0, 1, 1]
        let labels = [0, 0, 0, 1, 1]

        let metrics = ExtendedMetrics.calculate(predictions: predictions, labels: labels, numClasses: 2)

        if let perClass = metrics.perClassMetrics {
            // Class 0 has 3 samples
            XCTAssertEqual(perClass[0].support, 3)
            // Class 1 has 2 samples
            XCTAssertEqual(perClass[1].support, 2)
        }
    }

    // MARK: - Binary Classification Tests

    func testBinaryClassificationMetrics() {
        // Binary: positive class = 1
        // TP=2, FP=1, FN=1, TN=2
        let predictions = [0, 0, 1, 1, 1, 0]
        let labels = [0, 1, 1, 1, 0, 0]

        let metrics = ExtendedMetrics.calculate(predictions: predictions, labels: labels, numClasses: 2)

        // For class 0: precision=2/3, recall=2/3
        // For class 1: precision=2/3, recall=2/3
        // Macro: precision=2/3, recall=2/3
        XCTAssertEqual(metrics.precision, 2.0/3.0, accuracy: 0.001)
        XCTAssertEqual(metrics.recall, 2.0/3.0, accuracy: 0.001)
    }

    // MARK: - Edge Cases

    func testSingleSample() {
        let predictions = [0]
        let labels = [0]

        let metrics = ExtendedMetrics.calculate(predictions: predictions, labels: labels, numClasses: 1)

        XCTAssertEqual(metrics.precision, 1.0, accuracy: 0.001)
        XCTAssertEqual(metrics.recall, 1.0, accuracy: 0.001)
    }

    func testClassWithNoSamples() {
        // Only class 0 has samples, class 1 and 2 have none
        let predictions = [0, 0, 0]
        let labels = [0, 0, 0]

        let metrics = ExtendedMetrics.calculate(predictions: predictions, labels: labels, numClasses: 3)

        // Per-class: class 0 has perfect metrics, class 1 and 2 have zero
        // Macro average will be affected
        XCTAssertNotNil(metrics.perClassMetrics)
        if let perClass = metrics.perClassMetrics {
            XCTAssertEqual(perClass[0].precision, 1.0)
            XCTAssertEqual(perClass[1].precision, 0.0)
            XCTAssertEqual(perClass[2].precision, 0.0)
        }
    }

    // MARK: - Equatable Tests

    func testExtendedMetricsEquatable() {
        let metrics1 = ExtendedMetrics(precision: 0.9, recall: 0.85, f1Score: 0.87)
        let metrics2 = ExtendedMetrics(precision: 0.9, recall: 0.85, f1Score: 0.87)
        let metrics3 = ExtendedMetrics(precision: 0.8, recall: 0.85, f1Score: 0.87)

        XCTAssertEqual(metrics1, metrics2)
        XCTAssertNotEqual(metrics1, metrics3)
    }
}
