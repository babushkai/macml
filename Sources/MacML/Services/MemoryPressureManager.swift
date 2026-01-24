import Foundation
import Combine

// MARK: - Memory Pressure Manager

/// Monitors system memory pressure and adjusts training accordingly
@MainActor
class MemoryPressureManager: ObservableObject {
    static let shared = MemoryPressureManager()

    @Published var currentPressureLevel: MemoryPressureLevel = .normal
    @Published var memoryUsage: MemoryUsage = MemoryUsage()
    @Published var recommendations: [MemoryRecommendation] = []

    // Using nonisolated(unsafe) for these properties allows safe access from deinit.
    // This is safe because:
    // 1. Task.cancel() and DispatchSource.cancel() are thread-safe operations
    // 2. deinit is called only when no other references exist (single writer)
    // 3. These properties are only modified during init (on MainActor) and read in deinit
    private nonisolated(unsafe) var monitoringTask: Task<Void, Never>?
    private nonisolated(unsafe) var dispatchSource: DispatchSourceMemoryPressure?
    private var cancellables = Set<AnyCancellable>()

    // Thresholds
    private let warningThreshold: Double = 0.7   // 70% memory usage
    private let criticalThreshold: Double = 0.85 // 85% memory usage

    private init() {
        setupMemoryPressureMonitoring()
        startPeriodicMonitoring()
    }

    deinit {
        // Safe to call from deinit because cancel() is thread-safe and
        // the properties are marked nonisolated(unsafe)
        monitoringTask?.cancel()
        dispatchSource?.cancel()
    }

    // MARK: - Types

    enum MemoryPressureLevel: String, CaseIterable {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"

        var color: String {
            switch self {
            case .normal: return "green"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }

        var icon: String {
            switch self {
            case .normal: return "memorychip"
            case .warning: return "exclamationmark.triangle"
            case .critical: return "exclamationmark.octagon.fill"
            }
        }
    }

    struct MemoryUsage {
        var totalPhysicalMemory: UInt64 = 0
        var usedMemory: UInt64 = 0
        var freeMemory: UInt64 = 0
        var appMemory: UInt64 = 0
        var gpuMemory: UInt64 = 0
        var timestamp: Date = Date()

        var usagePercentage: Double {
            guard totalPhysicalMemory > 0 else { return 0 }
            return Double(usedMemory) / Double(totalPhysicalMemory)
        }

        var formattedTotal: String {
            ByteCountFormatter.string(fromByteCount: Int64(totalPhysicalMemory), countStyle: .memory)
        }

        var formattedUsed: String {
            ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory)
        }

        var formattedFree: String {
            ByteCountFormatter.string(fromByteCount: Int64(freeMemory), countStyle: .memory)
        }

        var formattedApp: String {
            ByteCountFormatter.string(fromByteCount: Int64(appMemory), countStyle: .memory)
        }
    }

    struct MemoryRecommendation: Identifiable {
        let id = UUID()
        let type: RecommendationType
        let message: String
        let action: (() -> Void)?

        enum RecommendationType {
            case reduceBatchSize
            case pauseTraining
            case clearCache
            case closeUnusedModels
            case info
        }
    }

    // MARK: - Monitoring Setup

    private func setupMemoryPressureMonitoring() {
        // Use dispatch source for system memory pressure notifications
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = source.data

            Task { @MainActor in
                if event.contains(.critical) {
                    self.handleCriticalPressure()
                } else if event.contains(.warning) {
                    self.handleWarningPressure()
                }
            }
        }

