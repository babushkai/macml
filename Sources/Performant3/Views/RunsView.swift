import SwiftUI
import Charts

struct RunsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: RunFilter = .all
    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var runToDelete: TrainingRun?
    @State private var showingBulkDeleteConfirmation = false
    @State private var bulkDeleteType: BulkDeleteType = .failed
    @State private var selectedRuns: Set<String> = []
    @State private var isSelectionMode = false

    enum RunFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
        case failed = "Failed"

        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .active: return "play.circle.fill"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
    }

    enum BulkDeleteType {
        case failed, selected, all
    }

    var filteredRuns: [TrainingRun] {
        var runs: [TrainingRun]
        switch selectedFilter {
        case .all: runs = appState.runs
        case .active: runs = appState.runs.filter { $0.status == .running || $0.status == .paused || $0.status == .queued }
        case .completed: runs = appState.runs.filter { $0.status == .completed }
        case .failed: runs = appState.runs.filter { $0.status == .failed || $0.status == .cancelled }
        }

        if !searchText.isEmpty {
            runs = runs.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.modelName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return runs
    }

    var failedRunsCount: Int {
        appState.runs.filter { $0.status == .failed || $0.status == .cancelled }.count
    }

    var activeRunsCount: Int {
        appState.runs.filter { $0.status == .running || $0.status == .paused || $0.status == .queued }.count
    }

    var body: some View {
        HSplitView {
            // Runs List
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.successGradient)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Training Runs")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(AppTheme.textPrimary)

                                HStack(spacing: 12) {
                                    Label("\(appState.runs.count) total", systemImage: "number")
                                    if activeRunsCount > 0 {
                                        Label("\(activeRunsCount) active", systemImage: "bolt.fill")
                                            .foregroundColor(AppTheme.warning)
                                    }
                                    if failedRunsCount > 0 {
                                        Label("\(failedRunsCount) failed", systemImage: "exclamationmark.triangle.fill")
                                            .foregroundColor(AppTheme.error)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(AppTheme.textMuted)
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            // Bulk actions menu
                            if !appState.runs.isEmpty {
                                Menu {
                                    if isSelectionMode && !selectedRuns.isEmpty {
                                        Button(role: .destructive) {
                                            bulkDeleteType = .selected
                                            showingBulkDeleteConfirmation = true
                                        } label: {
                                            Label("Delete Selected (\(selectedRuns.count))", systemImage: "trash")
                                        }
                                        Divider()
                                    }

                                    Button {
                                        isSelectionMode.toggle()
                                        if !isSelectionMode {
                                            selectedRuns.removeAll()
                                        }
                                    } label: {
                                        Label(isSelectionMode ? "Cancel Selection" : "Select Multiple", systemImage: isSelectionMode ? "xmark" : "checkmark.circle")
                                    }

                                    if failedRunsCount > 0 {
                                        Button(role: .destructive) {
                                            bulkDeleteType = .failed
                                            showingBulkDeleteConfirmation = true
                                        } label: {
                                            Label("Delete All Failed (\(failedRunsCount))", systemImage: "trash")
                                        }
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        bulkDeleteType = .all
                                        showingBulkDeleteConfirmation = true
                                    } label: {
                                        Label("Delete All Runs", systemImage: "trash.fill")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title2)
                                }
                                .menuStyle(.borderlessButton)
                                .frame(width: 30)
                            }

                            Button(action: { appState.showNewRunSheet = true }) {
                                Label("New Run", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(appState.models.isEmpty)
                        }
                    }

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search runs...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()

                // Filter Tabs
                HStack(spacing: 4) {
                    ForEach(RunFilter.allCases, id: \.self) { filter in
                        FilterButton(
                            title: filter.rawValue,
                            icon: filter.icon,
                            isSelected: selectedFilter == filter,
                            count: countForFilter(filter)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filter
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 12)

                Divider()

                // Runs List with virtualized scrolling
                if filteredRuns.isEmpty {
                    EmptyRunsView(
                        filter: selectedFilter,
                        hasModels: !appState.models.isEmpty,
                        onCreateRun: { appState.showNewRunSheet = true }
                    )
                } else {
                    ScrollViewReader { proxy in
                        List(selection: isSelectionMode ? nil : $appState.selectedRunId) {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredRuns) { run in
                                    RunListItem(
                                        run: run,
                                        isSelected: selectedRuns.contains(run.id),
                                        isSelectionMode: isSelectionMode,
                                        onToggleSelection: {
                                            if selectedRuns.contains(run.id) {
                                                selectedRuns.remove(run.id)
                                            } else {
                                                selectedRuns.insert(run.id)
                                            }
                                        }
                                    )
                                    .id(run.id)
                                    .tag(run.id)
                                    .contextMenu {
                                        runContextMenu(for: run)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            runToDelete = run
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        if run.status == .running {
                                            Button {
                                                appState.pauseTraining(runId: run.id)
                                            } label: {
                                                Label("Pause", systemImage: "pause.fill")
                                            }
                                            .tint(.orange)
                                        } else if run.status == .paused {
                                            Button {
                                                appState.resumeTraining(runId: run.id)
                                            } label: {
                                                Label("Resume", systemImage: "play.fill")
                                            }
                                            .tint(.green)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.inset)
                        .animation(.easeInOut(duration: 0.2), value: filteredRuns.count)
                        .onChange(of: appState.selectedRunId) { _, newId in
                            if let id = newId {
                                withAnimation {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 400)

            // Run Detail
            if let run = appState.selectedRun {
                RunDetailView(run: run)
            } else {
                PlaceholderDetailView(
                    icon: "play.circle",
                    title: "Select a Training Run",
                    subtitle: "Choose a run from the list to view details, metrics, and logs"
                )
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Delete Run", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let run = runToDelete {
                    Task { await appState.deleteRun(run) }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(runToDelete?.name ?? "this run")\"? This cannot be undone.")
        }
        .alert(bulkDeleteAlertTitle, isPresented: $showingBulkDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await performBulkDelete() }
            }
        } message: {
            Text(bulkDeleteAlertMessage)
        }
    }

    private func countForFilter(_ filter: RunFilter) -> Int? {
        switch filter {
        case .all: return nil
        case .active: return activeRunsCount > 0 ? activeRunsCount : nil
        case .completed: return appState.completedRuns.count > 0 ? appState.completedRuns.count : nil
        case .failed: return failedRunsCount > 0 ? failedRunsCount : nil
        }
    }

    @ViewBuilder
    private func runContextMenu(for run: TrainingRun) -> some View {
        if run.status == .running {
            Button { appState.pauseTraining(runId: run.id) } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            Button(role: .destructive) { appState.cancelTraining(runId: run.id) } label: {
                Label("Cancel", systemImage: "stop.fill")
            }
        } else if run.status == .paused {
            Button { appState.resumeTraining(runId: run.id) } label: {
                Label("Resume", systemImage: "play.fill")
            }
            Button(role: .destructive) { appState.cancelTraining(runId: run.id) } label: {
                Label("Cancel", systemImage: "stop.fill")
            }
        }

        Divider()

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(run.id, forType: .string)
        } label: {
            Label("Copy Run ID", systemImage: "doc.on.doc")
        }

        Divider()

        Button(role: .destructive) {
            runToDelete = run
            showingDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var bulkDeleteAlertTitle: String {
        switch bulkDeleteType {
        case .failed: return "Delete Failed Runs"
        case .selected: return "Delete Selected Runs"
        case .all: return "Delete All Runs"
        }
    }

    private var bulkDeleteAlertMessage: String {
        switch bulkDeleteType {
        case .failed: return "Delete all \(failedRunsCount) failed runs? This cannot be undone."
        case .selected: return "Delete \(selectedRuns.count) selected runs? This cannot be undone."
        case .all: return "Delete all \(appState.runs.count) runs? This cannot be undone."
        }
    }

    private func performBulkDelete() async {
        switch bulkDeleteType {
        case .failed:
            await appState.deleteFailedRuns()
        case .selected:
            let runsToDelete = appState.runs.filter { selectedRuns.contains($0.id) }
            await appState.deleteRuns(runsToDelete)
            selectedRuns.removeAll()
            isSelectionMode = false
        case .all:
            await appState.deleteAllRuns()
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                if let count = count {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty Runs View

struct EmptyRunsView: View {
    let filter: RunsView.RunFilter
    let hasModels: Bool
    let onCreateRun: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: iconForFilter)
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 8) {
                Text(titleForFilter)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(subtitleForFilter)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if filter == .all && hasModels {
                Button(action: onCreateRun) {
                    Label("Start Training", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if filter == .all && !hasModels {
                Text("Create a model first to start training")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var iconForFilter: String {
        switch filter {
        case .all: return "play.circle"
        case .active: return "bolt.slash"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }

    private var titleForFilter: String {
        switch filter {
        case .all: return "No Training Runs"
        case .active: return "No Active Runs"
        case .completed: return "No Completed Runs"
        case .failed: return "No Failed Runs"
        }
    }

    private var subtitleForFilter: String {
        switch filter {
        case .all: return "Start a training run to train your models on your datasets"
        case .active: return "No training is currently running"
        case .completed: return "Completed runs will appear here"
        case .failed: return "Great! No failures to report"
        }
    }
}

// MARK: - Placeholder Detail View

struct PlaceholderDetailView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Run List Item

struct RunListItem: View {
    let run: TrainingRun
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var onToggleSelection: (() -> Void)?
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            if isSelectionMode {
                Button(action: { onToggleSelection?() }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Status Icon with animation
            ZStack {
                Circle()
                    .fill(run.status.color.opacity(0.15))
                    .frame(width: 40, height: 40)

                if run.status == .running {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: run.status.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(run.status.color)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(run.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(run.modelName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if run.status == .running || run.status == .paused {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Epoch \(run.currentEpoch)/\(run.totalEpochs)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Progress/Status
            VStack(alignment: .trailing, spacing: 4) {
                if run.status == .running || run.status == .paused {
                    Text("\(Int(run.progress * 100))%")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)

                    ProgressView(value: run.progress)
                        .frame(width: 80)
                        .tint(run.status == .paused ? .orange : .accentColor)
                } else if run.status == .completed {
                    if let accuracy = run.accuracy {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption2)
                            Text(String(format: "%.1f%%", accuracy * 100))
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.green)
                    }
                } else {
                    StatusBadge(text: run.status.rawValue, color: run.status.color)
                }
            }

            // Quick Actions
            if run.status == .running {
                Button(action: { appState.pauseTraining(runId: run.id) }) {
                    Image(systemName: "pause.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.borderless)
                .help("Pause training")
            } else if run.status == .paused {
                Button(action: { appState.resumeTraining(runId: run.id) }) {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
                .help("Resume training")
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Run Detail View

struct RunDetailView: View {
    let run: TrainingRun
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: DetailTab = .training
    @State private var showCancelConfirmation = false
    @State private var showDeleteConfirmation = false

    enum DetailTab: String, CaseIterable {
        case training = "Training"
        case console = "Console"
        case config = "Config"
    }

    var isActive: Bool {
        run.status == .running || run.status == .paused
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    // Status indicator
                    ZStack {
                        Circle()
                            .fill(run.status.color.opacity(0.15))
                            .frame(width: 50, height: 50)
                        if run.status == .running {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: run.status.icon)
                                .font(.title2)
                                .foregroundColor(run.status.color)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        HStack(spacing: 8) {
                            Text(run.modelName)
                                .foregroundColor(.secondary)
                            Text("•")
                                .foregroundColor(.secondary)
                            StatusBadge(text: run.status.rawValue, color: run.status.color)
                        }
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        actionButtons
                    }
                }

                // Stats bar
                TrainingStatsBar(run: run)

                // Progress bar for active training
                if isActive {
                    VStack(spacing: 4) {
                        ProgressView(value: run.progress)
                            .tint(run.status == .paused ? .orange : .accentColor)

                        HStack {
                            Text("Epoch \(run.currentEpoch) of \(run.totalEpochs)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(run.progress * 100))% complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // Tab selector
            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            Group {
                switch selectedTab {
                case .training:
                    TrainingTabContent(run: run, isActive: isActive)
                case .console:
                    ConsoleTabContent(logs: run.logs)
                case .config:
                    ConfigTabContent(run: run)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Stop Training", isPresented: $showCancelConfirmation) {
            Button("Continue Training", role: .cancel) {}
            Button("Stop", role: .destructive) {
                appState.cancelTraining(runId: run.id)
            }
        } message: {
            Text("Are you sure you want to stop this training run? Progress will be lost.")
        }
        .alert("Delete Run", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await appState.deleteRun(run) }
            }
        } message: {
            Text("Are you sure you want to delete this run? This cannot be undone.")
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if run.status == .running {
            Button(action: { appState.pauseTraining(runId: run.id) }) {
                Label("Pause", systemImage: "pause.fill")
            }
            .buttonStyle(.bordered)

            Button(action: { showCancelConfirmation = true }) {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        } else if run.status == .paused {
            Button(action: { appState.resumeTraining(runId: run.id) }) {
                Label("Resume", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)

            Button(action: { showCancelConfirmation = true }) {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        } else if run.status == .completed {
            Button(action: { exportModel() }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }

        // Delete button for non-active runs
        if !isActive {
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    private func exportModel() {
        Task {
            guard let checkpoint = try? await CheckpointManager.shared.getLatestCheckpoint(runId: run.id) else {
                appState.errorMessage = "No checkpoint found for this run"
                return
            }

            let panel = NSSavePanel()
            panel.title = "Export Trained Model"
            panel.nameFieldStringValue = "\(run.name.replacingOccurrences(of: " ", with: "_")).safetensors"
            panel.allowedContentTypes = [.data]
            panel.canCreateDirectories = true

            if panel.runModal() == .OK, let url = panel.url {
                do {
                    let sourceURL = URL(fileURLWithPath: checkpoint.path)
                    try FileManager.default.copyItem(at: sourceURL, to: url)
                    appState.showSuccess("Model exported successfully")
                } catch {
                    appState.errorMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Training Tab Content

struct TrainingTabContent: View {
    let run: TrainingRun
    let isActive: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LiveTrainingChart(metrics: run.metrics, isTraining: isActive)

                if isActive {
                    GPUMonitorView()
                }

                if !run.metrics.isEmpty {
                    MetricsTableView(metrics: run.metrics)
                }
            }
            .padding()
        }
    }
}

struct MetricsTableView: View {
    let metrics: [MetricPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training History")
                .font(.headline)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Epoch").frame(width: 60, alignment: .leading)
                    Text("Loss").frame(width: 80, alignment: .trailing)
                    Text("Accuracy").frame(width: 80, alignment: .trailing)
                    Text("Time").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                ForEach(metrics.suffix(10).reversed()) { metric in
                    HStack {
                        Text("\(metric.epoch)").frame(width: 60, alignment: .leading)
                        Text(String(format: "%.4f", metric.loss))
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(.red)
                        Text(String(format: "%.1f%%", metric.accuracy * 100))
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(.green)
                        Text(metric.timestamp.formatted(date: .omitted, time: .shortened))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    if metric.id != metrics.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - Console Tab Content

struct ConsoleTabContent: View {
    @EnvironmentObject var appState: AppState
    let logs: [LogEntry]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.green)
                Text("Console Output")
                    .font(.headline)
                Spacer()
                Text("\(logs.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: { copyLogs() }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy all logs")
            }
            .padding()
            .background(Color.black.opacity(0.8))

            ConsoleView(logs: logs)
        }
    }

    private func copyLogs() {
        let logText = logs.map { log in
            "[\(log.timestamp.formatted(date: .omitted, time: .standard))] [\(log.level.rawValue.uppercased())] \(log.message)"
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logText, forType: .string)
        appState.showSuccess("Logs copied to clipboard")
    }
}

// MARK: - Config Tab Content

struct ConfigTabContent: View {
    let run: TrainingRun

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ConfigSection(title: "Model Architecture") {
                    ConfigRow(label: "Architecture", value: run.architectureType)
                }

                ConfigSection(title: "Training Configuration") {
                    ConfigRow(label: "Epochs", value: "\(run.totalEpochs)")
                    ConfigRow(label: "Batch Size", value: "\(run.batchSize)")
                    ConfigRow(label: "Learning Rate", value: String(format: "%.6f", run.learningRate))
                }

                ConfigSection(title: "Run Information") {
                    ConfigRow(label: "Run ID", value: String(run.id.prefix(8)) + "...")
                    ConfigRow(label: "Model", value: run.modelName)
                    ConfigRow(label: "Started", value: run.startedAt.formatted())
                    if let finished = run.finishedAt {
                        ConfigRow(label: "Finished", value: finished.formatted())
                    }
                    ConfigRow(label: "Status", value: run.status.rawValue)
                }

                if run.status == .completed {
                    ConfigSection(title: "Results") {
                        if let loss = run.loss {
                            ConfigRow(label: "Final Loss", value: String(format: "%.4f", loss))
                        }
                        if let accuracy = run.accuracy {
                            ConfigRow(label: "Final Accuracy", value: String(format: "%.2f%%", accuracy * 100))
                        }
                        ConfigRow(label: "Total Duration", value: run.duration)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Console View

struct ConsoleView: View {
    let logs: [LogEntry]

    var body: some View {
        if logs.isEmpty {
            VStack {
                Image(systemName: "terminal")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text("Waiting for output...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.9))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logs) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)

                                Text(entry.level.prefix)
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(entry.level.color)
                                    .frame(width: 50, alignment: .leading)

                                Text(entry.message)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(entry.level == .error ? .red : .primary)
                                    .textSelection(.enabled)
                            }
                            .id(entry.id)
                        }
                    }
                    .padding()
                }
                .background(Color.black.opacity(0.9))
                .onChange(of: logs.count) { _, _ in
                    if let lastLog = logs.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastLog = logs.last {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ConfigSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct ConfigRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .textSelection(.enabled)
        }
        .font(.system(.body, design: .monospaced))
    }
}
