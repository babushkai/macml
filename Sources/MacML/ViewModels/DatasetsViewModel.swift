import SwiftUI

/// ViewModel for managing datasets
/// Extracts dataset-related logic from AppState for better separation of concerns
@MainActor
class DatasetsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var datasets: [Dataset] = []
    @Published var selectedDatasetId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let storage: StorageManager

    // MARK: - Computed Properties

    var selectedDataset: Dataset? {
        selectedDatasetId.flatMap { id in datasets.first { $0.id == id } }
    }

    var activeDatasets: [Dataset] {
        datasets.filter { $0.status.isActive }
    }

    var imageDatasets: [Dataset] {
        datasets.filter { $0.type == .images && $0.status.isActive }
    }

    var textDatasets: [Dataset] {
        datasets.filter { $0.type == .text && $0.status.isActive }
    }

    // MARK: - Initialization

    init(storage: StorageManager = .shared) {
        self.storage = storage
    }

    // MARK: - Data Loading

    func loadDatasets() async {
        isLoading = true
        defer { isLoading = false }

        do {
            datasets = try await storage.loadDatasets()
            Log.debug("Loaded \(datasets.count) datasets", category: .database)
            ensureBuiltInDatasets()
        } catch {
            Log.error("Failed to load datasets", error: error, category: .database)
            errorMessage = "Failed to load datasets: \(error.localizedDescription)"
        }
    }

    private func ensureBuiltInDatasets() {
        for seedDataset in DemoDataProvider.seedDatasets {
            if !datasets.contains(where: { $0.id == seedDataset.id }) {
                datasets.append(seedDataset)
            }
        }
    }

    // MARK: - CRUD Operations

    func addDataset(_ dataset: Dataset) async {
        datasets.insert(dataset, at: 0)
        await saveDatasets()
        Log.info("Dataset created: \(dataset.name)", category: .app)
    }

    func updateDatasetStatus(_ datasetId: String, status: DatasetStatus) async {
        if let index = datasets.firstIndex(where: { $0.id == datasetId }) {
            datasets[index].status = status
            datasets[index].updatedAt = Date()
            await saveDatasets()
        }
    }

    func deleteDataset(_ dataset: Dataset) async {
        do {
            try await storage.deleteDataset(dataset)
            datasets.removeAll { $0.id == dataset.id }
            await saveDatasets()
            Log.info("Dataset deleted: \(dataset.name)", category: .app)
        } catch {
            Log.error("Failed to delete dataset", error: error, category: .app)
            errorMessage = "Failed to delete dataset: \(error.localizedDescription)"
        }
    }

    // MARK: - Import

    func importDataset(from url: URL, name: String, type: DatasetType) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let dataset = try await storage.importDataset(from: url, name: name, type: type)
            datasets.insert(dataset, at: 0)
            await saveDatasets()
            Log.info("Dataset imported: \(name)", category: .app)
        } catch {
            Log.error("Failed to import dataset", error: error, category: .app)
            errorMessage = "Failed to import dataset: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Queries

    func dataset(withId id: String) -> Dataset? {
        datasets.first { $0.id == id }
    }

    func datasets(ofType type: DatasetType) -> [Dataset] {
        datasets.filter { $0.type == type && $0.status.isActive }
    }

    // MARK: - Private

    private func saveDatasets() async {
        do {
            try await storage.saveDatasets(datasets)
        } catch {
            Log.error("Failed to save datasets", error: error, category: .database)
            errorMessage = "Failed to save datasets: \(error.localizedDescription)"
        }
    }
}
