import SwiftUI

/// System status panel showing GPU, memory, and Python environment status
struct SystemStatusView: View {
    @ObservedObject private var monitor = SystemMonitorService.shared
    @State private var pythonStatus: PythonEnvironmentManager.Status = .notChecked
    @State private var pythonVersion: String?
    @State private var isCheckingPython = false
    @State private var isSettingUpPython = false
    @State private var setupProgress: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // GPU Status
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("GPU", systemImage: "gpu")
                            .font(.headline)

                        if monitor.gpuInfo.isAvailable {
                            HStack {
                                Text(monitor.gpuInfo.name)
                                    .font(.subheadline)
                                Spacer()
                                statusBadge(status: .healthy, text: "Available")
                            }

                            Divider()

                            MetricRow(
                                label: "Memory",
                                value: String(format: "%.1f GB", monitor.gpuInfo.recommendedMemoryGB),
                                icon: "memorychip"
                            )

                            MetricRow(
                                label: "Allocated",
                                value: String(format: "%.2f GB", monitor.gpuInfo.currentAllocatedGB),
                                icon: "chart.bar.fill"
                            )

                            ProgressView(value: monitor.gpuMemoryUsagePercent / 100)
                                .tint(progressColor(for: monitor.gpuMemoryUsagePercent))
                        } else {
                            HStack {
                                Text("No GPU detected")
                                    .foregroundColor(.secondary)
                                Spacer()
                                statusBadge(status: .warning, text: "CPU Only")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Memory Status
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("System Memory", systemImage: "memorychip")
                            .font(.headline)

                        MetricRow(
                            label: "Total",
                            value: String(format: "%.1f GB", monitor.memoryInfo.totalGB),
                            icon: "square.stack.3d.up"
                        )

                        MetricRow(
                            label: "Used",
                            value: String(format: "%.1f GB (%.0f%%)", monitor.memoryInfo.usedGB, monitor.memoryInfo.usagePercent),
                            icon: "chart.pie.fill"
                        )

                        MetricRow(
                            label: "App Usage",
                            value: String(format: "%.0f MB", monitor.memoryInfo.appUsedMB),
                            icon: "app.fill"
                        )

                        ProgressView(value: monitor.memoryInfo.usagePercent / 100)
                            .tint(progressColor(for: monitor.memoryInfo.usagePercent))
                    }
                    .padding(.vertical, 4)
                }

                // CPU Status
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("CPU", systemImage: "cpu")
                            .font(.headline)

                        HStack {
                            Text("Usage")
                            Spacer()
                            Text(String(format: "%.1f%%", monitor.cpuUsage))
                                .fontWeight(.medium)
                        }

                        ProgressView(value: min(monitor.cpuUsage, 100) / 100)
                            .tint(progressColor(for: monitor.cpuUsage))
                    }
                    .padding(.vertical, 4)
                }

                // Python Environment
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Python Environment", systemImage: "terminal")
                                .font(.headline)
                            Spacer()
                            if isCheckingPython {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }

                        switch pythonStatus {
                        case .ready:
                            HStack {
                                if let version = pythonVersion {
                                    Text(version)
                                        .font(.subheadline)
                                }
                                Spacer()
                                statusBadge(status: .healthy, text: "Ready")
                            }

                        case .missingVenv:
                            HStack {
                                Text("Virtual environment not found")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                statusBadge(status: .warning, text: "Not Setup")
                            }

                            if isSettingUpPython {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(setupProgress)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    ProgressView()
                                }
                            } else {
                                Button("Setup Python Environment") {
                                    setupPythonEnvironment()
                                }
                                .buttonStyle(.borderedProminent)
                            }

                        case .missingPackages(let packages):
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Missing packages")
                                        .font(.subheadline)
                                    Spacer()
                                    statusBadge(status: .warning, text: "Incomplete")
                                }

                                Text(packages.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if isSettingUpPython {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(setupProgress)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        ProgressView()
                                    }
                                } else {
                                    Button("Install Missing Packages") {
                                        setupPythonEnvironment()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }

                        case .error(let message):
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Error")
                                    Spacer()
                                    statusBadge(status: .critical, text: "Error")
                                }
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                        default:
                            Text("Checking...")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("System Status")
        .onAppear {
            monitor.startMonitoring()
            checkPythonEnvironment()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
    }

    // MARK: - Helpers

    private func statusBadge(status: SystemMonitorService.HealthStatus, text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.2))
            .foregroundColor(statusColor(status))
            .cornerRadius(4)
    }

    private func statusColor(_ status: SystemMonitorService.HealthStatus) -> Color {
        switch status {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func progressColor(for percent: Double) -> Color {
        if percent > 90 { return .red }
        if percent > 75 { return .orange }
        return .blue
    }

    private func checkPythonEnvironment() {
        isCheckingPython = true
        Task {
            pythonStatus = await PythonEnvironmentManager.shared.checkStatus()
            if pythonStatus.isReady {
                pythonVersion = await PythonEnvironmentManager.shared.getPythonVersion()
            }
            isCheckingPython = false
        }
    }

    private func setupPythonEnvironment() {
        isSettingUpPython = true
        Task {
            do {
                try await PythonEnvironmentManager.shared.ensureReady { progress in
                    Task { @MainActor in
                        setupProgress = progress
                    }
                }
                pythonStatus = await PythonEnvironmentManager.shared.checkStatus()
                pythonVersion = await PythonEnvironmentManager.shared.getPythonVersion()
            } catch {
                pythonStatus = .error(error.localizedDescription)
            }
            isSettingUpPython = false
        }
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Compact Status Indicator

struct CompactSystemStatus: View {
    @ObservedObject private var monitor = SystemMonitorService.shared

    var body: some View {
        HStack(spacing: 12) {
            // GPU indicator
            HStack(spacing: 4) {
                Image(systemName: "gpu")
                    .foregroundColor(monitor.gpuInfo.isAvailable ? .green : .orange)
                if monitor.gpuInfo.isAvailable {
                    Text(String(format: "%.0f%%", monitor.gpuMemoryUsagePercent))
                        .font(.caption)
                }
            }

            // Memory indicator
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .foregroundColor(memoryColor)
                Text(String(format: "%.0f%%", monitor.memoryInfo.usagePercent))
                    .font(.caption)
            }

            // CPU indicator
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .foregroundColor(cpuColor)
                Text(String(format: "%.0f%%", monitor.cpuUsage))
                    .font(.caption)
            }
        }
        .onAppear {
            monitor.startMonitoring()
        }
    }

    private var memoryColor: Color {
        if monitor.memoryInfo.usagePercent > 90 { return .red }
        if monitor.memoryInfo.usagePercent > 75 { return .orange }
        return .green
    }

    private var cpuColor: Color {
        if monitor.cpuUsage > 90 { return .red }
        if monitor.cpuUsage > 75 { return .orange }
        return .green
    }
}

#Preview {
    SystemStatusView()
}
