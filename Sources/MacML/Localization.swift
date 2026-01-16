import Foundation

// MARK: - Localization Helper

/// Localized string helper using String(localized:) for SwiftUI
enum L {
    // MARK: - Navigation & Tabs
    static var dashboard: String { String(localized: "dashboard", bundle: .module) }
    static var models: String { String(localized: "models", bundle: .module) }
    static var training: String { String(localized: "training", bundle: .module) }
    static var experiments: String { String(localized: "experiments", bundle: .module) }
    static var metrics: String { String(localized: "metrics", bundle: .module) }
    static var datasets: String { String(localized: "datasets", bundle: .module) }
    static var inference: String { String(localized: "inference", bundle: .module) }
    static var settings: String { String(localized: "settings", bundle: .module) }

    // MARK: - Common Actions
    static var newModel: String { String(localized: "new_model", bundle: .module) }
    static var newTrainingRun: String { String(localized: "new_training_run", bundle: .module) }
    static var importDataset: String { String(localized: "import_dataset", bundle: .module) }
    static var importModel: String { String(localized: "import_model", bundle: .module) }
    static var createModel: String { String(localized: "create_model", bundle: .module) }
    static var trainModel: String { String(localized: "train_model", bundle: .module) }
    static var train: String { String(localized: "train", bundle: .module) }
    static var runInference: String { String(localized: "run_inference", bundle: .module) }
    static var export: String { String(localized: "export", bundle: .module) }
    static var delete: String { String(localized: "delete", bundle: .module) }
    static var cancel: String { String(localized: "cancel", bundle: .module) }
    static var ok: String { String(localized: "ok", bundle: .module) }
    static var save: String { String(localized: "save", bundle: .module) }
    static var create: String { String(localized: "create", bundle: .module) }
    static var refresh: String { String(localized: "refresh", bundle: .module) }
    static var clear: String { String(localized: "clear", bundle: .module) }
    static var close: String { String(localized: "close", bundle: .module) }
    static var browse: String { String(localized: "browse", bundle: .module) }

    // MARK: - Training Actions
    static var pause: String { String(localized: "pause", bundle: .module) }
    static var resume: String { String(localized: "resume", bundle: .module) }
    static var stop: String { String(localized: "stop", bundle: .module) }
    static var pauseTraining: String { String(localized: "pause_training", bundle: .module) }
    static var resumeTraining: String { String(localized: "resume_training", bundle: .module) }
    static var stopTraining: String { String(localized: "stop_training", bundle: .module) }
    static var continueTraining: String { String(localized: "continue_training", bundle: .module) }
    static var startTraining: String { String(localized: "start_training", bundle: .module) }

    // MARK: - Menu Items
    static var toggleSidebar: String { String(localized: "toggle_sidebar", bundle: .module) }
    static var refreshData: String { String(localized: "refresh_data", bundle: .module) }
    static var deleteAllFailedRuns: String { String(localized: "delete_all_failed_runs", bundle: .module) }
    static var trainingRuns: String { String(localized: "training_runs", bundle: .module) }

    // MARK: - Status Labels
    static var active: String { String(localized: "status_active", bundle: .module) }
    static var completed: String { String(localized: "status_completed", bundle: .module) }
    static var failed: String { String(localized: "status_failed", bundle: .module) }
    static var cancelled: String { String(localized: "status_cancelled", bundle: .module) }
    static var paused: String { String(localized: "status_paused", bundle: .module) }
    static var running: String { String(localized: "status_running", bundle: .module) }
    static var queued: String { String(localized: "status_queued", bundle: .module) }
    static var draft: String { String(localized: "status_draft", bundle: .module) }
    static var ready: String { String(localized: "status_ready", bundle: .module) }
    static var importing: String { String(localized: "status_importing", bundle: .module) }
    static var deployed: String { String(localized: "status_deployed", bundle: .module) }
    static var archived: String { String(localized: "status_archived", bundle: .module) }
    static var deprecated: String { String(localized: "status_deprecated", bundle: .module) }

