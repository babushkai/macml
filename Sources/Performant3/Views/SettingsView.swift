import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var storageStats: StorageStats?
    @State private var isClearing = false
    @State private var showClearCacheConfirmation = false
    @State private var showResetSettingsConfirmation = false
    @State private var showClearAllDataConfirmation = false

    var learningRateValidation: (isValid: Bool, message: String) {
        let lr = appState.settings.defaultLearningRate
        if lr <= 0 {
            return (false, "Learning rate must be positive")
        } else if lr > 1.0 {
            return (false, "Learning rate should not exceed 1.0")
        } else if lr < 0.00001 {
            return (false, "Learning rate is very low (< 0.00001)")
        } else if lr > 0.1 {
            return (false, "Learning rate is quite high (> 0.1)")
        }
        return (true, "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.surface)
                        .frame(width: 44, height: 44)
                    Image(systemName: "gear")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Configure training defaults and preferences")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            }
            .padding()
            .background(AppTheme.background)

            Form {
            // General Settings
            Section("General") {
                Toggle("Auto-save training checkpoints", isOn: $appState.settings.autoSaveCheckpoints)
                Toggle("Show notifications for completed runs", isOn: $appState.settings.showNotifications)
                Toggle("Keep models in memory for faster inference", isOn: $appState.settings.cacheModels)
            }

            // Training Settings
            Section("Training Defaults") {
                Stepper("Default epochs: \(appState.settings.defaultEpochs)",
                       value: $appState.settings.defaultEpochs, in: 1...1000)

                Stepper("Default batch size: \(appState.settings.defaultBatchSize)",
                       value: $appState.settings.defaultBatchSize, in: 1...512)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Default learning rate:")
                        Spacer()
                        TextField("", value: $appState.settings.defaultLearningRate, format: .number)
                            .frame(width: 100)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(learningRateValidation.isValid ? .primary : .orange)
                    }
                    if !learningRateValidation.isValid {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(learningRateValidation.message)
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }

            // MLX Training Backend
            Section {
                HStack {
                    Image(systemName: "cpu.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("MLX Backend")
                            .fontWeight(.medium)
                        Text("Apple Silicon Optimized")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Active")
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                }

                HStack {
                    Image(systemName: "memorychip")
                        .foregroundColor(.blue)
                    Text("GPU Acceleration")
                    Spacer()
                    Text("Metal")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                    Text("Automatic Differentiation")
                    Spacer()
                    Text("Enabled")
                        .foregroundColor(.secondary)
                }

                Text("Training uses Apple's MLX framework with native Metal GPU acceleration. All gradients are computed using automatic differentiation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                HStack {
                    Text("ML Training Backend")
                    Spacer()
                    Image(systemName: "sparkle")
                        .foregroundColor(.purple)
                }
            }

            // Storage
            Section("Storage") {
                if let stats = storageStats {
                    HStack {
                        Text("Total Size")
                        Spacer()
                        Text(formatBytes(stats.totalSize))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Models")
                        Spacer()
                        Text(formatBytes(stats.modelsSize))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Datasets")
                        Spacer()
                        Text(formatBytes(stats.datasetsSize))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Cache")
                        Spacer()
                        Text(formatBytes(stats.cacheSize))
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Text("Loading storage info...")
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                HStack {
                    Button("Open Data Folder") {
                        Task { await appState.openDataFolder() }
                    }

                    Spacer()

                    Button(role: .destructive, action: {
                        showClearCacheConfirmation = true
                    }) {
                        if isClearing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Clear Cache")
                        }
                    }
                    .disabled(isClearing || (storageStats?.cacheSize ?? 0) == 0)
                    .help((storageStats?.cacheSize ?? 0) == 0 ? "Cache is empty" : "Clear temporary files and cached data")
                }
            }

            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text("2024.1")
                        .foregroundColor(.secondary)
                }
            }

            // Demo Data
            Section("Demo & Sample Data") {
                Button(action: {
                    Task { await appState.loadDemoData() }
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Load Demo Data")
                    }
                }

                Text("Loads sample models, datasets, training runs, and inference results to explore the app features.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Danger Zone
            Section {
                Button(role: .destructive, action: {
                    showResetSettingsConfirmation = true
                }) {
                    Text("Reset Settings to Defaults")
                }

                Button(role: .destructive, action: {
                    showClearAllDataConfirmation = true
                }) {
                    Text("Clear All Data")
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("These actions cannot be undone.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 400)
        .task {
            storageStats = await appState.getStorageStats()
        }
        .onChange(of: appState.settings) { _, _ in
            Task { await appState.saveData() }
        }
        .alert("Clear Cache", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Cache", role: .destructive) {
                isClearing = true
                Task {
                    await appState.clearCache()
                    storageStats = await appState.getStorageStats()
                    isClearing = false
                }
            }
        } message: {
            Text("This will remove all cached data including temporary files. Models and datasets will not be affected.")
        }
        .alert("Reset Settings", isPresented: $showResetSettingsConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                appState.settings = .default
                Task { await appState.saveData() }
                appState.showSuccess("Settings reset to defaults")
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
        .alert("Clear All Data", isPresented: $showClearAllDataConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                Task { await appState.clearAllData() }
            }
        } message: {
            Text("This will permanently delete all models, datasets, training runs, and settings. This action cannot be undone.")
        }
        }
        .background(AppTheme.background)
    }
}
