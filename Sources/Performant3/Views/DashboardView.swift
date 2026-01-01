import SwiftUI
import Charts
import AppKit

// MARK: - Modern MLOps Dashboard

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var storageStats: StorageStats?
    @State private var systemMetrics = SystemMetrics()
    @State private var showWelcome = true
    @State private var selectedHubTab = 0

    // Computed analytics
    var completedRuns: [TrainingRun] {
        appState.runs.filter { $0.status == .completed }
    }

    var averageAccuracy: Double? {
        let accuracies = completedRuns.compactMap { $0.accuracy }
        guard !accuracies.isEmpty else { return nil }
        return accuracies.reduce(0, +) / Double(accuracies.count)
    }

    var bestModel: (run: TrainingRun, accuracy: Double)? {
        completedRuns
            .compactMap { run -> (TrainingRun, Double)? in
                guard let acc = run.accuracy else { return nil }
                return (run, acc)
            }
            .max(by: { $0.1 < $1.1 })
    }

    var totalTrainingTime: TimeInterval {
        completedRuns.reduce(0) { total, run in
            guard let finished = run.finishedAt else { return total }
            return total + finished.timeIntervalSince(run.startedAt)
        }
    }

    var body: some View {
        ZStack {
            // Background
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero Header
                    heroHeader

                    // Live Metrics Bar
                    liveMetricsBar
                        .padding(.horizontal)

                    // Stats Grid - Key Metrics
                    statsGrid
                        .padding(.horizontal)

                    // Active Training Section
                    if !appState.activeRuns.isEmpty {
                        activeTrainingSection
                            .padding(.horizontal)
                    }

                    // Model Hub & Dataset Hub
                    hubsSection
                        .padding(.horizontal)

                    // Training Analytics (if there are completed runs)
                    if !completedRuns.isEmpty {
                        modernAnalyticsSection
                            .padding(.horizontal)
                    }

                    // Quick Actions Grid
                    quickActionsSection
                        .padding(.horizontal)

                    // Recent Activity
                    recentActivitySection
                        .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }
        }
        .task {
            storageStats = await appState.getStorageStats()
            startSystemMonitoring()
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("MLOps Command Center")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryGradient)

                    if !appState.activeRuns.isEmpty {
                        HStack(spacing: 6) {
                            PulsingDot(color: AppTheme.success)
                            Text("\(appState.activeRuns.count) Active")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppTheme.success)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.success.opacity(0.15))
                        .cornerRadius(12)
                    }
                }

                Text("Train, deploy, and monitor your machine learning models")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            // System Status Indicator
            HStack(spacing: 16) {
                systemStatusWidget

                Button(action: { Task { await appState.loadData() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.primary.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - System Status Widget

    private var systemStatusWidget: some View {
        HStack(spacing: 12) {
            // CPU
            VStack(spacing: 2) {
                GlowingIcon(systemName: "cpu", color: AppTheme.primary, size: 16)
                Text("\(Int(systemMetrics.cpuUsage))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Memory
            VStack(spacing: 2) {
                GlowingIcon(systemName: "memorychip", color: AppTheme.secondary, size: 16)
                Text("\(formatMemory(systemMetrics.memoryUsed))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }

            // GPU
            VStack(spacing: 2) {
                GlowingIcon(systemName: "gpu", color: AppTheme.success, size: 16)
                Text(systemMetrics.gpuAvailable ? "Ready" : "N/A")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceElevated.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Live Metrics Bar

    private var liveMetricsBar: some View {
        HStack(spacing: 0) {
            LiveMetricPill(
                icon: "clock.fill",
                label: "Uptime",
                value: formatUptime(systemMetrics.uptime),
                color: AppTheme.primary
            )

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.1))

            LiveMetricPill(
                icon: "bolt.fill",
                label: "Throughput",
                value: "\(Int(systemMetrics.throughput)) it/s",
                color: AppTheme.success
            )

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.1))

            LiveMetricPill(
                icon: "server.rack",
                label: "Jobs Queue",
                value: "\(appState.activeRuns.count)",
                color: AppTheme.warning
            )

            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.1))

            LiveMetricPill(
                icon: "checkmark.seal.fill",
                label: "Success Rate",
                value: successRate,
                color: AppTheme.success
            )
        }
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var successRate: String {
        let completed = completedRuns.count
        let failed = appState.runs.filter { $0.status == .failed }.count
        let total = completed + failed
        guard total > 0 else { return "100%" }
        return "\(Int(Double(completed) / Double(total) * 100))%"
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ModernStatCard(
                title: "Models",
                value: appState.models.count,
                icon: "cube.fill",
                gradient: AppTheme.primaryGradient,
                trend: nil
            )

            ModernStatCard(
                title: "Training Runs",
                value: appState.runs.count,
                icon: "play.circle.fill",
                gradient: AppTheme.successGradient,
                trend: appState.activeRuns.isEmpty ? nil : "+\(appState.activeRuns.count) active"
            )

            ModernStatCard(
                title: "Datasets",
                value: appState.datasets.count,
                icon: "cylinder.split.1x2.fill",
                gradient: AppTheme.warmGradient,
                trend: nil
            )

            ModernStatCard(
                title: "Storage",
                value: -1,
                displayValue: storageStats.map { formatBytes($0.totalSize) } ?? "--",
                icon: "externaldrive.fill",
                gradient: LinearGradient(colors: [AppTheme.secondary, AppTheme.primary], startPoint: .topLeading, endPoint: .bottomTrailing),
                trend: nil
            )
        }
    }

    // MARK: - Active Training Section

    private var activeTrainingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModernSectionHeader(title: "Active Training", icon: "bolt.fill", iconColor: AppTheme.success) {
                Text("\(appState.activeRuns.count) running")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
            }

            ForEach(appState.activeRuns.prefix(3)) { run in
                ModernActiveRunCard(run: run)
            }

            if appState.activeRuns.count > 3 {
                Button(action: { appState.selectedTab = .runs }) {
                    HStack {
                        Text("View all \(appState.activeRuns.count) active runs")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Hubs Section

    private var hubsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tab Selector
            HStack(spacing: 0) {
                HubTabButton(title: "Model Hub", icon: "cube.fill", isSelected: selectedHubTab == 0) {
                    withAnimation(.spring(duration: 0.3)) { selectedHubTab = 0 }
                }

                HubTabButton(title: "Dataset Hub", icon: "cylinder.split.1x2.fill", isSelected: selectedHubTab == 1) {
                    withAnimation(.spring(duration: 0.3)) { selectedHubTab = 1 }
                }
            }
            .padding(4)
            .background(AppTheme.surface)
            .cornerRadius(12)

            // Hub Content
            if selectedHubTab == 0 {
                modelHubContent
            } else {
                datasetHubContent
            }
        }
    }

    private var modelHubContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Model Architectures")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("Train with MLX on Apple Silicon")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(modelTemplates) { template in
                    ModelTemplateCard(template: template)
                }
            }
        }
    }

    private var datasetHubContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Datasets")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("Built-in datasets ready to use")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
            }

            if popularDatasets.isEmpty {
                Text("No datasets available")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(popularDatasets) { dataset in
                        BuiltInDatasetCard(dataset: dataset)
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModernSectionHeader(title: "Quick Actions", icon: "bolt.horizontal.fill", iconColor: AppTheme.warning)

            HStack(spacing: 12) {
                ModernQuickAction(
                    title: "New Model",
                    subtitle: "Import or create",
                    icon: "plus.square.fill",
                    gradient: AppTheme.primaryGradient
                ) {
                    appState.showNewModelSheet = true
                }

                ModernQuickAction(
                    title: "Start Training",
                    subtitle: "Train a model",
                    icon: "play.fill",
                    gradient: AppTheme.successGradient
                ) {
                    appState.showNewRunSheet = true
                }

                ModernQuickAction(
                    title: "Import Dataset",
                    subtitle: "Add training data",
                    icon: "folder.badge.plus",
                    gradient: AppTheme.warmGradient
                ) {
                    appState.showImportDatasetSheet = true
                }

                ModernQuickAction(
                    title: "Run Inference",
                    subtitle: "Test your model",
                    icon: "wand.and.stars",
                    gradient: LinearGradient(colors: [AppTheme.secondary, AppTheme.primary], startPoint: .topLeading, endPoint: .bottomTrailing)
                ) {
                    appState.selectedTab = .inference
                }
            }
        }
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModernSectionHeader(title: "Recent Activity", icon: "clock.fill", iconColor: AppTheme.textMuted)

            if appState.runs.isEmpty && appState.models.isEmpty {
                // Empty State - Getting Started
                gettingStartedCard
            } else {
                VStack(spacing: 8) {
                    // Recent Models
                    if !appState.models.isEmpty {
                        ForEach(appState.models.prefix(3)) { model in
                            ActivityRow(
                                icon: model.framework.icon,
                                iconColor: model.framework.color,
                                title: model.name,
                                subtitle: model.framework.rawValue,
                                timestamp: model.createdAt,
                                badge: model.accuracy > 0 ? String(format: "%.1f%%", model.accuracy * 100) : nil
                            )
                        }
                    }

                    // Recent Completed Runs
                    ForEach(completedRuns.prefix(3)) { run in
                        ActivityRow(
                            icon: "checkmark.circle.fill",
                            iconColor: AppTheme.success,
                            title: run.name,
                            subtitle: "Training completed",
                            timestamp: run.finishedAt ?? run.startedAt,
                            badge: run.accuracy.map { String(format: "%.1f%%", $0 * 100) }
                        )
                    }
                }
                .padding()
                .background(AppTheme.surface)
                .cornerRadius(12)
            }
        }
    }

    private var gettingStartedCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryGradient)
                        .frame(width: 56, height: 56)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Performant3")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Your end-to-end MLOps platform powered by Apple Silicon")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()
            }

            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 12) {
                Button(action: { Task { await appState.loadDemoData() } }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Load Demo Data")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.primaryGradient)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: { appState.showNewModelSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Model")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.primary.opacity(0.15))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(20)
        .background(AppTheme.surfaceElevated)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.primary.opacity(0.3), AppTheme.secondary.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Modern Analytics Section

    private var modernAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ModernSectionHeader(title: "Training Analytics", icon: "chart.bar.fill", iconColor: AppTheme.primary)

            HStack(spacing: 16) {
                // Key Metrics
                VStack(spacing: 12) {
                    AnalyticsGaugeCard(
                        title: "Avg Accuracy",
                        value: averageAccuracy ?? 0,
                        maxValue: 1.0,
                        color: AppTheme.success
                    )

                    if let best = bestModel {
                        AnalyticsGaugeCard(
                            title: "Best Model",
                            value: best.accuracy,
                            maxValue: 1.0,
                            color: AppTheme.warning,
                            subtitle: best.run.name
                        )
                    }
                }
                .frame(width: 200)

                // Chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accuracy Trend")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    ModernAccuracyChart(runs: completedRuns)
                }
                .padding()
                .background(AppTheme.surface)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    private func startSystemMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Simulate system metrics updates
            systemMetrics.cpuUsage = Double.random(in: 15...45)
            systemMetrics.memoryUsed = Double.random(in: 8...16) * 1024 * 1024 * 1024
            systemMetrics.uptime += 2
            systemMetrics.throughput = appState.activeRuns.isEmpty ? 0 : Double.random(in: 50...200)
        }
    }

    private func formatMemory(_ bytes: Double) -> String {
        let gb = bytes / (1024 * 1024 * 1024)
        return String(format: "%.1fGB", gb)
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

// MARK: - System Metrics

struct SystemMetrics {
    var cpuUsage: Double = 25
    var memoryUsed: Double = 12 * 1024 * 1024 * 1024
    var gpuAvailable: Bool = true
    var uptime: TimeInterval = 0
    var throughput: Double = 0
}

// MARK: - Supporting Views

struct LiveMetricPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }
}

