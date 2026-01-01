import SwiftUI

@main
struct Performant3App: App {
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
                Button("New Model") {
                    appState.showNewModelSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Training Run") {
                    appState.showNewRunSheet = true
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Import Dataset") {
                    appState.showImportDatasetSheet = true
                }
                .keyboardShortcut("i", modifiers: .command)
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])

                Divider()

                // Navigation shortcuts
                Button("Dashboard") {
                    appState.selectedTab = .dashboard
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Models") {
                    appState.selectedTab = .models
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Training Runs") {
                    appState.selectedTab = .runs
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Experiments") {
                    appState.selectedTab = .experiments
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Datasets") {
                    appState.selectedTab = .datasets
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Inference") {
                    appState.selectedTab = .inference
                }
                .keyboardShortcut("6", modifiers: .command)

                Button("Metrics") {
                    appState.selectedTab = .metrics
                }
                .keyboardShortcut("7", modifiers: .command)

                Button("Settings") {
                    appState.selectedTab = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Training controls
            CommandMenu("Training") {
                Button("Pause Training") {
                    if let runId = appState.selectedRunId,
                       appState.selectedRun?.status == .running {
                        appState.pauseTraining(runId: runId)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(appState.selectedRun?.status != .running)

                Button("Resume Training") {
                    if let runId = appState.selectedRunId,
                       appState.selectedRun?.status == .paused {
                        appState.resumeTraining(runId: runId)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(appState.selectedRun?.status != .paused)

                Button("Stop Training") {
                    if let runId = appState.selectedRunId {
                        appState.cancelTraining(runId: runId)
                    }
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(appState.selectedRun?.status != .running && appState.selectedRun?.status != .paused)

                Divider()

                Button("Refresh Data") {
                    Task { await appState.loadData() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Delete All Failed Runs") {
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
        }
    }

    // MARK: - Database Initialization

    private func initializeDatabase() async {
        do {
            try await DatabaseManager.shared.setup()
            databaseInitialized = true
        } catch {
            print("[Performant3] Database initialization failed: \(error.localizedDescription)")
            // Continue with JSON storage as fallback
            #if DEBUG
            print("[Performant3] Debug: Full error details - \(error)")
            #endif
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        loadingMessage = "Loading data..."

        do {
            print("[DEBUG] Loading models...")
            models = try await storage.loadModels()
            print("[DEBUG] Loaded \(models.count) models")

            print("[DEBUG] Loading runs...")
            runs = try await storage.loadRuns()
            print("[DEBUG] Loaded \(runs.count) runs")

            print("[DEBUG] Loading datasets...")
            datasets = try await storage.loadDatasets()
            print("[DEBUG] Loaded \(datasets.count) datasets")

            print("[DEBUG] Loading settings...")
            settings = try await storage.loadSettings()
            print("[DEBUG] Settings loaded")

            // Try to load inference history from database first, fall back to JSON
            if databaseInitialized {
                print("[DEBUG] Loading inference history from database...")
                let repo = InferenceResultRepository()
                inferenceHistory = (try? await repo.findAll(limit: Constants.maxInferenceHistoryCount)) ?? []
                print("[DEBUG] Loaded \(inferenceHistory.count) inference results from database")
            }

            // If database has no results, try JSON as fallback
            if inferenceHistory.isEmpty {
                print("[DEBUG] Loading inference history from JSON...")
                inferenceHistory = try await storage.loadInferenceHistory()
                print("[DEBUG] Loaded \(inferenceHistory.count) inference results from JSON")
            }
        } catch {
            print("[DEBUG] Load error: \(error)")
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

            #if DEBUG
            print("[Performant3] Cleaned up \(staleCount) stale training run(s) from previous session")
            #endif
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
        for model in modelsToDelete {
            do {
                try await storage.deleteModelFile(model)
            } catch {
                print("Failed to delete model file: \(error)")
            }
        }
        let idsToDelete = Set(modelsToDelete.map { $0.id })
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
                print("No checkpoint found for run \(run.id)")
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
        runs.removeAll { $0.id == run.id }
        await saveData()
        showSuccess("Run deleted")
    }

    func deleteRuns(_ runsToDelete: [TrainingRun]) async {
        for run in runsToDelete {
            if trainingService.isRunning(run.id) {
                trainingService.cancelTraining(runId: run.id)
            }
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
        }
        runs.removeAll()
        await saveData()
        showSuccess("All runs deleted")
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
    case dashboard = "Dashboard"
    case models = "Models"
    case runs = "Training"
    case experiments = "Experiments"
    case metrics = "Metrics"
    case datasets = "Datasets"
    case inference = "Inference"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .models: return "cpu"
        case .runs: return "play.circle"
        case .experiments: return "flask"
        case .metrics: return "chart.xyaxis.line"
        case .datasets: return "folder"
        case .inference: return "wand.and.stars"
        case .settings: return "gear"
        }
    }
}