    // MARK: - Dashboard
    static var mlopsCommandCenter: String { String(localized: "mlops_command_center", bundle: .module) }
    static var trainDeployMonitor: String { String(localized: "train_deploy_monitor", bundle: .module) }
    static var modelArchitectures: String { String(localized: "model_architectures", bundle: .module) }
    static var trainWithMLX: String { String(localized: "train_with_mlx", bundle: .module) }
    static var availableDatasets: String { String(localized: "available_datasets", bundle: .module) }
    static var builtInDatasets: String { String(localized: "built_in_datasets", bundle: .module) }
    static var quickActions: String { String(localized: "quick_actions", bundle: .module) }
    static var recentActivity: String { String(localized: "recent_activity", bundle: .module) }
    static var trainingAnalytics: String { String(localized: "training_analytics", bundle: .module) }
    static var accuracyTrend: String { String(localized: "accuracy_trend", bundle: .module) }
    static var modelHub: String { String(localized: "model_hub", bundle: .module) }
    static var datasetHub: String { String(localized: "dataset_hub", bundle: .module) }
    static var liveMetrics: String { String(localized: "live_metrics", bundle: .module) }
    static var activeTraining: String { String(localized: "active_training", bundle: .module) }
    static var uptime: String { String(localized: "uptime", bundle: .module) }
    static var throughput: String { String(localized: "throughput", bundle: .module) }
    static var jobsQueue: String { String(localized: "jobs_queue", bundle: .module) }
    static var successRate: String { String(localized: "success_rate", bundle: .module) }
    static var storage: String { String(localized: "storage", bundle: .module) }
    static var avgAccuracy: String { String(localized: "avg_accuracy", bundle: .module) }
    static var bestModel: String { String(localized: "best_model", bundle: .module) }
    static var welcomeToMacML: String { String(localized: "welcome_to_macml", bundle: .module) }
    static var mlopsDescription: String { String(localized: "mlops_description", bundle: .module) }
    static var loadDemoData: String { String(localized: "load_demo_data", bundle: .module) }
    static var completeTrendsMessage: String { String(localized: "complete_trends_message", bundle: .module) }
    static var importOrCreate: String { String(localized: "import_or_create", bundle: .module) }
    static var trainAModel: String { String(localized: "train_a_model", bundle: .module) }
    static var addTrainingData: String { String(localized: "add_training_data", bundle: .module) }
    static var testYourModel: String { String(localized: "test_your_model", bundle: .module) }
    static var trainingCompleted: String { String(localized: "training_completed", bundle: .module) }
    static var noDataAvailable: String { String(localized: "no_data_available", bundle: .module) }