struct ModernStatCard: View {
    let title: String
    let value: Int
    var displayValue: String? = nil
    let icon: String
    let gradient: LinearGradient
    let trend: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(gradient.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(gradient)
                }

                Spacer()

                if let trend = trend {
                    Text(trend)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.success.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayValue ?? "\(value)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(gradient)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct ModernSectionHeader<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder var trailing: () -> Content

    init(title: String, icon: String, iconColor: Color, @ViewBuilder trailing: @escaping () -> Content = { EmptyView() }) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            trailing()
        }
    }
}

struct ModernActiveRunCard: View {
    let run: TrainingRun
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            // Progress Ring
            ZStack {
                ProgressRing(progress: run.progress, color: AppTheme.success, lineWidth: 4)
                    .frame(width: 48, height: 48)

                Text("\(Int(run.progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(run.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 8) {
                    Text(run.modelName)
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)

                    Text("Epoch \(run.currentEpoch)/\(run.totalEpochs)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            // Metrics
            if let loss = run.loss {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.4f", loss))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Loss")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            // Actions
            HStack(spacing: 8) {
                if run.status == .running {
                    Button(action: { appState.pauseTraining(runId: run.id) }) {
                        Image(systemName: "pause.fill")
                            .foregroundColor(AppTheme.warning)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { appState.cancelTraining(runId: run.id) }) {
                    Image(systemName: "xmark")
                        .foregroundColor(AppTheme.error)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.success.opacity(0.3), lineWidth: 1)
        )
    }
}

struct HubTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.surfaceElevated : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct ModelTemplateCard: View {
    let template: ModelTemplate
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.primary.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: template.icon)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.primary)
                }

                Spacer()

                Text(template.task)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppTheme.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.secondary.opacity(0.15))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(template.description)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(2)
                    .frame(height: 26, alignment: .top)
            }

            Button(action: {
                // Create model from template and open training sheet
                Task {
                    await appState.createModelFromTemplate(template)
                    appState.showNewRunSheet = true
                }
            }) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("Train")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(AppTheme.primaryGradient)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(isHovered ? AppTheme.surfaceHover : AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct HFModelCard: View {
    let model: HFModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.primary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: model.icon)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.primary)
                }

                Spacer()

                Text(model.task)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.secondary.opacity(0.15))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(model.description)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                    Text(model.downloads)
                        .font(.system(size: 10))
                }
                .foregroundColor(AppTheme.textMuted)

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    Text("\(model.likes)")
                        .font(.system(size: 10))
                }
                .foregroundColor(AppTheme.textMuted)

                Spacer()

                Button(action: { appState.showNewModelSheet = true }) {
                    Text("Import")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct BuiltInDatasetCard: View {
    let dataset: PopularDataset
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.success.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: dataset.icon)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.success)
                }

                Spacer()

                HStack(spacing: 4) {
                    if dataset.isBuiltIn {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 8))
                    }
                    Text(dataset.isBuiltIn ? "Built-in" : dataset.task)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.success.opacity(0.15))
                .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dataset.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(dataset.description)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(2)
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 10))
                    Text(dataset.samples)
                        .font(.system(size: 10))
                }
                .foregroundColor(AppTheme.textMuted)

                Spacer()

                Button(action: {
                    // Start training with this dataset
                    appState.showNewRunSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text("Train")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(AppTheme.successGradient)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(isHovered ? AppTheme.surfaceHover : AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct PopularDatasetCard: View {
    let dataset: PopularDataset
    @EnvironmentObject var appState: AppState

    var body: some View {
        BuiltInDatasetCard(dataset: dataset)
    }
}

struct ModernQuickAction: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(gradient.opacity(isHovered ? 0.4 : 0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(gradient)
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(isHovered ? AppTheme.surfaceHover : AppTheme.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(isHovered ? 0.1 : 0.05), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct ActivityRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let timestamp: Date
    let badge: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()

            if let badge = badge {
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.success.opacity(0.15))
                    .cornerRadius(4)
            }

            Text(timestamp, style: .relative)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.vertical, 8)
    }
}

struct AnalyticsGaugeCard: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                ProgressRing(progress: value / maxValue, color: color, lineWidth: 6)
                    .frame(width: 64, height: 64)

                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(12)
    }
}

