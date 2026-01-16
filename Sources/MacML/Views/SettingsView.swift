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
            return (false, L.learningRateMustBePositive)
        } else if lr > 1.0 {
            return (false, L.learningRateTooHigh)
        } else if lr < 0.00001 {
            return (false, L.learningRateVeryLow)
        } else if lr > 0.1 {
            return (false, L.learningRateQuiteHigh)
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
                    Text(L.settings)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(L.configurePreferences)
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            }
            .padding()
            .background(AppTheme.background)

            Form {
            // General Settings
            Section(L.general) {
                Toggle(L.autoSaveCheckpoints, isOn: $appState.settings.autoSaveCheckpoints)
                Toggle(L.showNotifications, isOn: $appState.settings.showNotifications)
                Toggle(L.cacheModels, isOn: $appState.settings.cacheModels)
            }

            // Training Settings
            Section(L.trainingDefaults) {
                Stepper("\(L.defaultEpochs): \(appState.settings.defaultEpochs)",
                       value: $appState.settings.defaultEpochs, in: 1...1000)

                Stepper("\(L.defaultBatchSize): \(appState.settings.defaultBatchSize)",
                       value: $appState.settings.defaultBatchSize, in: 1...512)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(L.defaultLearningRate):")
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
                        Text(L.mlxBackend)
                            .fontWeight(.medium)
                        Text(L.appleSiliconOptimized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(L.active)
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                }

                HStack {
                    Image(systemName: "memorychip")
                        .foregroundColor(.blue)
                    Text(L.gpuAcceleration)
                    Spacer()
                    Text(L.metal)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                    Text(L.automaticDifferentiation)
                    Spacer()
                    Text(L.enabled)
                        .foregroundColor(.secondary)
                }

                Text(L.mlxDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                HStack {
                    Text(L.mlTrainingBackend)
                    Spacer()
                    Image(systemName: "sparkle")
                        .foregroundColor(.purple)
                }
            }

            // Storage
            Section(L.storage) {
                if let stats = storageStats {
                    HStack {
                        Text(L.totalSize)
                        Spacer()
                        Text(formatBytes(stats.totalSize))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(L.models)
                        Spacer()
                        Text(formatBytes(stats.modelsSize))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(L.datasets)
                        Spacer()
                        Text(formatBytes(stats.datasetsSize))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(L.cache)
                        Spacer()
                        Text(formatBytes(stats.cacheSize))
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Text(L.loadingStorageInfo)
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                HStack {
                    Button(L.openDataFolder) {
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
                            Text(L.clearCache)
                        }
                    }
                    .disabled(isClearing || (storageStats?.cacheSize ?? 0) == 0)
                    .help((storageStats?.cacheSize ?? 0) == 0 ? L.cacheEmpty : L.clearCache)
                }
            }

            // About
            Section(L.about) {
                HStack {
                    Text(L.version)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(L.build)
                    Spacer()
                    Text("2024.1")
                        .foregroundColor(.secondary)
                }
            }

            // Demo Data
            Section(L.demoSampleData) {
                Button(action: {
                    Task { await appState.loadDemoData() }
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(L.loadDemoData)
                    }
                }

                Text(L.loadDemoDataDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Danger Zone
            Section {
                Button(role: .destructive, action: {
                    showResetSettingsConfirmation = true
                }) {
                    Text(L.resetSettings)
                }

                Button(role: .destructive, action: {
                    showClearAllDataConfirmation = true
                }) {
                    Text(L.clearAllData)
                }
            } header: {
                Text(L.dangerZone)
            } footer: {
                Text(L.cannotBeUndone)
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
        .alert(L.clearCache, isPresented: $showClearCacheConfirmation) {
            Button(L.cancel, role: .cancel) {}
            Button(L.clearCache, role: .destructive) {
                isClearing = true
                Task {
                    await appState.clearCache()
                    storageStats = await appState.getStorageStats()
                    isClearing = false
                }
            }
        } message: {
            Text(L.confirmClearCache())
        }
        .alert(L.resetSettings, isPresented: $showResetSettingsConfirmation) {
            Button(L.cancel, role: .cancel) {}
            Button(L.resetSettings, role: .destructive) {
                appState.settings = .default
                Task { await appState.saveData() }
                appState.showSuccess(L.settingsReset)
            }
        } message: {
            Text(L.confirmResetSettings())
        }
        .alert(L.clearAllData, isPresented: $showClearAllDataConfirmation) {
            Button(L.cancel, role: .cancel) {}
            Button(L.clearAllData, role: .destructive) {
                Task { await appState.clearAllData() }
            }
        } message: {
            Text(L.confirmClearAllData())
        }
        }
        .background(AppTheme.background)
    }
}
