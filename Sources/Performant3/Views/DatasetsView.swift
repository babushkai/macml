import SwiftUI
import AppKit

struct DatasetsView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedType: DatasetType?
    @State private var selectedStatus: DatasetStatus?
    @State private var showingDeleteConfirmation = false
    @State private var datasetToDelete: Dataset?
    @State private var isDraggingOver = false
    @State private var showCreateWizard = false
    @State private var showArchiveFilter = false

    var filteredDatasets: [Dataset] {
        var datasets = appState.datasets

        // Hide archived/deprecated by default unless filter is on
        if !showArchiveFilter {
            datasets = datasets.filter { $0.status.isActive }
        }

        if !searchText.isEmpty {
            datasets = datasets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        if let type = selectedType {
            datasets = datasets.filter { $0.type == type }
        }

        if let status = selectedStatus {
            datasets = datasets.filter { $0.status == status }
        }

        return datasets
    }

    var archivedCount: Int {
        appState.datasets.filter { !$0.status.isActive }.count
    }

    var activeCount: Int {
        appState.datasets.filter { $0.status.isActive }.count
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                // Check if it's a directory
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    DispatchQueue.main.async {
                        appState.errorMessage = "Please drop a folder containing dataset files"
                    }
                    return
                }

                // Import the dataset
                DispatchQueue.main.async {
                    Task {
                        do {
                            try await appState.importDataset(
                                from: url,
                                name: url.lastPathComponent,
                                type: .images // Default to images, could be improved
                            )
                        } catch {
                            appState.errorMessage = "Failed to import dataset: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.warningGradient)
                                .frame(width: 44, height: 44)
                            Image(systemName: "folder.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Datasets")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)

                            HStack(spacing: 12) {
                                Label("\(activeCount) active", systemImage: "folder")
                                if archivedCount > 0 {
                                    Label("\(archivedCount) archived", systemImage: "archivebox")
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Menu {
                            Toggle(isOn: $showArchiveFilter) {
                                Label("Show Archived (\(archivedCount))", systemImage: "archivebox")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 30)

                        Button(action: { showCreateWizard = true }) {
                            Label("Create Dataset", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { appState.showImportDatasetSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.plus")
                                Text("Import Dataset")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.warningGradient)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Filters
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.textMuted)
                    TextField("Search datasets...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(AppTheme.textPrimary)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(AppTheme.surface)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )

                Picker("Type", selection: $selectedType) {
                    Text("All Types").tag(nil as DatasetType?)
                    ForEach(DatasetType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(type as DatasetType?)
                    }
                }
                .frame(width: 140)

                Picker("Status", selection: $selectedStatus) {
                    Text("All Status").tag(nil as DatasetStatus?)
                    ForEach(DatasetStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status as DatasetStatus?)
                    }
                }
                .frame(width: 120)
            }
            }
            .padding()
            .background(AppTheme.background)

            Divider()

            // Datasets Grid
            if filteredDatasets.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "No Datasets",
                    message: searchText.isEmpty ? "Import a dataset to get started" : "No datasets match your search",
                    actionTitle: searchText.isEmpty ? "Import Dataset" : nil,
                    action: searchText.isEmpty ? { appState.showImportDatasetSheet = true } : nil
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 280, maximum: 400))
                    ], spacing: 16) {
                        ForEach(filteredDatasets) { dataset in
                            DatasetCard(
                                dataset: dataset,
                                onDelete: {
                                    datasetToDelete = dataset
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(AppTheme.background)
        .overlay {
            if isDraggingOver {
                DatasetDropZone()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
            return true
        }
        .alert("Delete Dataset", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let dataset = datasetToDelete {
                    Task { await appState.deleteDataset(dataset) }
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(datasetToDelete?.name ?? "")'? This will remove the dataset files.")
        }
        .sheet(isPresented: $showCreateWizard) {
            DatasetCreationWizard()
                .environmentObject(appState)
        }
    }
}

// MARK: - Dataset Card

struct DatasetCard: View {
    let dataset: Dataset
    let onDelete: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(dataset.type.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: dataset.type.icon)
                        .foregroundColor(dataset.type.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(dataset.name)
                            .font(.headline)
                            .lineLimit(1)
                        StatusBadge(text: dataset.status.rawValue, color: dataset.status.color)
                    }
                    Text(dataset.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    Button(action: { openInFinder() }) {
                        Label("Show in Finder", systemImage: "folder")
                    }

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(dataset.id, forType: .string)
                    } label: {
                        Label("Copy Dataset ID", systemImage: "doc.on.doc")
                    }

                    Divider()

                    // Archive/Restore actions
                    if dataset.status == .archived {
                        Button {
                            Task { await appState.updateDatasetStatus(dataset.id, status: .active) }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                    } else if dataset.status != .deprecated {
                        Button {
                            Task { await appState.updateDatasetStatus(dataset.id, status: .archived) }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }

                    // Deprecate/Undeprecate actions
                    if dataset.status == .deprecated {
                        Button {
                            Task { await appState.updateDatasetStatus(dataset.id, status: .active) }
                        } label: {
                            Label("Undeprecate", systemImage: "arrow.uturn.backward")
                        }
                    } else if dataset.status != .archived {
                        Button {
                            Task { await appState.updateDatasetStatus(dataset.id, status: .deprecated) }
                        } label: {
                            Label("Mark Deprecated", systemImage: "exclamationmark.triangle")
                        }
                    }

                    Divider()

                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.borderless)
            }

            // Description (if available)
            if !dataset.description.isEmpty {
                Text(dataset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Divider()

            // Stats
            HStack(spacing: 16) {
                DatasetStat(icon: "doc.on.doc", value: "\(dataset.sampleCount)", label: "Samples")
                DatasetStat(icon: "internaldrive", value: formatBytes(dataset.size), label: "Size")
                if !dataset.classes.isEmpty {
                    DatasetStat(icon: "tag", value: "\(dataset.classes.count)", label: "Classes")
                }
            }

            // Classes (if available)
            if !dataset.classes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Classes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(dataset.classes.prefix(10), id: \.self) { className in
                                Text(className)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            if dataset.classes.count > 10 {
                                Text("+\(dataset.classes.count - 10) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Footer
            HStack {
                Text("Created \(dataset.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if dataset.updatedAt != dataset.createdAt {
                    Text("Updated \(dataset.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(isHovered ? AppTheme.surfaceHover : AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? AppTheme.primary.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
        .opacity(dataset.status.isActive ? 1.0 : 0.7)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func openInFinder() {
        if let path = dataset.path {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        }
    }
}

// MARK: - Dataset Stat

struct DatasetStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Dataset Drop Zone

struct DatasetDropZone: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.white)

                Text("Drop Folder to Import Dataset")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("Drop a folder containing images organized by class")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.accentColor.opacity(0.9))
            )
        }
    }
}