    // MARK: - Models View
    static var allModels: String { String(localized: "all_models", bundle: .module) }
    static var noModelsYet: String { String(localized: "no_models_yet", bundle: .module) }
    static var noMatchingModels: String { String(localized: "no_matching_models", bundle: .module) }
    static var noModels: String { String(localized: "no_models", bundle: .module) }
    static var searchModels: String { String(localized: "search_models", bundle: .module) }
    static var allFrameworks: String { String(localized: "all_frameworks", bundle: .module) }
    static var allStatus: String { String(localized: "all_status", bundle: .module) }
    static var selectMultiple: String { String(localized: "select_multiple", bundle: .module) }
    static var cancelSelection: String { String(localized: "cancel_selection", bundle: .module) }
    static var showArchived: String { String(localized: "show_archived", bundle: .module) }
    static var deleteAllModels: String { String(localized: "delete_all_models", bundle: .module) }
    static var clearFilters: String { String(localized: "clear_filters", bundle: .module) }
    static var adjustFilters: String { String(localized: "adjust_filters", bundle: .module) }
    static var importModelToStart: String { String(localized: "import_model_to_start", bundle: .module) }
    static var total: String { String(localized: "total", bundle: .module) }
    static var copyModelId: String { String(localized: "copy_model_id", bundle: .module) }
    static var archive: String { String(localized: "archive", bundle: .module) }
    static var restore: String { String(localized: "restore", bundle: .module) }
    static var markDeprecated: String { String(localized: "mark_deprecated", bundle: .module) }
    static var undeprecate: String { String(localized: "undeprecate", bundle: .module) }
    static var dropToImport: String { String(localized: "drop_to_import", bundle: .module) }
    static var dragDropModel: String { String(localized: "drag_drop_model", bundle: .module) }
    static var supportedFormats: String { String(localized: "supported_formats", bundle: .module) }
    static var loadingModelInfo: String { String(localized: "loading_model_info", bundle: .module) }
    static var metadata: String { String(localized: "metadata", bundle: .module) }
    static var created: String { String(localized: "created", bundle: .module) }
    static var updated: String { String(localized: "updated", bundle: .module) }
    static var author: String { String(localized: "author", bundle: .module) }
    static var version: String { String(localized: "version", bundle: .module) }
    static var inputs: String { String(localized: "inputs", bundle: .module) }
    static var outputs: String { String(localized: "outputs", bundle: .module) }
    static var description: String { String(localized: "description", bundle: .module) }

    // MARK: - Training Runs View
    static var noTrainingRunsYet: String { String(localized: "no_training_runs_yet", bundle: .module) }
    static var copyRunId: String { String(localized: "copy_run_id", bundle: .module) }
    static var deleteRun: String { String(localized: "delete_run", bundle: .module) }
    static var epoch: String { String(localized: "epoch", bundle: .module) }
    static var loss: String { String(localized: "loss", bundle: .module) }
    static var accuracy: String { String(localized: "accuracy", bundle: .module) }
    static var learningRate: String { String(localized: "learning_rate", bundle: .module) }

    // MARK: - Datasets View
    static var noDatasetsYet: String { String(localized: "no_datasets_yet", bundle: .module) }
    static var searchDatasets: String { String(localized: "search_datasets", bundle: .module) }
    static var allTypes: String { String(localized: "all_types", bundle: .module) }
    static var files: String { String(localized: "files", bundle: .module) }
    static var classes: String { String(localized: "classes", bundle: .module) }
    static var samples: String { String(localized: "samples", bundle: .module) }
    static var size: String { String(localized: "size", bundle: .module) }
    static var duration: String { String(localized: "duration", bundle: .module) }
    static var createDataset: String { String(localized: "create_dataset", bundle: .module) }
    static var copyDatasetId: String { String(localized: "copy_dataset_id", bundle: .module) }
    static var showInFinder: String { String(localized: "show_in_finder", bundle: .module) }

    // MARK: - Inference View
    static var selectModel: String { String(localized: "select_model", bundle: .module) }
    static var selectModelForInference: String { String(localized: "select_model_for_inference", bundle: .module) }
    static var dropImages: String { String(localized: "drop_images", bundle: .module) }
    static var batchMode: String { String(localized: "batch_mode", bundle: .module) }
    static var batchInference: String { String(localized: "batch_inference", bundle: .module) }
    static var inferenceComplete: String { String(localized: "inference_complete", bundle: .module) }
    static var noModelsAvailable: String { String(localized: "no_models_available", bundle: .module) }
    static var exportCSV: String { String(localized: "export_csv", bundle: .module) }
    static var exportJSON: String { String(localized: "export_json", bundle: .module) }

