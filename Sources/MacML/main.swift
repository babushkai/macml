import SwiftUI

@main
struct MacMLApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L.newModel) {
                    appState.showNewModelSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button(L.newTrainingRun) {
                    appState.showNewRunSheet = true
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button(L.importDataset) {
                    appState.showImportDatasetSheet = true
                }
                .keyboardShortcut("i", modifiers: .command)
            }

            CommandGroup(after: .sidebar) {
                Button(L.toggleSidebar) {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])

                Divider()

                // Navigation shortcuts
                Button(L.dashboard) {
                    appState.selectedTab = .dashboard
                }
                .keyboardShortcut("1", modifiers: .command)

                Button(L.models) {
                    appState.selectedTab = .models
                }
                .keyboardShortcut("2", modifiers: .command)

                Button(L.trainingRuns) {
                    appState.selectedTab = .runs
                }
                .keyboardShortcut("3", modifiers: .command)

                Button(L.experiments) {
                    appState.selectedTab = .experiments
                }
                .keyboardShortcut("4", modifiers: .command)

                Button(L.datasets) {
                    appState.selectedTab = .datasets
                }
                .keyboardShortcut("5", modifiers: .command)

                Button(L.inference) {
                    appState.selectedTab = .inference
                }
                .keyboardShortcut("6", modifiers: .command)

                Button(L.metrics) {
                    appState.selectedTab = .metrics
                }
                .keyboardShortcut("7", modifiers: .command)

