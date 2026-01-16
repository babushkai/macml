import Foundation
import os.log

/// Structured logging service for MacML
/// Uses OSLog for system-integrated logging with proper log levels
/// Named `Log` to avoid conflict with os.Logger
enum Log {
    // MARK: - Log Categories

    /// Main subsystem identifier for the app
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.macml.app"

    /// Loggers for different categories
    private static let appLogger = os.Logger(subsystem: subsystem, category: "app")
    private static let trainingLogger = os.Logger(subsystem: subsystem, category: "training")
    private static let inferenceLogger = os.Logger(subsystem: subsystem, category: "inference")
    private static let databaseLogger = os.Logger(subsystem: subsystem, category: "database")
    private static let networkLogger = os.Logger(subsystem: subsystem, category: "network")
    private static let mlxLogger = os.Logger(subsystem: subsystem, category: "mlx")
    private static let pythonLogger = os.Logger(subsystem: subsystem, category: "python")

    /// Log categories
    enum Category {
        case app
        case training
        case inference
        case database
        case network
        case mlx
        case python

        fileprivate var logger: os.Logger {
            switch self {
            case .app: return Log.appLogger
            case .training: return Log.trainingLogger
            case .inference: return Log.inferenceLogger
            case .database: return Log.databaseLogger
            case .network: return Log.networkLogger
            case .mlx: return Log.mlxLogger
            case .python: return Log.pythonLogger
            }
        }
    }

    // MARK: - Log Levels

    /// Log a debug message (only in debug builds)
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: Source file (auto-filled)
    ///   - function: Function name (auto-filled)
    ///   - line: Line number (auto-filled)
    static func debug(
        _ message: String,
        category: Category = .app,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        category.logger.debug("[\(filename):\(line)] \(function) - \(message)")
        #endif
    }

    /// Log an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    static func info(_ message: String, category: Category = .app) {
        category.logger.info("\(message)")
    }

    /// Log a notice (more important than info)
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    static func notice(_ message: String, category: Category = .app) {
        category.logger.notice("\(message)")
    }

    /// Log a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    static func warning(_ message: String, category: Category = .app) {
        category.logger.warning("\(message)")
    }

    /// Log an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - error: Optional error object
    ///   - category: The log category
    static func error(
        _ message: String,
        error: Error? = nil,
        category: Category = .app
    ) {
        if let error = error {
            category.logger.error("\(message): \(error.localizedDescription)")
        } else {
            category.logger.error("\(message)")
        }
    }

    /// Log a critical/fault message (for serious issues)
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    static func critical(_ message: String, category: Category = .app) {
        category.logger.critical("\(message)")
    }

    // MARK: - Specialized Logging

    /// Log training progress
    /// - Parameters:
    ///   - runId: Training run ID
    ///   - epoch: Current epoch
    ///   - totalEpochs: Total epochs
    ///   - loss: Current loss
    ///   - accuracy: Current accuracy (optional)
    static func trainingProgress(
        runId: String,
        epoch: Int,
        totalEpochs: Int,
        loss: Double,
        accuracy: Double? = nil
    ) {
        if let accuracy = accuracy {
            trainingLogger.info("[\(runId)] Epoch \(epoch)/\(totalEpochs) - loss: \(String(format: "%.4f", loss)), accuracy: \(String(format: "%.2f%%", accuracy * 100))")
        } else {
            trainingLogger.info("[\(runId)] Epoch \(epoch)/\(totalEpochs) - loss: \(String(format: "%.4f", loss))")
        }
    }

    /// Log inference result
    /// - Parameters:
    ///   - modelId: Model ID
    ///   - prediction: Top prediction label
    ///   - confidence: Confidence score
    ///   - timeMs: Inference time in milliseconds
    static func inferenceResult(
        modelId: String,
        prediction: String,
        confidence: Double,
        timeMs: Double
    ) {
        inferenceLogger.info("[\(modelId)] Prediction: \(prediction) (\(String(format: "%.1f%%", confidence * 100))) in \(String(format: "%.1f", timeMs))ms")
    }

    /// Log database operation
    /// - Parameters:
    ///   - operation: Operation name (e.g., "insert", "update", "delete")
    ///   - table: Table name
    ///   - count: Number of records affected
    static func databaseOperation(
        operation: String,
        table: String,
        count: Int = 1
    ) {
        databaseLogger.debug("\(operation.uppercased()) \(table): \(count) record(s)")
    }

    /// Log MLX operation
    /// - Parameters:
    ///   - operation: Operation name
    ///   - details: Additional details
    static func mlxOperation(_ operation: String, details: String? = nil) {
        if let details = details {
            mlxLogger.info("\(operation): \(details)")
        } else {
            mlxLogger.info("\(operation)")
        }
    }

    /// Log Python operation
    /// - Parameters:
    ///   - operation: Operation name
    ///   - script: Script name (optional)
    static func pythonOperation(_ operation: String, script: String? = nil) {
        if let script = script {
            pythonLogger.info("\(operation): \(script)")
        } else {
            pythonLogger.info("\(operation)")
        }
    }

    // MARK: - Performance Logging

    /// Measure and log execution time of a block
    /// - Parameters:
    ///   - label: Label for the operation
    ///   - category: Log category
    ///   - block: The block to measure
    /// - Returns: The result of the block
    static func measure<T>(
        _ label: String,
        category: Category = .app,
        _ block: () throws -> T
    ) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        category.logger.debug("\(label) completed in \(String(format: "%.2f", elapsed))ms")
        return result
    }

    /// Measure and log execution time of an async block
    /// - Parameters:
    ///   - label: Label for the operation
    ///   - category: Log category
    ///   - block: The async block to measure
    /// - Returns: The result of the block
    static func measureAsync<T>(
        _ label: String,
        category: Category = .app,
        _ block: () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        category.logger.debug("\(label) completed in \(String(format: "%.2f", elapsed))ms")
        return result
    }

    // MARK: - Signposts for Instruments

    private static let signpostLog = OSLog(subsystem: subsystem, category: .pointsOfInterest)

    /// Begin a signpost interval for Instruments profiling
    /// - Parameters:
    ///   - name: Signpost name
    ///   - id: Signpost ID
    static func signpostBegin(_ name: StaticString, id: OSSignpostID = .exclusive) {
        os_signpost(.begin, log: signpostLog, name: name, signpostID: id)
    }

    /// End a signpost interval
    /// - Parameters:
    ///   - name: Signpost name
    ///   - id: Signpost ID
    static func signpostEnd(_ name: StaticString, id: OSSignpostID = .exclusive) {
        os_signpost(.end, log: signpostLog, name: name, signpostID: id)
    }
}

// MARK: - Convenience Extensions

extension Log {
    /// Log app lifecycle events
    static func appDidLaunch() {
        info("MacML launched", category: .app)
        info("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")", category: .app)
    }

    /// Log memory warning
    static func memoryWarning() {
        warning("Received memory warning", category: .app)
    }

    /// Log app state change
    static func appStateChanged(to state: String) {
        debug("App state changed to: \(state)", category: .app)
    }
}