    // MARK: - Settings View
    static var general: String { String(localized: "general", bundle: .module) }
    static var trainingDefaults: String { String(localized: "training_defaults", bundle: .module) }
    static var mlTrainingBackend: String { String(localized: "ml_training_backend", bundle: .module) }
    static var autoSaveCheckpoints: String { String(localized: "auto_save_checkpoints", bundle: .module) }
    static var showNotifications: String { String(localized: "show_notifications", bundle: .module) }
    static var cacheModels: String { String(localized: "cache_models", bundle: .module) }
    static var defaultEpochs: String { String(localized: "default_epochs", bundle: .module) }
    static var defaultBatchSize: String { String(localized: "default_batch_size", bundle: .module) }
    static var defaultLearningRate: String { String(localized: "default_learning_rate", bundle: .module) }
    static var mlxBackend: String { String(localized: "mlx_backend", bundle: .module) }
    static var appleSiliconOptimized: String { String(localized: "apple_silicon_optimized", bundle: .module) }
    static var gpuAcceleration: String { String(localized: "gpu_acceleration", bundle: .module) }
    static var metal: String { String(localized: "metal", bundle: .module) }
    static var automaticDifferentiation: String { String(localized: "automatic_differentiation", bundle: .module) }
    static var enabled: String { String(localized: "enabled", bundle: .module) }
    static var mlxDescription: String { String(localized: "mlx_description", bundle: .module) }
    static var totalSize: String { String(localized: "total_size", bundle: .module) }
    static var cache: String { String(localized: "cache", bundle: .module) }
    static var loadingStorageInfo: String { String(localized: "loading_storage_info", bundle: .module) }
    static var openDataFolder: String { String(localized: "open_data_folder", bundle: .module) }
    static var clearCache: String { String(localized: "clear_cache", bundle: .module) }
    static var cacheEmpty: String { String(localized: "cache_empty", bundle: .module) }
    static var about: String { String(localized: "about", bundle: .module) }
    static var build: String { String(localized: "build", bundle: .module) }
    static var demoSampleData: String { String(localized: "demo_sample_data", bundle: .module) }
    static var loadDemoDataDescription: String { String(localized: "load_demo_data_description", bundle: .module) }
    static var dangerZone: String { String(localized: "danger_zone", bundle: .module) }
    static var resetSettings: String { String(localized: "reset_settings", bundle: .module) }
    static var clearAllData: String { String(localized: "clear_all_data", bundle: .module) }
    static var cannotBeUndone: String { String(localized: "cannot_be_undone", bundle: .module) }
    static var configurePreferences: String { String(localized: "configure_preferences", bundle: .module) }

    // MARK: - Alerts & Confirmations
    static var error: String { String(localized: "error", bundle: .module) }
    static var deleteModel: String { String(localized: "delete_model", bundle: .module) }
    static var deleteModels: String { String(localized: "delete_models", bundle: .module) }
    static var deleteDataset: String { String(localized: "delete_dataset", bundle: .module) }

    // MARK: - Loading Messages
    static var loadingData: String { String(localized: "loading_data", bundle: .module) }
    static var importingModel: String { String(localized: "importing_model", bundle: .module) }
    static var importingDataset: String { String(localized: "importing_dataset", bundle: .module) }
    static var exportingModel: String { String(localized: "exporting_model", bundle: .module) }
    static var runningInference: String { String(localized: "running_inference", bundle: .module) }

    // MARK: - Success Messages
    static var modelCreated: String { String(localized: "model_created", bundle: .module) }
    static var modelDeleted: String { String(localized: "model_deleted", bundle: .module) }
    static var datasetCreated: String { String(localized: "dataset_created", bundle: .module) }
    static var datasetDeleted: String { String(localized: "dataset_deleted", bundle: .module) }
    static var trainingStarted: String { String(localized: "training_started", bundle: .module) }
    static var trainingPaused: String { String(localized: "training_paused", bundle: .module) }
    static var trainingResumed: String { String(localized: "training_resumed", bundle: .module) }
    static var trainingCancelled: String { String(localized: "training_cancelled", bundle: .module) }
    static var runDeleted: String { String(localized: "run_deleted", bundle: .module) }
    static var cacheCleared: String { String(localized: "cache_cleared", bundle: .module) }
    static var allDataCleared: String { String(localized: "all_data_cleared", bundle: .module) }
    static var settingsReset: String { String(localized: "settings_reset", bundle: .module) }
    static var datasetImported: String { String(localized: "dataset_imported", bundle: .module) }

