import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ModelsView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedFramework: MLFramework?
    @State private var selectedStatus: ModelStatus?
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: MLModel?
    @State private var showingBulkDeleteConfirmation = false
    @State private var isDragging = false
    @State private var selectedModels: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showCreateWizard = false
    @State private var showArchiveFilter = false

    var filteredModels: [MLModel] {
        var models = appState.models

        // Hide archived/deprecated by default unless filter is on
        if !showArchiveFilter {
            models = models.filter { $0.status.isActive }
        }

        if !searchText.isEmpty {
            models = models.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.framework.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let framework = selectedFramework {
            models = models.filter { $0.framework == framework }
        }

        if let status = selectedStatus {
            models = models.filter { $0.status == status }
        }

        return models
    }

    var archivedCount: Int {
        appState.models.filter { !$0.status.isActive }.count
    }

    var readyModelsCount: Int {
        appState.models.filter { $0.status == .ready }.count
    }

    var trainingModelsCount: Int {
        appState.models.filter { $0.status == .training }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primaryGradient)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "cpu.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Models")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)

                                HStack(spacing: 12) {
                                    Label("\(appState.models.count) total", systemImage: "square.stack.3d.up")
                                    if readyModelsCount > 0 {
                                        Label("\(readyModelsCount) ready", systemImage: "checkmark.circle.fill")
                                            .foregroundColor(AppTheme.success)
                                    }
                                    if trainingModelsCount > 0 {
                                        Label("\(trainingModelsCount) training", systemImage: "bolt.fill")
                                            .foregroundColor(AppTheme.warning)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(AppTheme.textMuted)
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        // Bulk actions menu
                        if !appState.models.isEmpty {
                            Menu {
                                if isSelectionMode && !selectedModels.isEmpty {
                                    Button(role: .destructive) {
                                        showingBulkDeleteConfirmation = true
                                    } label: {
                                        Label("Delete Selected (\(selectedModels.count))", systemImage: "trash")
                                    }
                                    Divider()
                                }

                                Button {
                                    isSelectionMode.toggle()
                                    if !isSelectionMode {
                                        selectedModels.removeAll()
                                    }
                                } label: {
                                    Label(isSelectionMode ? "Cancel Selection" : "Select Multiple", systemImage: isSelectionMode ? "xmark" : "checkmark.circle")
                                }

                                Divider()

                                Toggle(isOn: $showArchiveFilter) {
                                    Label("Show Archived (\(archivedCount))", systemImage: "archivebox")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    // Delete all filtered models
                                    for model in filteredModels {
                                        selectedModels.insert(model.id)
                                    }
                                    showingBulkDeleteConfirmation = true
                                } label: {
                                    Label("Delete All Models", systemImage: "trash.fill")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 30)
                        }

                        Button(action: { showCreateWizard = true }) {
                            Label("Create Model", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)

                        Button(action: { appState.showNewModelSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import Model")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.primaryGradient)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Search and filters
                HStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.textMuted)
                        TextField("Search models...", text: $searchText)
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

                    Picker("Framework", selection: $selectedFramework) {
                        Text("All Frameworks").tag(nil as MLFramework?)
                        ForEach(MLFramework.allCases, id: \.self) { framework in
                            Label(framework.rawValue, systemImage: framework.icon).tag(framework as MLFramework?)
                        }
                    }
                    .frame(width: 160)

                    Picker("Status", selection: $selectedStatus) {
                        Text("All Status").tag(nil as ModelStatus?)
                        ForEach(ModelStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status as ModelStatus?)
                        }
                    }
                    .frame(width: 120)
                }
            }
            .padding()
            .background(AppTheme.background)

            // Drop zone when empty or dragging
            if appState.models.isEmpty || isDragging {
                ModelDropZone(isDragging: $isDragging) { urls in
                    for url in urls {
                        Task {
                            let name = url.deletingPathExtension().lastPathComponent
                            try? await appState.importModel(from: url, name: name, framework: .coreML)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, appState.models.isEmpty ? 0 : 12)
            }

            Divider()

            // Models List
            if filteredModels.isEmpty {
                EmptyModelsView(
                    hasModels: !appState.models.isEmpty,
                    searchText: searchText,
                    onImport: { appState.showNewModelSheet = true },
                    onClearSearch: { searchText = ""; selectedFramework = nil; selectedStatus = nil }
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredModels) { model in
                                ModelCard(
                                    model: model,
                                    isSelected: selectedModels.contains(model.id),
                                    isSelectionMode: isSelectionMode,
                                    onToggleSelection: {
                                        if selectedModels.contains(model.id) {
                                            selectedModels.remove(model.id)
                                        } else {
                                            selectedModels.insert(model.id)
                                        }
                                    },
                                    onDelete: {
                                        modelToDelete = model
                                        showingDeleteConfirmation = true
                                    },
                                    onExport: { exportModel(model) }
                                )
                                .id(model.id)
                                .contextMenu {
                                    modelContextMenu(for: model)
                                }
                            }
                        }
                        .padding()
                    }
                    .animation(.easeInOut(duration: 0.2), value: filteredModels.count)
                    .onChange(of: appState.selectedModelId) { _, newId in
                        if let id = newId {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Delete Model", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    Task { await appState.deleteModel(model) }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(modelToDelete?.name ?? "")\"? Associated training runs will also be deleted.")
        }
        .alert("Delete Models", isPresented: $showingBulkDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedModels.removeAll()
            }
            Button("Delete \(selectedModels.count) Models", role: .destructive) {
                Task { await performBulkDelete() }
            }
        } message: {
            Text("Are you sure you want to delete \(selectedModels.count) models? Associated training runs will also be deleted. This cannot be undone.")
        }
        .sheet(isPresented: $showCreateWizard) {
            ModelCreationWizard()
                .environmentObject(appState)
        }
    }

    @ViewBuilder
    private func modelContextMenu(for model: MLModel) -> some View {
        Button { startTrainingWithModel(model) } label: {
            Label("Train", systemImage: "play.fill")
        }

        if model.status == .ready && model.filePath != nil {
            Button { runInferenceWithModel(model) } label: {
                Label("Run Inference", systemImage: "wand.and.stars")
            }
        }

        Divider()

        Button { exportModel(model) } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(model.id, forType: .string)
        } label: {
            Label("Copy Model ID", systemImage: "doc.on.doc")
        }

        Divider()

        // Archive/Restore actions
        if model.status == .archived {
            Button {
                Task { await appState.updateModelStatus(model.id, status: .draft) }
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
        } else if model.status != .deprecated {
            Button {
                Task { await appState.updateModelStatus(model.id, status: .archived) }
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }

        // Deprecate/Undeprecate actions
        if model.status == .deprecated {
            Button {
                Task { await appState.updateModelStatus(model.id, status: .draft) }
            } label: {
                Label("Undeprecate", systemImage: "arrow.uturn.backward")
            }
        } else if model.status != .archived {
            Button {
                Task { await appState.updateModelStatus(model.id, status: .deprecated) }
            } label: {
                Label("Mark Deprecated", systemImage: "exclamationmark.triangle")
            }
        }

        Divider()

        Button(role: .destructive) {
            modelToDelete = model
            showingDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func exportModel(_ model: MLModel) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "mlmodel")!]
        panel.nameFieldStringValue = "\(model.name).mlmodel"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                try? await appState.exportModel(model, to: url)
            }
        }
    }

    private func startTrainingWithModel(_ model: MLModel) {
        appState.selectedModelId = model.id
        appState.showNewRunSheet = true
    }

    private func runInferenceWithModel(_ model: MLModel) {
        appState.selectedModelId = model.id
        appState.selectedTab = .inference
    }

    private func performBulkDelete() async {
        let modelsToDelete = appState.models.filter { selectedModels.contains($0.id) }
        await appState.deleteModels(modelsToDelete)
        selectedModels.removeAll()
        isSelectionMode = false
    }
}