        source.resume()
        dispatchSource = source
    }

    private func startPeriodicMonitoring() {
        monitoringTask = Task {
            while !Task.isCancelled {
                await updateMemoryUsage()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    // MARK: - Memory Usage Updates

    func updateMemoryUsage() async {
        let usage = getSystemMemoryInfo()
        memoryUsage = usage

        // Determine pressure level
        let newLevel: MemoryPressureLevel
        if usage.usagePercentage >= criticalThreshold {
            newLevel = .critical
        } else if usage.usagePercentage >= warningThreshold {
            newLevel = .warning
        } else {
            newLevel = .normal
        }

        if newLevel != currentPressureLevel {
            currentPressureLevel = newLevel
            updateRecommendations()
        }
    }

    private func getSystemMemoryInfo() -> MemoryUsage {
        var usage = MemoryUsage()
        usage.timestamp = Date()

        // Get total physical memory
        var size = MemoryLayout<UInt64>.size
        var physicalMemory: UInt64 = 0
        sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0)
        usage.totalPhysicalMemory = physicalMemory

        // Get memory stats using host_statistics64
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_page_size)

            let wiredMemory = UInt64(stats.wire_count) * pageSize
            let activeMemory = UInt64(stats.active_count) * pageSize
            let inactiveMemory = UInt64(stats.inactive_count) * pageSize
            let freeMemory = UInt64(stats.free_count) * pageSize
            let compressedMemory = UInt64(stats.compressor_page_count) * pageSize

            usage.usedMemory = wiredMemory + activeMemory + inactiveMemory + compressedMemory
            usage.freeMemory = freeMemory
        }

        // Get app memory usage
        var info = mach_task_basic_info()
        var infoCount = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)

        let taskResult = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &infoCount)
            }
        }

        if taskResult == KERN_SUCCESS {
            usage.appMemory = UInt64(info.resident_size)
        }

        return usage
    }

    // MARK: - Pressure Handling

    private func handleWarningPressure() {
        currentPressureLevel = .warning
        updateRecommendations()

        // Notify active training services
        NotificationCenter.default.post(
            name: .memoryPressureWarning,
            object: nil,
            userInfo: ["level": MemoryPressureLevel.warning]
        )
    }

    private func handleCriticalPressure() {
        currentPressureLevel = .critical
        updateRecommendations()

        // Notify active training services
        NotificationCenter.default.post(
            name: .memoryPressureCritical,
            object: nil,
            userInfo: ["level": MemoryPressureLevel.critical]
        )

        // Auto-cleanup cached data
        performEmergencyCleanup()
    }

    private func updateRecommendations() {
        var newRecommendations: [MemoryRecommendation] = []

        switch currentPressureLevel {
        case .critical:
            newRecommendations.append(MemoryRecommendation(
                type: .pauseTraining,
                message: "Consider pausing training to free memory",
                action: nil
            ))
            newRecommendations.append(MemoryRecommendation(
                type: .reduceBatchSize,
                message: "Reduce batch size to lower memory usage",
                action: nil
            ))
            newRecommendations.append(MemoryRecommendation(
                type: .clearCache,
                message: "Clear model caches and temporary files",
                action: { [weak self] in
                    self?.performEmergencyCleanup()
                }
            ))

        case .warning:
            newRecommendations.append(MemoryRecommendation(
                type: .reduceBatchSize,
                message: "Consider reducing batch size",
                action: nil
            ))
            newRecommendations.append(MemoryRecommendation(
                type: .closeUnusedModels,
                message: "Close unused models to free memory",
                action: nil
            ))

        case .normal:
            newRecommendations.append(MemoryRecommendation(
                type: .info,
                message: "Memory usage is within normal limits",
                action: nil
            ))
        }

        recommendations = newRecommendations
    }

    // MARK: - Cleanup Actions

    func performEmergencyCleanup() {
        // Clear any caches
        URLCache.shared.removeAllCachedResponses()

        // Trigger garbage collection for Swift
        autoreleasepool { }

        // Post notification for other components to clean up
        NotificationCenter.default.post(name: .performMemoryCleanup, object: nil)
    }

    func clearModelCache() {
        // Clear temporary model files
        let tempDir = FileManager.default.temporaryDirectory
        try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mlmodel" || $0.pathExtension == "safetensors" }
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }

    // MARK: - Training Adjustments

    /// Calculate recommended batch size based on current memory pressure
    func recommendedBatchSize(for currentBatchSize: Int) -> Int {
        switch currentPressureLevel {
        case .critical:
            return max(1, currentBatchSize / 4)
        case .warning:
            return max(1, currentBatchSize / 2)
        case .normal:
            return currentBatchSize
        }
    }

    /// Check if training should be paused due to memory pressure
    func shouldPauseTraining() -> Bool {
        return currentPressureLevel == .critical
    }

    /// Check if it's safe to start a new training run
    func canStartNewTraining() -> Bool {
        return currentPressureLevel != .critical && memoryUsage.usagePercentage < 0.8
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let memoryPressureWarning = Notification.Name("memoryPressureWarning")
    static let memoryPressureCritical = Notification.Name("memoryPressureCritical")
    static let performMemoryCleanup = Notification.Name("performMemoryCleanup")
}