struct ModernAccuracyChart: View {
    let runs: [TrainingRun]

    var chartData: [(name: String, accuracy: Double, index: Int)] {
        runs.suffix(8).enumerated().compactMap { index, run in
            guard let acc = run.accuracy else { return nil }
            return (run.name, acc * 100, index)
        }
    }

    var body: some View {
        if chartData.count > 1 {
            Chart(chartData, id: \.index) { item in
                BarMark(
                    x: .value("Run", item.index),
                    y: .value("Accuracy", item.accuracy)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)%")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    AxisGridLine()
                        .foregroundStyle(Color.white.opacity(0.1))
                }
            }
            .frame(height: 140)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.textMuted)
                Text("Complete more runs to see trends")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
        }
    }
}

// MARK: - Legacy Support Components (using existing definitions from ContentView)

// Keep existing helper views for compatibility
struct ActiveRunCard: View {
    let run: TrainingRun
    @EnvironmentObject var appState: AppState
    @State private var showCancelConfirmation = false

    var body: some View {
        ModernActiveRunCard(run: run)
    }
}

struct ModelQuickCard: View {
    let model: MLModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        HFModelCard(model: HFModel(
            id: model.id,
            name: model.name,
            description: model.framework.rawValue,
            downloads: "--",
            likes: 0,
            task: model.status.rawValue,
            icon: model.framework.icon
        ))
    }
}