    // MARK: - Validation Messages
    static var learningRateMustBePositive: String { String(localized: "lr_must_be_positive", bundle: .module) }
    static var learningRateTooHigh: String { String(localized: "lr_too_high", bundle: .module) }
    static var learningRateVeryLow: String { String(localized: "lr_very_low", bundle: .module) }
    static var learningRateQuiteHigh: String { String(localized: "lr_quite_high", bundle: .module) }

    // MARK: - Sheets
    static var runName: String { String(localized: "run_name", bundle: .module) }
    static var model: String { String(localized: "model", bundle: .module) }
    static var dataset: String { String(localized: "dataset", bundle: .module) }
    static var optional: String { String(localized: "optional", bundle: .module) }
    static var epochs: String { String(localized: "epochs", bundle: .module) }
    static var batchSize: String { String(localized: "batch_size", bundle: .module) }
    static var validationSplit: String { String(localized: "validation_split", bundle: .module) }
    static var dataAugmentation: String { String(localized: "data_augmentation", bundle: .module) }
    static var dataType: String { String(localized: "data_type", bundle: .module) }
    static var architecture: String { String(localized: "architecture", bundle: .module) }
    static var experiment: String { String(localized: "experiment", bundle: .module) }
    static var datasetName: String { String(localized: "dataset_name", bundle: .module) }
    static var datasetType: String { String(localized: "dataset_type", bundle: .module) }
    static var modelName: String { String(localized: "model_name", bundle: .module) }
    static var modelDescription: String { String(localized: "model_description", bundle: .module) }
    static var framework: String { String(localized: "framework", bundle: .module) }
    static var classLabels: String { String(localized: "class_labels", bundle: .module) }
    static var inputShape: String { String(localized: "input_shape", bundle: .module) }
    static var chooseModelFile: String { String(localized: "choose_model_file", bundle: .module) }
    static var dropFolder: String { String(localized: "drop_folder", bundle: .module) }

    // MARK: - Confirmation Messages
    static func confirmDeleteModel(_ name: String) -> String {
        String(localized: "confirm_delete_model \(name)", bundle: .module)
    }

    static func confirmDeleteModels(_ count: Int) -> String {
        String(localized: "confirm_delete_models \(count)", bundle: .module)
    }

    static func confirmStopTraining() -> String {
        String(localized: "confirm_stop_training", bundle: .module)
    }

    static func confirmClearCache() -> String {
        String(localized: "confirm_clear_cache", bundle: .module)
    }

    static func confirmResetSettings() -> String {
        String(localized: "confirm_reset_settings", bundle: .module)
    }

    static func confirmClearAllData() -> String {
        String(localized: "confirm_clear_all_data", bundle: .module)
    }

    static func nActive(_ count: Int) -> String {
        String(localized: "n_active \(count)", bundle: .module)
    }

    static func nRunning(_ count: Int) -> String {
        String(localized: "n_running \(count)", bundle: .module)
    }

    static func epochProgress(_ current: Int, _ total: Int) -> String {
        String(localized: "epoch_progress \(current) \(total)", bundle: .module)
    }

    static func modelsDeleted(_ count: Int) -> String {
        String(localized: "models_deleted \(count)", bundle: .module)
    }

    static func runsDeleted(_ count: Int) -> String {
        String(localized: "runs_deleted \(count)", bundle: .module)
    }

    static func deleteSelected(_ count: Int) -> String {
        String(localized: "delete_selected \(count)", bundle: .module)
    }

    static func viewAllActiveRuns(_ count: Int) -> String {
        String(localized: "view_all_active_runs \(count)", bundle: .module)
    }
}