                Button(L.settings) {
                    appState.selectedTab = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Training controls
            CommandMenu(L.training) {
                Button(L.pauseTraining) {
                    if let runId = appState.selectedRunId,
                       appState.selectedRun?.status == .running {
                        appState.pauseTraining(runId: runId)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(appState.selectedRun?.status != .running)

                Button(L.resumeTraining) {
                    if let runId = appState.selectedRunId,
                       appState.selectedRun?.status == .paused {
                        appState.resumeTraining(runId: runId)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(appState.selectedRun?.status != .paused)

                Button(L.stopTraining) {
                    if let runId = appState.selectedRunId {
                        appState.cancelTraining(runId: runId)
                    }
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(appState.selectedRun?.status != .running && appState.selectedRun?.status != .paused)

                Divider()

                Button(L.refreshData) {
                    Task { await appState.loadData() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button(L.deleteAllFailedRuns) {
                    Task { await appState.deleteFailedRuns() }
                }
                .disabled(appState.runs.filter { $0.status == .failed }.isEmpty)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    // MARK: - Constants

    private enum Constants {
        static let maxInferenceHistoryCount = 100
        static let defaultSuccessMessageDuration: Double = 3.0
    }

    // Data
    @Published var models: [MLModel] = []
    @Published var runs: [TrainingRun] = []
    @Published var datasets: [Dataset] = []
    @Published var inferenceHistory: [InferenceResult] = []
    @Published var settings: AppSettings = .default

    // UI State
    @Published var selectedTab: NavigationTab = .dashboard
    @Published var selectedModelId: String?
    @Published var selectedRunId: String?
    @Published var selectedDatasetId: String?

    // Sheet State
    @Published var showNewModelSheet = false
    @Published var showNewRunSheet = false
    @Published var showImportDatasetSheet = false
    @Published var showInferenceSheet = false
    @Published var showNewDistillationSheet = false

    // Distillation State
    @Published var distillationRuns: [DistillationRun] = []
    @Published var activeDistillations: [String: DistillationRun] = [:]
    let distillationService = DistillationService.shared

    // Loading State
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var errorMessage: String?
    @Published var successMessage: String?

    /// Show a success message that auto-dismisses after a delay
    func showSuccess(_ message: String, duration: Double = Constants.defaultSuccessMessageDuration) {
        successMessage = message
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if successMessage == message {
                successMessage = nil
            }
        }
    }

    // Services
    private let storage = StorageManager.shared
    let trainingService = TrainingService.shared
    let mlService = MLService.shared

    // Database flag
    @Published var databaseInitialized = false

    init() {
        Task {
            await initializeDatabase()
            await loadData()
            setupTrainingCallbacks()
            setupDistillationCallbacks()
        }
    }

    // MARK: - Database Initialization

    private func initializeDatabase() async {
        do {
            try await DatabaseManager.shared.setup()
            databaseInitialized = true
            Log.info("Database initialized successfully", category: .database)
        } catch {
            Log.error("Database initialization failed", error: error, category: .database)
            // Continue with JSON storage as fallback
            Log.debug("Falling back to JSON storage", category: .database)
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        loadingMessage = "Loading data..."

        do {
            Log.debug("Loading models...", category: .database)
            models = try await storage.loadModels()
            Log.debug("Loaded \(models.count) models", category: .database)

            Log.debug("Loading runs...", category: .database)
            runs = try await storage.loadRuns()
            Log.debug("Loaded \(runs.count) runs", category: .database)

            Log.debug("Loading datasets...", category: .database)
            datasets = try await storage.loadDatasets()
            Log.debug("Loaded \(datasets.count) datasets", category: .database)

            Log.debug("Loading settings...", category: .database)
            settings = try await storage.loadSettings()
            Log.debug("Settings loaded", category: .database)

            // Try to load inference history from database first, fall back to JSON
            if databaseInitialized {
                Log.debug("Loading inference history from database...", category: .database)
                let repo = InferenceResultRepository()
                inferenceHistory = (try? await repo.findAll(limit: Constants.maxInferenceHistoryCount)) ?? []
                Log.debug("Loaded \(inferenceHistory.count) inference results from database", category: .database)
            }

            // If database has no results, try JSON as fallback
            if inferenceHistory.isEmpty {
                Log.debug("Loading inference history from JSON...", category: .database)
                inferenceHistory = try await storage.loadInferenceHistory()
                Log.debug("Loaded \(inferenceHistory.count) inference results from JSON", category: .database)
            }
        } catch {
            Log.error("Failed to load data", error: error, category: .database)
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }

        // Clean up stale running states from previous session
        await cleanupStaleRuns()

        // Ensure built-in datasets are always available
        ensureBuiltInDatasets()

        isLoading = false
    }

    /// Clean up runs that were "running" or "queued" from a previous session
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
            // Save to JSON storage first
            await saveData()

            // Also sync with database if initialized
            if databaseInitialized {
                let repo = TrainingRunRepository()
                for run in runs where run.status == .cancelled && run.logs.last?.message.contains("application restart") == true {
                    try? await repo.update(run)
                }
            }

            Log.debug("Cleaned up \(staleCount) stale training run(s) from previous session", category: .training)
        }
    }

    /// Add seed datasets and models if they don't exist (first load)
    private func ensureBuiltInDatasets() {
        // Add seed datasets
        for seedDataset in DemoDataProvider.seedDatasets {
            if !datasets.contains(where: { $0.id == seedDataset.id }) {
                datasets.append(seedDataset)
            }
        }

        // Add seed models
        for seedModel in DemoDataProvider.seedModels {
            if !models.contains(where: { $0.id == seedModel.id }) {
                models.append(seedModel)
            }
        }

        // Ensure default MNIST classifier is present for quick start
        let defaultModel = MLModel(
            id: "default-mlx-model",
            name: "MNIST Classifier",
            framework: .mlx,
            status: .draft,
            accuracy: 0,
            fileSize: 0,
            filePath: nil,
            metadata: ["description": "Default model for MNIST digit classification", "architecture": "MLP"]
        )

        if !models.contains(where: { $0.id == "default-mlx-model" }) {
            models.insert(defaultModel, at: 0)
        }
    }

    func saveData() async {
        do {
            try await storage.saveModels(models)
            try await storage.saveRuns(runs)
            try await storage.saveDatasets(datasets)
            try await storage.saveSettings(settings)
            try await storage.saveInferenceHistory(inferenceHistory)
        } catch {
            errorMessage = "Failed to save data: \(error.localizedDescription)"
        }
    }

    // MARK: - Distillation Operations

    private func setupDistillationCallbacks() {
        distillationService.onDistillationUpdated = { [weak self] run in
            Task { @MainActor in
                self?.activeDistillations[run.id] = run
                if let index = self?.distillationRuns.firstIndex(where: { $0.id == run.id }) {
                    self?.distillationRuns[index] = run
                }
            }
        }

        distillationService.onDistillationCompleted = { [weak self] run in
            Task { @MainActor in
                self?.activeDistillations.removeValue(forKey: run.id)
                if let index = self?.distillationRuns.firstIndex(where: { $0.id == run.id }) {
                    self?.distillationRuns[index] = run
                }
            }
        }
    }

    func startDistillation(run: DistillationRun) {
        distillationRuns.append(run)
        Task {
            _ = await distillationService.startDistillation(run: run)
        }
    }

    func cancelDistillation(runId: String) {
        distillationService.cancelDistillation(runId: runId)
    }

    func deleteDistillationRun(runId: String) {
        distillationRuns.removeAll { $0.id == runId }
        activeDistillations.removeValue(forKey: runId)
    }

    // MARK: - Model Operations

    func addModel(_ model: MLModel) async {
        models.insert(model, at: 0)
        await saveData()
        showSuccess("Model created: \(model.name)")
    }

    func createModel(name: String, framework: MLFramework) async {
        let model = MLModel(name: name, framework: framework, status: .draft)
        models.insert(model, at: 0)
        await saveData()
    }

    /// Create a model from a template and select it for training
    func createModelFromTemplate(_ template: ModelTemplate) async {
        // Check if a model with this template ID already exists
        if let existingModel = models.first(where: { $0.id == template.id }) {
            // Select the existing model
            selectedModelId = existingModel.id
            return
        }

        // Create new model from template
        let model = MLModel(
            id: template.id,
            name: template.name,
            framework: .mlx,
            status: .draft,
            accuracy: 0,
            fileSize: 0,
            metadata: [
                "description": template.description,
                "architectureType": template.architectureType
            ]
        )

        models.insert(model, at: 0)
        selectedModelId = model.id
        await saveData()
    }

    func importModel(from url: URL, name: String, framework: MLFramework) async throws {
        isLoading = true
        loadingMessage = "Importing model..."

        do {
            let model = try await storage.importModel(from: url, name: name, framework: framework)
            models.insert(model, at: 0)
            await saveData()
        } catch {
            errorMessage = "Failed to import model: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    func deleteModel(_ model: MLModel) async {
        do {
            try await storage.deleteModelFile(model)
            // Clean up resources for associated runs before removing them
            let associatedRuns = runs.filter { $0.modelId == model.id }
            for run in associatedRuns {
                await cleanupRunResources(runId: run.id)
            }
            models.removeAll { $0.id == model.id }
            // Also delete associated runs
            runs.removeAll { $0.modelId == model.id }
            await saveData()
            showSuccess("Model deleted")
        } catch {
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
        }
    }

    func deleteModels(_ modelsToDelete: [MLModel]) async {
        let idsToDelete = Set(modelsToDelete.map { $0.id })
        // Clean up resources for associated runs before removing them
        let associatedRuns = runs.filter { idsToDelete.contains($0.modelId) }
        for run in associatedRuns {
            await cleanupRunResources(runId: run.id)
        }
        for model in modelsToDelete {
            do {
                try await storage.deleteModelFile(model)
            } catch {
                Log.warning("Failed to delete model file: \(error.localizedDescription)", category: .app)
            }
        }
        models.removeAll { idsToDelete.contains($0.id) }
        runs.removeAll { idsToDelete.contains($0.modelId) }
        await saveData()
        showSuccess("\(modelsToDelete.count) models deleted")
    }

    func exportModel(_ model: MLModel, to url: URL) async throws {
        isLoading = true
        loadingMessage = "Exporting model..."

        do {
            try await storage.exportModel(model, to: url)
        } catch {
            errorMessage = "Failed to export model: \(error.localizedDescription)"
            throw error
        }

        isLoading = false
    }

    func updateModelStatus(_ modelId: String, status: ModelStatus) async {
        if let index = models.firstIndex(where: { $0.id == modelId }) {
            models[index].status = status
            models[index].updatedAt = Date()
            await saveData()
        }
    }

    // MARK: - Training Operations

    private func setupTrainingCallbacks() {
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
                await self?.saveData()

                // Update model accuracy if training completed
                if run.status == .completed, let accuracy = run.accuracy {
                    await self?.updateModelAccuracy(run.modelId, accuracy: accuracy)

                    // Register the trained model for inference
                    await self?.registerTrainedModel(from: run)
                }
            }
        }
    }

    /// Register a trained model from a completed training run
    private func registerTrainedModel(from run: TrainingRun) async {
        // Get the best checkpoint for this run
        do {
            guard let checkpoint = try await CheckpointManager.shared.getLatestCheckpoint(runId: run.id) else {
                Log.debug("No checkpoint found for run \(run.id)", category: .training)
                return
            }

            // Build metadata with class labels and architecture
            var metadata: [String: String] = [:]
            metadata["architectureType"] = checkpoint.architectureType ?? run.architectureType
            metadata["numClasses"] = "\(checkpoint.classLabels?.count ?? 10)"

            // Store class labels as JSON array
            if let classLabels = checkpoint.classLabels {
                if let labelsData = try? JSONEncoder().encode(classLabels),
                   let labelsString = String(data: labelsData, encoding: .utf8) {
                    metadata["classLabels"] = labelsString
                }
            }

            // Create a new model entry for the trained model
            let trainedModel = MLModel(
                id: "trained-\(run.id)",
                name: "\(run.name) (Trained)",
                framework: .mlx,
                status: .ready,
                accuracy: run.accuracy ?? 0,
                fileSize: getFileSize(at: checkpoint.path),
                filePath: checkpoint.path,
                metadata: metadata
            )

            // Add to models list if not already present
            if !models.contains(where: { $0.id == trainedModel.id }) {
                models.insert(trainedModel, at: 0)
                await saveData()
            }
        } catch {
            errorMessage = "Failed to register trained model: \(error.localizedDescription)"
        }
    }

    private func getFileSize(at path: String) -> Int64 {
        let fileManager = FileManager.default
        if let attrs = try? fileManager.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int64 {
            return size
        }
        return 0
    }

    func startTraining(modelId: String, name: String, config: TrainingConfig, datasetId: String?, experimentId: String? = nil) async {
        guard let model = models.first(where: { $0.id == modelId }) else { return }

        var run = TrainingRun(
            name: name,
            modelId: modelId,
            modelName: model.name,
            epochs: config.epochs,
            batchSize: config.batchSize,
            learningRate: config.learningRate,
            architecture: config.architecture.rawValue
        )
        run.experimentId = experimentId

        runs.insert(run, at: 0)

        // Save run to database with experiment ID
        if let expId = experimentId {
            Task {
                let repo = TrainingRunRepository()
                try? await repo.create(run, experimentId: expId)
            }
        }

        let dataset = datasetId.flatMap { id in datasets.first { $0.id == id } }
        let updatedRun = await trainingService.startTraining(run: run, config: config, dataset: dataset)

        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = updatedRun
        }

        // Update model status
        await updateModelStatus(modelId, status: .training)
        await saveData()
        showSuccess("Training started: \(name)")
    }

    func pauseTraining(runId: String) {
        trainingService.pauseTraining(runId: runId)
        showSuccess("Training paused")
    }

    func resumeTraining(runId: String) {
        trainingService.resumeTraining(runId: runId)
        showSuccess("Training resumed")
    }

    func cancelTraining(runId: String) {
        trainingService.cancelTraining(runId: runId)
        showSuccess("Training cancelled")
    }

    func deleteRun(_ run: TrainingRun) async {
        if trainingService.isRunning(run.id) {
            trainingService.cancelTraining(runId: run.id)
        }
        // Clean up checkpoints and artifacts for this run
        await cleanupRunResources(runId: run.id)
        runs.removeAll { $0.id == run.id }
        await saveData()
        showSuccess("Run deleted")
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
        await saveData()
        showSuccess("\(runsToDelete.count) runs deleted")
    }

    func deleteFailedRuns() async {
        let failedRuns = runs.filter { $0.status == .failed }
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
        await saveData()
        showSuccess("All runs deleted")
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

    private func updateModelAccuracy(_ modelId: String, accuracy: Double) async {
        if let index = models.firstIndex(where: { $0.id == modelId }) {
            models[index].accuracy = accuracy
            models[index].status = .ready
            models[index].updatedAt = Date()
            await saveData()
        }
    }

    /// Update a model's metadata (e.g., class labels)
    func updateModel(_ model: MLModel) {
        if let index = models.firstIndex(where: { $0.id == model.id }) {
            models[index] = model
            models[index].updatedAt = Date()
            Task {
                await saveData()
            }
        }
    }

    // MARK: - Dataset Operations

    func addDataset(_ dataset: Dataset) async {
        datasets.insert(dataset, at: 0)
        await saveData()
        showSuccess("Dataset created: \(dataset.name)")
    }

    func updateDatasetStatus(_ datasetId: String, status: DatasetStatus) async {
        if let index = datasets.firstIndex(where: { $0.id == datasetId }) {
            datasets[index].status = status
            datasets[index].updatedAt = Date()
            await saveData()
        }
    }

    func importDataset(from url: URL, name: String, type: DatasetType) async throws {
        isLoading = true
        loadingMessage = "Importing dataset..."

        do {
            let dataset = try await storage.importDataset(from: url, name: name, type: type)
            datasets.insert(dataset, at: 0)
            await saveData()
            isLoading = false
            showSuccess("Dataset imported: \(name)")
        } catch {
            isLoading = false
            errorMessage = "Failed to import dataset: \(error.localizedDescription)"
            throw error
        }
    }

    func deleteDataset(_ dataset: Dataset) async {
        do {
            try await storage.deleteDataset(dataset)
            datasets.removeAll { $0.id == dataset.id }
            await saveData()
            showSuccess("Dataset deleted")
        } catch {
            errorMessage = "Failed to delete dataset: \(error.localizedDescription)"
        }
    }

    // MARK: - Inference Operations

    func runInference(model: MLModel, imageURL: URL) async throws -> InferenceResult {
        isLoading = true
        loadingMessage = "Running inference..."

        do {
            let result: InferenceResult

            // Use appropriate inference backend based on framework
            if model.framework == .mlx {
                result = try await MLXInferenceService.shared.runInference(model: model, imageURL: imageURL)
            } else {
                result = try await mlService.classifyImage(model: model, imageURL: imageURL)
            }

            inferenceHistory.insert(result, at: 0)

            // Keep only last N results in memory
            if inferenceHistory.count > Constants.maxInferenceHistoryCount {
                inferenceHistory = Array(inferenceHistory.prefix(Constants.maxInferenceHistoryCount))
            }

            // Persist to database
            Task {
                let repo = InferenceResultRepository()
                try? await repo.create(result)
                // Prune old results in database too
                try? await repo.pruneToLimit(Constants.maxInferenceHistoryCount)
            }

            await saveData()
            isLoading = false
            if let topPrediction = result.predictions.first {
                showSuccess("Prediction: \(topPrediction.label) (\(String(format: "%.1f%%", topPrediction.confidence * 100)))")
            } else {
                showSuccess("Inference complete")
            }
            return result
        } catch {
            isLoading = false
            errorMessage = "Inference failed: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Storage Operations

    func getStorageStats() async -> StorageStats? {
        try? await storage.getStorageStats()
    }

    func clearCache() async {
        do {
            try await storage.clearCache()
            showSuccess("Cache cleared")
        } catch {
            errorMessage = "Failed to clear cache: \(error.localizedDescription)"
        }
    }

    func openDataFolder() async {
        await storage.openInFinder()
    }

    // MARK: - Demo Data

    func loadDemoData() async {
        isLoading = true
        loadingMessage = "Loading demo data..."

        // Merge with existing data (don't replace)
        let demoModels = DemoDataProvider.sampleModels
        for model in demoModels {
            if !models.contains(where: { $0.id == model.id }) {
                models.append(model)
            }
        }

        let demoRuns = DemoDataProvider.sampleRuns
        for run in demoRuns {
            if !runs.contains(where: { $0.id == run.id }) {
                runs.append(run)
            }
        }

        let demoDatasets = DemoDataProvider.sampleDatasets
        for dataset in demoDatasets {
            if !datasets.contains(where: { $0.id == dataset.id }) {
                datasets.append(dataset)
            }
        }

        let demoInference = DemoDataProvider.sampleInferenceResults
        for result in demoInference {
            if !inferenceHistory.contains(where: { $0.id == result.id }) {
                inferenceHistory.append(result)
            }
        }

        await saveData()
        isLoading = false
    }

    func clearAllData() async {
        models = []
        runs = []
        datasets = []
        inferenceHistory = []
        await saveData()
        showSuccess("All data cleared")
    }

    // MARK: - Computed Properties

    var activeRuns: [TrainingRun] {
        runs.filter { $0.status == .running || $0.status == .queued || $0.status == .paused }
    }

    var completedRuns: [TrainingRun] {
        runs.filter { $0.status == .completed }
    }

    var readyModels: [MLModel] {
        models.filter { $0.status == .ready }
    }

    /// Models that are ready AND have actual model files for inference
    var inferenceReadyModels: [MLModel] {
        models.filter { $0.status == .ready && $0.filePath != nil }
    }

    var selectedModel: MLModel? {
        selectedModelId.flatMap { id in models.first { $0.id == id } }
    }

    var selectedRun: TrainingRun? {
        selectedRunId.flatMap { id in runs.first { $0.id == id } }
    }

    var selectedDataset: Dataset? {
        selectedDatasetId.flatMap { id in datasets.first { $0.id == id } }
    }
}

// MARK: - Navigation

enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard
    case models
    case runs
    case experiments
    case distillation
    case metrics
    case datasets
    case inference
    case settings

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .dashboard: return L.dashboard
        case .models: return L.models
        case .runs: return L.training
        case .experiments: return L.experiments
        case .distillation: return L.distillation
        case .metrics: return L.metrics
        case .datasets: return L.datasets
        case .inference: return L.inference
        case .settings: return L.settings
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .models: return "cpu"
        case .runs: return "play.circle"
        case .experiments: return "flask"
        case .distillation: return "sparkles"
        case .metrics: return "chart.xyaxis.line"
        case .datasets: return "folder"
        case .inference: return "wand.and.stars"
        case .settings: return "gear"
        }
    }
}
