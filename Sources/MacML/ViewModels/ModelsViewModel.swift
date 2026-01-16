import SwiftUI

/// ViewModel for managing ML models
/// Extracts model-related logic from AppState for better separation of concerns
@MainActor
class ModelsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var models: [MLModel] = []
    @Published var selectedModelId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let storage: StorageManager

    // MARK: - Computed Properties

    var selectedModel: MLModel? {
        selectedModelId.flatMap { id in models.first { $0.id == id } }
    }

    var readyModels: [MLModel] {
        models.filter { $0.status == .ready }
    }

    var inferenceReadyModels: [MLModel] {
        models.filter { $0.status == .ready && $0.filePath != nil }
    }

    var draftModels: [MLModel] {
        models.filter { $0.status == .draft }
    }

    var trainingModels: [MLModel] {
        models.filter { $0.status == .training }
    }

    // MARK: - Initialization

    init(storage: StorageManager = .shared) {
        self.storage = storage
    }

    // MARK: - CRUD Operations

    func loadModels() async {
        isLoading = true
        defer { isLoading = false }

        do {
            models = try await storage.loadModels()
            Log.debug("Loaded \(models.count) models", category: .database)
        } catch {
            Log.error("Failed to load models", error: error, category: .database)
            errorMessage = "Failed to load models: \(error.localizedDescription)"
        }
    }

    func addModel(_ model: MLModel) async {
        models.insert(model, at: 0)
        await saveModels()
        Log.info("Model created: \(model.name)", category: .app)
    }

    func createModel(name: String, framework: MLFramework) async {
        let model = MLModel(name: name, framework: framework, status: .draft)
        await addModel(model)
    }

    func createModelFromTemplate(_ template: ModelTemplate) async {
        if let existingModel = models.first(where: { $0.id == template.id }) {
            selectedModelId = existingModel.id
            return
        }

        let model = MLModel(
            id: template.id,
            name: template.name,
            framework: .mlx,
            status: .draft,
            metadata: [
                "description": template.description,
                "architectureType": template.architectureType
            ]
        )

        models.insert(model, at: 0)
        selectedModelId = model.id
        await saveModels()
    }

    func updateModel(_ model: MLModel) async {
        if let index = models.firstIndex(where: { $0.id == model.id }) {
            var updated = model
            updated.updatedAt = Date()
            models[index] = updated
            await saveModels()
        }
    }

    func updateModelStatus(_ modelId: String, status: ModelStatus) async {
        if let index = models.firstIndex(where: { $0.id == modelId }) {
            models[index].status = status
            models[index].updatedAt = Date()
            await saveModels()
        }
    }

    func updateModelAccuracy(_ modelId: String, accuracy: Double) async {
        if let index = models.firstIndex(where: { $0.id == modelId }) {
            models[index].accuracy = accuracy
            models[index].status = .ready
            models[index].updatedAt = Date()
            await saveModels()
        }
    }

    func deleteModel(_ model: MLModel) async {
        do {
            try await storage.deleteModelFile(model)
            models.removeAll { $0.id == model.id }
            await saveModels()
            Log.info("Model deleted: \(model.name)", category: .app)
        } catch {
            Log.error("Failed to delete model", error: error, category: .app)
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
        }
    }

    func deleteModels(_ modelsToDelete: [MLModel]) async {
        for model in modelsToDelete {
            do {
                try await storage.deleteModelFile(model)
            } catch {
                Log.warning("Failed to delete model file: \(error.localizedDescription)", category: .app)
            }
        }

        let idsToDelete = Set(modelsToDelete.map { $0.id })
        models.removeAll { idsToDelete.contains($0.id) }
        await saveModels()
        Log.info("\(modelsToDelete.count) models deleted", category: .app)
    }

    // MARK: - Import/Export

    func importModel(from url: URL, name: String, framework: MLFramework) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let model = try await storage.importModel(from: url, name: name, framework: framework)
            models.insert(model, at: 0)
            await saveModels()
            Log.info("Model imported: \(name)", category: .app)
        } catch {
            Log.error("Failed to import model", error: error, category: .app)
            errorMessage = "Failed to import model: \(error.localizedDescription)"
            throw error
        }
    }

    func exportModel(_ model: MLModel, to url: URL) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await storage.exportModel(model, to: url)
            Log.info("Model exported: \(model.name)", category: .app)
        } catch {
            Log.error("Failed to export model", error: error, category: .app)
            errorMessage = "Failed to export model: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Private

    private func saveModels() async {
        do {
            try await storage.saveModels(models)
        } catch {
            Log.error("Failed to save models", error: error, category: .database)
            errorMessage = "Failed to save models: \(error.localizedDescription)"
        }
    }
}