// MARK: - Memory Monitor View

import SwiftUI

struct MemoryMonitorView: View {
    @ObservedObject var memoryManager = MemoryPressureManager.shared
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: memoryManager.currentPressureLevel.icon)
                    .foregroundColor(pressureColor)
                Text("Memory: \(memoryManager.currentPressureLevel.rawValue)")
                    .fontWeight(.medium)
                Spacer()
                Button {
                    showDetails.toggle()
                } label: {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(pressureColor)
                        .frame(width: geo.size.width * memoryManager.memoryUsage.usagePercentage)
                }
            }
            .frame(height: 8)

            // Usage text
            HStack {
                Text("Used: \(memoryManager.memoryUsage.formattedUsed)")
                Spacer()
                Text("Free: \(memoryManager.memoryUsage.formattedFree)")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Details
            if showDetails {
                VStack(spacing: 8) {
                    Divider()

                    HStack {
                        Text("Total Memory")
                        Spacer()
                        Text(memoryManager.memoryUsage.formattedTotal)
                    }

                    HStack {
                        Text("App Memory")
                        Spacer()
                        Text(memoryManager.memoryUsage.formattedApp)
                    }

                    HStack {
                        Text("Usage")
                        Spacer()
                        Text(String(format: "%.1f%%", memoryManager.memoryUsage.usagePercentage * 100))
                    }

                    // Recommendations
                    if !memoryManager.recommendations.isEmpty {
                        Divider()

                        ForEach(memoryManager.recommendations) { rec in
                            HStack {
                                Image(systemName: recommendationIcon(rec.type))
                                    .foregroundColor(recommendationColor(rec.type))
                                Text(rec.message)
                                    .font(.caption)
                                Spacer()
                                if rec.action != nil {
                                    Button("Fix") {
                                        rec.action?()
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                }
                            }
                        }
                    }

                    // Actions
                    Button("Clear Caches") {
                        memoryManager.performEmergencyCleanup()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var pressureColor: Color {
        switch memoryManager.currentPressureLevel {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func recommendationIcon(_ type: MemoryPressureManager.MemoryRecommendation.RecommendationType) -> String {
        switch type {
        case .reduceBatchSize: return "slider.horizontal.3"
        case .pauseTraining: return "pause.circle"
        case .clearCache: return "trash"
        case .closeUnusedModels: return "xmark.circle"
        case .info: return "info.circle"
        }
    }

    private func recommendationColor(_ type: MemoryPressureManager.MemoryRecommendation.RecommendationType) -> Color {
        switch type {
        case .reduceBatchSize, .closeUnusedModels: return .orange
        case .pauseTraining, .clearCache: return .red
        case .info: return .blue
        }
    }
}

// MARK: - Compact Memory Indicator

struct MemoryIndicatorButton: View {
    @ObservedObject var memoryManager = MemoryPressureManager.shared
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: memoryManager.currentPressureLevel.icon)
                    .foregroundColor(pressureColor)

                Text(String(format: "%.0f%%", memoryManager.memoryUsage.usagePercentage * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            MemoryMonitorView()
                .frame(width: 280)
        }
    }

    private var pressureColor: Color {
        switch memoryManager.currentPressureLevel {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
