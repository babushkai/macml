import Foundation
import GRDB
import os.log

// MARK: - Database Logger

private let logger = Logger(subsystem: "com.macml.database", category: "DatabaseManager")

// MARK: - Database Manager

/// Manages SQLite database connection and migrations
actor DatabaseManager {
    static let shared = DatabaseManager()

    private var dbPool: DatabasePool?
    private let fileManager = FileManager.default

    private var databaseURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MacML", isDirectory: true)
        do {
            try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create database directory: \(error.localizedDescription)")
        }
        return appDir.appendingPathComponent("macml.sqlite")
    }

    // MARK: - Setup

    func setup() async throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.prepareDatabase { db in
            // Enable WAL mode for better concurrent access
            do {
                try db.execute(sql: "PRAGMA journal_mode = WAL")
            } catch {
                logger.warning("Failed to set WAL journal mode: \(error.localizedDescription). Using default mode.")
            }
            do {
                try db.execute(sql: "PRAGMA synchronous = NORMAL")
            } catch {
                logger.warning("Failed to set synchronous mode: \(error.localizedDescription). Using default mode.")
            }
        }

        dbPool = try DatabasePool(path: databaseURL.path, configuration: config)

        // Run migrations
        try await migrate()
    }

    // MARK: - Migrations

    private func migrate() async throws {
        guard let pool = dbPool else {
            throw DatabaseError.notInitialized
        }

        var migrator = DatabaseMigrator()

        // Migration 1: Initial schema
        migrator.registerMigration("v1_initial") { db in
            // Projects table
            try db.create(table: "projects") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("created_at", .double).notNull()
                t.column("updated_at", .double).notNull()
            }

            // Experiments table
            try db.create(table: "experiments") { t in
                t.column("id", .text).primaryKey()
                t.column("project_id", .text).notNull()
                    .references("projects", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("created_at", .double).notNull()
                t.column("updated_at", .double).notNull()
            }
            try db.create(index: "idx_experiments_project", on: "experiments", columns: ["project_id"])

            // Models table
            try db.create(table: "models") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("framework", .text).notNull()
                t.column("status", .text).notNull()
                t.column("accuracy", .double)
                t.column("file_size", .integer)
                t.column("file_path", .text)
                t.column("created_at", .double).notNull()
                t.column("updated_at", .double).notNull()
                t.column("metadata", .text)  // JSON
            }

            // Training runs table
            try db.create(table: "training_runs") { t in
                t.column("id", .text).primaryKey()
                t.column("experiment_id", .text)
                    .references("experiments", onDelete: .setNull)
                t.column("model_id", .text).notNull()
                    .references("models", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("status", .text).notNull()
                t.column("progress", .double).defaults(to: 0)
                t.column("current_epoch", .integer).defaults(to: 0)
                t.column("total_epochs", .integer).notNull()
                t.column("batch_size", .integer).notNull()
                t.column("learning_rate", .double).notNull()
                t.column("loss", .double)
                t.column("accuracy", .double)
                t.column("started_at", .double).notNull()
                t.column("finished_at", .double)
                t.column("error_message", .text)
                t.column("config", .text).notNull()  // JSON
            }
            try db.create(index: "idx_runs_model", on: "training_runs", columns: ["model_id"])
            try db.create(index: "idx_runs_experiment", on: "training_runs", columns: ["experiment_id"])

            // Metrics time-series table
            try db.create(table: "metrics") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("run_id", .text).notNull()
                    .references("training_runs", onDelete: .cascade)
                t.column("epoch", .integer).notNull()
                t.column("step", .integer)
                t.column("metric_name", .text).notNull()
                t.column("metric_value", .double).notNull()
                t.column("timestamp", .double).notNull()
                t.uniqueKey(["run_id", "epoch", "step", "metric_name"])
            }
            try db.create(index: "idx_metrics_run", on: "metrics", columns: ["run_id", "epoch"])

            // Run logs table
            try db.create(table: "run_logs") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("run_id", .text).notNull()
                    .references("training_runs", onDelete: .cascade)
                t.column("timestamp", .double).notNull()
                t.column("level", .text).notNull()
                t.column("message", .text).notNull()
            }
            try db.create(index: "idx_logs_run", on: "run_logs", columns: ["run_id", "timestamp"])

            // Datasets table
            try db.create(table: "datasets") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("type", .text).notNull()
                t.column("path", .text)
                t.column("sample_count", .integer)
                t.column("size", .integer)
                t.column("classes", .text)  // JSON array
                t.column("created_at", .double).notNull()
                t.column("metadata", .text)  // JSON
            }

            // Artifacts table (content-addressed)
            try db.create(table: "artifacts") { t in
                t.column("sha256", .text).primaryKey()
                t.column("run_id", .text)
                    .references("training_runs", onDelete: .setNull)
                t.column("type", .text).notNull()
                t.column("name", .text).notNull()
                t.column("size", .integer).notNull()
                t.column("created_at", .double).notNull()
                t.column("local_path", .text)
            }
            try db.create(index: "idx_artifacts_run", on: "artifacts", columns: ["run_id"])

            // Inference results table
            try db.create(table: "inference_results") { t in
                t.column("id", .text).primaryKey()
                t.column("model_id", .text).notNull()
                    .references("models", onDelete: .cascade)
                t.column("predictions", .text).notNull()  // JSON
                t.column("inference_time_ms", .double).notNull()
                t.column("timestamp", .double).notNull()
            }

            // Settings table (key-value)
            try db.create(table: "settings") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
                t.column("updated_at", .double).notNull()
            }
        }

        // Migration 2: Add architecture_type column to training_runs
        migrator.registerMigration("v2_architecture_type") { db in
            try db.alter(table: "training_runs") { t in
                t.add(column: "architecture_type", .text).defaults(to: "cnn")
            }
        }

        // Migration 3: Add precision, recall, f1_score columns to training_runs
        migrator.registerMigration("v3_extended_metrics") { db in
            try db.alter(table: "training_runs") { t in
                t.add(column: "precision", .double)
                t.add(column: "recall", .double)
                t.add(column: "f1_score", .double)
            }
        }

        try migrator.migrate(pool)
    }

    // MARK: - Database Access

    func read<T>(_ block: (Database) throws -> T) async throws -> T {
        guard let pool = dbPool else {
            throw DatabaseError.notInitialized
        }
        return try pool.read(block)
    }

    func write<T>(_ block: (Database) throws -> T) async throws -> T {
        guard let pool = dbPool else {
            throw DatabaseError.notInitialized
        }
        return try pool.write(block)
    }

    // MARK: - Observation

    func observe<T: FetchableRecord>(
        request: QueryInterfaceRequest<T>,
        onChange: @escaping ([T]) -> Void
    ) throws -> DatabaseCancellable {
        guard let pool = dbPool else {
            throw DatabaseError.notInitialized
        }

        let observation = ValueObservation.tracking { db in
            try request.fetchAll(db)
        }

        return observation.start(in: pool, onError: { _ in }, onChange: onChange)
    }

    // MARK: - Utilities

    func getDatabasePath() -> String {
        databaseURL.path
    }

    func getDatabaseSize() async throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: databaseURL.path)
        return attributes[.size] as? Int64 ?? 0
    }

    func vacuum() async throws {
        try await write { db in
            try db.execute(sql: "VACUUM")
        }
    }
}

// MARK: - Database Errors

enum DatabaseError: Error, LocalizedError {
    case notInitialized
    case migrationFailed(String)
    case recordNotFound(String)
    case duplicateRecord(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .recordNotFound(let type):
            return "\(type) not found"
        case .duplicateRecord(let type):
            return "Duplicate \(type) record"
        }
    }
}