// MARK: - Empty Models View

struct EmptyModelsView: View {
    let hasModels: Bool
    let searchText: String
    let onImport: () -> Void
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: hasModels ? "magnifyingglass" : "cpu")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 8) {
                Text(hasModels ? "No Matching Models" : "No Models")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(hasModels ? "Try adjusting your search or filters" : "Import a model or create one to start training")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if hasModels {
                Button(action: onClearSearch) {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: onImport) {
                    Label("Import Model", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Model Card

struct ModelCard: View {
    let model: MLModel
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var onToggleSelection: (() -> Void)?
    let onDelete: () -> Void
    let onExport: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = false
    @State private var modelInfo: ModelInfo?
    @State private var isLoadingInfo = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack(spacing: 16) {
                // Selection checkbox
                if isSelectionMode {
                    Button(action: { onToggleSelection?() }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Framework Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(model.framework.color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: model.framework.icon)
                        .font(.title2)
                        .foregroundColor(model.framework.color)
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.headline)
                            .lineLimit(1)
                        StatusBadge(text: model.status.rawValue, color: model.status.color)
                    }

                    HStack(spacing: 16) {
                        Label(model.framework.rawValue, systemImage: "cpu")
                        if model.accuracy > 0 {
                            Label(String(format: "%.1f%%", model.accuracy * 100), systemImage: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.green)
                        }
                        if model.fileSize > 0 {
                            Label(formatBytes(model.fileSize), systemImage: "doc")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Quick action buttons
                HStack(spacing: 8) {
                    if model.status == .ready {
                        Button(action: { startTrainingWithModel() }) {
                            Image(systemName: "play.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Start training")

                        if model.filePath != nil {
                            Button(action: { runInferenceWithModel() }) {
                                Image(systemName: "wand.and.stars")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Run inference")
                        }
                    } else if model.status == .training {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 20, height: 20)
                    }

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Menu {
                        Button(action: { startTrainingWithModel() }) {
                            Label("Train", systemImage: "play.fill")
                        }
                        if model.filePath != nil {
                            Button(action: { runInferenceWithModel() }) {
                                Label("Run Inference", systemImage: "wand.and.stars")
                            }
                        }
                        Divider()
                        Button(action: onExport) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()

            // Expanded Details
            if isExpanded {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    if isLoadingInfo {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading model info...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let info = modelInfo {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            DetailItem(label: "Author", value: info.author)
                            DetailItem(label: "Version", value: info.version)
                            DetailItem(label: "Inputs", value: info.inputs.joined(separator: ", "))
                            DetailItem(label: "Outputs", value: info.outputs.joined(separator: ", "))
                        }

                        if !info.description.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(info.description)
                                    .font(.caption)
                            }
                        }
                    }

                    // Metadata
                    if !model.metadata.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Metadata")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            ForEach(Array(model.metadata.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(model.metadata[key] ?? "")
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Label("Created \(model.createdAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar")
                        Spacer()
                        Label("Updated \(model.updatedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: isHovered ? .black.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded && modelInfo == nil {
                loadModelInfo()
            }
        }
    }

    private func loadModelInfo() {
        isLoadingInfo = true
        Task {
            do {
                modelInfo = try await appState.mlService.getModelInfo(model)
            } catch {
                // Model info not available
            }
            isLoadingInfo = false
        }
    }

    private func startTrainingWithModel() {
        appState.selectedModelId = model.id
        appState.showNewRunSheet = true
    }

    private func runInferenceWithModel() {
        appState.selectedModelId = model.id
        appState.selectedTab = .inference
    }
}

// MARK: - Detail Item

struct DetailItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Detail Row (for backwards compatibility)

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }
}

// MARK: - Model Drop Zone

struct ModelDropZone: View {
    @Binding var isDragging: Bool
    let onDrop: ([URL]) -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isDragging ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: isDragging ? "arrow.down.doc.fill" : "arrow.down.doc")
                    .font(.system(size: 36))
                    .foregroundColor(isDragging ? .accentColor : .secondary)
            }
            .animation(.easeInOut(duration: 0.2), value: isDragging)

            VStack(spacing: 4) {
                Text(isDragging ? "Drop to Import" : "Drag & Drop Model Here")
                    .font(.headline)
                    .foregroundColor(isDragging ? .accentColor : .primary)

                Text("Supports .mlmodel, .mlmodelc, .mlpackage, .safetensors files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.clear)
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            Task {
                var urls: [URL] = []
                for provider in providers {
                    if let item = try? await provider.loadItem(forTypeIdentifier: "public.file-url"),
                       let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        let ext = url.pathExtension.lowercased()
                        if ["mlmodel", "mlmodelc", "mlpackage", "safetensors", "pt", "pth"].contains(ext) {
                            urls.append(url)
                        }
                    }
                }
                if !urls.isEmpty {
                    onDrop(urls)
                }
            }
            return true
        }
    }
}

// MARK: - Model Row (for backwards compatibility)

struct ModelRow: View {
    let model: MLModel
    let onDelete: () -> Void
    let onExport: () -> Void

    var body: some View {
        ModelCard(
            model: model,
            onDelete: onDelete,
            onExport: onExport
        )
    }
}