struct CompletedRunCard: View {
    let run: TrainingRun

    var body: some View {
        ActivityRow(
            icon: "checkmark.circle.fill",
            iconColor: AppTheme.success,
            title: run.name,
            subtitle: run.modelName,
            timestamp: run.finishedAt ?? run.startedAt,
            badge: run.accuracy.map { String(format: "%.1f%%", $0 * 100) }
        )
        .padding(.horizontal)
        .background(AppTheme.surface)
        .cornerRadius(8)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        ModernQuickAction(
            title: title,
            subtitle: "",
            icon: icon,
            gradient: LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
            action: action
        )
    }
}

// MARK: - Keep Analytics Section Components

struct TrainingAnalyticsSection: View {
    let completedRuns: [TrainingRun]
    let averageAccuracy: Double?
    let bestModel: (run: TrainingRun, accuracy: Double)?
    let totalTrainingTime: TimeInterval

    var body: some View {
        EmptyView() // Replaced by modernAnalyticsSection
    }
}

struct AnalyticsMetricsColumn: View {
    let completedRuns: [TrainingRun]
    let averageAccuracy: Double?
    let bestModel: (run: TrainingRun, accuracy: Double)?
    let totalTrainingTime: TimeInterval

    var body: some View {
        EmptyView()
    }
}

struct AccuracyTrendChart: View {
    let completedRuns: [TrainingRun]
    let bestAccuracy: Double?

    var body: some View {
        ModernAccuracyChart(runs: completedRuns)
    }
}

struct ArchitectureDistributionChart: View {
    let completedRuns: [TrainingRun]

    var body: some View {
        EmptyView()
    }
}

struct AnalyticsMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        EmptyView()
    }
}
