import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            Group {
                switch appState.selectedTab {
                case .dashboard:
                    DashboardView()
                case .models:
                    ModelsView()
                case .runs:
                    RunsView()
                case .experiments:
                    ExperimentBrowserView()
                case .distillation:
                    DistillationView()
                case .metrics:
                    MetricsDashboardView()
                case .datasets:
                    DatasetsView()
                case .inference:
                    InferenceView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .overlay {
            if appState.isLoading {
                LoadingOverlay(message: appState.loadingMessage)
            }
        }
        .overlay(alignment: .top) {
            if let successMessage = appState.successMessage {
                SuccessToast(message: successMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: appState.successMessage)
                    .padding(.top, 8)
            }
        }
        .alert(L.error, isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button(L.ok) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .sheet(isPresented: $appState.showNewModelSheet) {
            NewModelSheet()
        }
        .sheet(isPresented: $appState.showNewRunSheet) {
            NewRunSheet()
        }
        .sheet(isPresented: $appState.showImportDatasetSheet) {
            ImportDatasetSheet()
        }
        .sheet(isPresented: $appState.showNewDistillationSheet) {
            DistillationWizard()
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var modelsExpanded = true
    @State private var runsExpanded = true

    var body: some View {
        List(selection: $appState.selectedTab) {
            Section(L.dashboard) {
                Label(NavigationTab.dashboard.localizedName, systemImage: NavigationTab.dashboard.icon)
                    .tag(NavigationTab.dashboard)
            }

            // Models Section - Expandable with individual models
            Section(L.models) {
                DisclosureGroup(isExpanded: $modelsExpanded) {
                    ForEach(appState.models) { model in
                        Button {
                            appState.selectedModelId = model.id
                            appState.selectedTab = .models
                        } label: {
                            SidebarModelRow(model: model)
                        }
                        .buttonStyle(.plain)
                    }

                    if appState.models.isEmpty {
                        Text(L.noModelsYet)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                } label: {
                    Button {
                        appState.selectedModelId = nil
                        appState.selectedTab = .models
                    } label: {
                        HStack {
                            Label(L.allModels, systemImage: NavigationTab.models.icon)
                            Spacer()
                            Text("\(appState.models.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Training Runs Section - Expandable with individual runs
            Section(L.training) {
                DisclosureGroup(isExpanded: $runsExpanded) {
                    // Active runs first
                    if !appState.activeRuns.isEmpty {
                        ForEach(appState.activeRuns) { run in
                            Button {
                                appState.selectedRunId = run.id
                                appState.selectedTab = .runs
                            } label: {
                                SidebarRunRow(run: run, isActive: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Recent completed runs
                    ForEach(appState.completedRuns.prefix(5)) { run in
                        Button {
                            appState.selectedRunId = run.id
                            appState.selectedTab = .runs
                        } label: {
                            SidebarRunRow(run: run, isActive: false)
                        }
                        .buttonStyle(.plain)
                    }

                    if appState.activeRuns.isEmpty && appState.completedRuns.isEmpty {
                        Text(L.noTrainingRunsYet)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                } label: {
                    Button {
                        appState.selectedRunId = nil
                        appState.selectedTab = .runs
                    } label: {
                        HStack {
                            Label(L.trainingRuns, systemImage: NavigationTab.runs.icon)
                            Spacer()
                            if !appState.activeRuns.isEmpty {
                                Text(L.nActive(appState.activeRuns.count))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section(L.experiments) {
                Label(NavigationTab.experiments.localizedName, systemImage: NavigationTab.experiments.icon)
                    .tag(NavigationTab.experiments)

                Label(NavigationTab.datasets.localizedName, systemImage: NavigationTab.datasets.icon)
                    .tag(NavigationTab.datasets)
                    .badge(appState.datasets.count)

                Label(NavigationTab.inference.localizedName, systemImage: NavigationTab.inference.icon)
                    .tag(NavigationTab.inference)
            }

            Section(L.distillation) {
                Label(NavigationTab.distillation.localizedName, systemImage: NavigationTab.distillation.icon)
                    .tag(NavigationTab.distillation)
                    .badge(appState.activeDistillations.count)
            }

            Section(L.metrics) {
                Label(NavigationTab.metrics.localizedName, systemImage: NavigationTab.metrics.icon)
                    .tag(NavigationTab.metrics)
            }

            Section {
                Label(NavigationTab.settings.localizedName, systemImage: NavigationTab.settings.icon)
                    .tag(NavigationTab.settings)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button(action: { appState.showNewModelSheet = true }) {
                        Label(L.newModel, systemImage: "cpu.fill")
                    }
                    Button(action: { appState.showNewRunSheet = true }) {
                        Label(L.newTrainingRun, systemImage: "play.fill")
                    }
                    Button(action: { appState.showImportDatasetSheet = true }) {
                        Label(L.importDataset, systemImage: "folder.badge.plus")
                    }
                    Divider()
                    Button(action: { appState.showNewDistillationSheet = true }) {
                        Label(L.newDistillation, systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - Sidebar Model Row

struct SidebarModelRow: View {
    let model: MLModel
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(model.framework.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
        .contextMenu {
            Button {
                appState.selectedModelId = model.id
                appState.showNewRunSheet = true
            } label: {
                Label(L.trainModel, systemImage: "play.fill")
            }

            if model.status == .ready && model.filePath != nil {
                Button {
                    appState.selectedModelId = model.id
                    appState.selectedTab = .inference
                } label: {
                    Label(L.runInference, systemImage: "wand.and.stars")
                }
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.id, forType: .string)
            } label: {
                Label(L.copyModelId, systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(L.deleteModel, systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(L.delete, systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                appState.selectedModelId = model.id
                appState.showNewRunSheet = true
            } label: {
                Label(L.train, systemImage: "play.fill")
            }
            .tint(.green)
        }
        .alert(L.deleteModel, isPresented: $showDeleteConfirmation) {
            Button(L.cancel, role: .cancel) {}
            Button(L.delete, role: .destructive) {
                Task { await appState.deleteModel(model) }
            }
        } message: {
            Text(L.confirmDeleteModel(model.name))
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .ready: return .green
        case .training: return .orange
        case .draft: return .gray
        case .failed: return .red
        case .archived: return .purple
        case .importing: return .blue
        case .deployed: return .teal
        case .deprecated: return .brown
        }
    }
}

// MARK: - Sidebar Run Row

struct SidebarRunRow: View {
    let run: TrainingRun
    let isActive: Bool
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    @State private var showCancelConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            if isActive {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: statusIcon)
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .frame(width: 12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(run.name)
                    .font(.subheadline)
                    .lineLimit(1)

                if isActive {
                    Text("\(Int(run.progress * 100))% - Epoch \(run.currentEpoch)/\(run.totalEpochs)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text(run.status.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
        .contextMenu {
            if run.status == .running {
                Button {
                    appState.pauseTraining(runId: run.id)
                } label: {
                    Label(L.pause, systemImage: "pause.fill")
                }
                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    Label(L.stopTraining, systemImage: "stop.fill")
                }
            } else if run.status == .paused {
                Button {
                    appState.resumeTraining(runId: run.id)
                } label: {
                    Label(L.resume, systemImage: "play.fill")
                }
                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    Label(L.stopTraining, systemImage: "stop.fill")
                }
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(run.id, forType: .string)
            } label: {
                Label(L.copyRunId, systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(L.deleteRun, systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(L.delete, systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if run.status == .running {
                Button {
                    appState.pauseTraining(runId: run.id)
                } label: {
                    Label(L.pause, systemImage: "pause.fill")
                }
                .tint(.orange)
            } else if run.status == .paused {
                Button {
                    appState.resumeTraining(runId: run.id)
                } label: {
                    Label(L.resume, systemImage: "play.fill")
                }
                .tint(.green)
            }
        }
        .alert(L.deleteRun, isPresented: $showDeleteConfirmation) {
            Button(L.cancel, role: .cancel) {}
            Button(L.delete, role: .destructive) {
                Task { await appState.deleteRun(run) }
            }
        } message: {
            Text(L.confirmDeleteModel(run.name))
        }
        .alert(L.stopTraining, isPresented: $showCancelConfirmation) {
            Button(L.continueTraining, role: .cancel) {}
            Button(L.stop, role: .destructive) {
                appState.cancelTraining(runId: run.id)
            }
        } message: {
            Text(L.confirmStopTraining())
        }
    }

    private var statusIcon: String {
        switch run.status {
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        case .paused: return "pause.circle.fill"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch run.status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        case .paused: return .yellow
        default: return .gray
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(message)
                    .foregroundColor(.secondary)
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - Success Toast

struct SuccessToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            Spacer()
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(height: 120)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?

    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(spacing: 24) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    iconScale = 1.0
                    iconOpacity = 1.0
                }
            }

            // Content
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 350)
            }
            .opacity(contentOpacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                    contentOpacity = 1.0
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                if let actionTitle = actionTitle, let action = action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }

                if let secondaryTitle = secondaryActionTitle, let secondaryAction = secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .opacity(buttonsOpacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                    buttonsOpacity = 1.0
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String?
    let actionLabel: String?
    let action: (() -> Void)?

    init(_ title: String, icon: String? = nil, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(title)
                .font(.headline)
            Spacer()
            if let actionLabel = actionLabel, let action = action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderless)
            }
        }
    }
}
