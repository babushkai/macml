import Foundation
import Combine

// MARK: - Background Task Manager

/// Manages background tasks with progress tracking and lifecycle handling
@MainActor
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()

    @Published var tasks: [BackgroundTaskInfo] = []
    @Published var isProcessingInBackground = false

    private var cancellables = Set<AnyCancellable>()
    private var taskCancellationTokens: [String: Bool] = [:]

    private init() {
        setupNotifications()
    }

    // MARK: - Task Info

    struct BackgroundTaskInfo: Identifiable {
        let id: String
        let name: String
        let type: TaskType
        var progress: Double
        var status: TaskStatus
        var statusMessage: String
        let startTime: Date
        var endTime: Date?
        var error: String?

        enum TaskType: String, Codable {
            case training = "Training"
            case export = "Export"
            case `import` = "Import"
            case dataProcessing = "Data Processing"
            case cleanup = "Cleanup"
            case inference = "Inference"

            var icon: String {
                switch self {
                case .training: return "brain"
                case .export: return "square.and.arrow.up"
                case .import: return "square.and.arrow.down"
                case .dataProcessing: return "gearshape.2"
                case .cleanup: return "trash"
                case .inference: return "wand.and.stars"
                }
            }
        }

        enum TaskStatus: String {
            case pending = "Pending"
            case running = "Running"
            case completed = "Completed"
            case failed = "Failed"
            case cancelled = "Cancelled"

            var color: String {
                switch self {
                case .pending: return "gray"
                case .running: return "blue"
                case .completed: return "green"
                case .failed: return "red"
                case .cancelled: return "orange"
                }
            }
        }

        var duration: TimeInterval {
            let end = endTime ?? Date()
            return end.timeIntervalSince(startTime)
        }

        var formattedDuration: String {
            let duration = self.duration
            if duration < 60 {
                return String(format: "%.1fs", duration)
            } else if duration < 3600 {
                return String(format: "%.1fm", duration / 60)
            } else {
                return String(format: "%.1fh", duration / 3600)
            }
        }
    }

    // MARK: - Task Management

    /// Start a new background task
    @discardableResult
    func startTask(
        name: String,
        type: BackgroundTaskInfo.TaskType,
        task: @escaping (BackgroundTaskHandle) async throws -> Void
    ) -> String {
        let taskId = UUID().uuidString
        let taskInfo = BackgroundTaskInfo(
            id: taskId,
            name: name,
            type: type,
            progress: 0,
            status: .running,
            statusMessage: "Starting...",
            startTime: Date()
        )

        tasks.append(taskInfo)
        taskCancellationTokens[taskId] = false
        isProcessingInBackground = true

        // Capture the cancellation check in an @MainActor closure to avoid data race
        // when isCancelled is called from non-main-actor contexts
        let handle = BackgroundTaskHandle(
            taskId: taskId,
            updateProgress: { [weak self] progress, message in
                await self?.updateTask(taskId, progress: progress, message: message)
            },
            isCancelled: { @MainActor [weak self] in
                self?.taskCancellationTokens[taskId] ?? true
            }
        )

        Task {
            do {
                try await task(handle)
                await completeTask(taskId, success: true)
            } catch {
                if error is CancellationError {
                    await completeTask(taskId, success: false, error: "Cancelled")
                } else {
                    await completeTask(taskId, success: false, error: error.localizedDescription)
                }
            }
        }

        return taskId
    }

    /// Update task progress
    func updateTask(_ id: String, progress: Double, message: String? = nil) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].progress = progress
            if let message = message {
                tasks[index].statusMessage = message
            }
        }
    }

    /// Complete a task
    func completeTask(_ id: String, success: Bool, error: String? = nil) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = success ? .completed : (error == "Cancelled" ? .cancelled : .failed)
            tasks[index].progress = success ? 1.0 : tasks[index].progress
            tasks[index].endTime = Date()
            tasks[index].error = error
            tasks[index].statusMessage = success ? "Completed" : (error ?? "Failed")
        }

        taskCancellationTokens.removeValue(forKey: id)
        updateBackgroundProcessingState()
    }

    /// Cancel a running task
    func cancelTask(_ id: String) {
        taskCancellationTokens[id] = true
    }

    /// Remove a completed/failed task from the list
    func removeTask(_ id: String) {
        tasks.removeAll { $0.id == id }
        taskCancellationTokens.removeValue(forKey: id)
    }

    /// Clear all completed tasks
    func clearCompletedTasks() {
        tasks.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
    }

    // MARK: - Queries

    var activeTasks: [BackgroundTaskInfo] {
        tasks.filter { $0.status == .running || $0.status == .pending }
    }

    var completedTasks: [BackgroundTaskInfo] {
        tasks.filter { $0.status == .completed }
    }

    var failedTasks: [BackgroundTaskInfo] {
        tasks.filter { $0.status == .failed }
    }

    func getTask(_ id: String) -> BackgroundTaskInfo? {
        tasks.first { $0.id == id }
    }

    // MARK: - Private Helpers

    private func updateBackgroundProcessingState() {
        isProcessingInBackground = !activeTasks.isEmpty
    }

    // MARK: - App Lifecycle

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
            .store(in: &cancellables)
    }

    func handleAppWillTerminate() {
        // Save state of running tasks for recovery
        let runningTasks = tasks.filter { $0.status == .running }
        if !runningTasks.isEmpty {
            let taskData = runningTasks.map { TaskPersistence(id: $0.id, name: $0.name, type: $0.type.rawValue) }
            if let encoded = try? JSONEncoder().encode(taskData) {
                UserDefaults.standard.set(encoded, forKey: "pendingBackgroundTasks")
            }
        }
    }

    func handleAppDidLaunch() {
        // Check for tasks that were interrupted
        if let data = UserDefaults.standard.data(forKey: "pendingBackgroundTasks"),
           let taskData = try? JSONDecoder().decode([TaskPersistence].self, from: data),
           !taskData.isEmpty {
            // Add interrupted tasks to list as failed
            for task in taskData {
                let taskInfo = BackgroundTaskInfo(
                    id: task.id,
                    name: task.name,
                    type: BackgroundTaskInfo.TaskType(rawValue: task.type) ?? .dataProcessing,
                    progress: 0,
                    status: .failed,
                    statusMessage: "Interrupted by app termination",
                    startTime: Date(),
                    endTime: Date(),
                    error: "Task was interrupted when the application closed"
                )
                tasks.append(taskInfo)
            }

            // Notify about interrupted tasks
            NotificationCenter.default.post(
                name: .backgroundTasksInterrupted,
                object: nil,
                userInfo: ["count": taskData.count]
            )

            UserDefaults.standard.removeObject(forKey: "pendingBackgroundTasks")
        }
    }

    private struct TaskPersistence: Codable {
        let id: String
        let name: String
        let type: String
    }
}

// MARK: - Background Task Handle

/// Handle for updating task progress from within the task
struct BackgroundTaskHandle: Sendable {
    let taskId: String
    let updateProgress: @Sendable (Double, String?) async -> Void
    let isCancelled: @MainActor @Sendable () -> Bool

    func update(progress: Double, message: String? = nil) async {
        await updateProgress(progress, message)
    }

    @MainActor
    func checkCancellation() throws {
        if isCancelled() {
            throw CancellationError()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let backgroundTasksInterrupted = Notification.Name("backgroundTasksInterrupted")
    static let backgroundTaskCompleted = Notification.Name("backgroundTaskCompleted")
}

// MARK: - Background Tasks View

import SwiftUI

struct BackgroundTasksView: View {
    @ObservedObject var taskManager = BackgroundTaskManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Background Tasks")
                    .font(.headline)

                Spacer()

                if !taskManager.completedTasks.isEmpty {
                    Button("Clear Completed") {
                        taskManager.clearCompletedTasks()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding()

            Divider()

            if taskManager.tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No background tasks")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(taskManager.tasks) { task in
                        BackgroundTaskRow(task: task) {
                            taskManager.cancelTask(task.id)
                        } onRemove: {
                            taskManager.removeTask(task.id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct BackgroundTaskRow: View {
    let task: BackgroundTaskManager.BackgroundTaskInfo
    let onCancel: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: task.type.icon)
                .font(.title3)
                .foregroundColor(statusColor)
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.name)
                        .fontWeight(.medium)

                    Spacer()

                    Text(task.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if task.status == .running {
                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                }

                HStack {
                    Text(task.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if task.status == .running {
                        Spacer()
                        Text("\(Int(task.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = task.error, task.status == .failed {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }

            // Actions
            if task.status == .running {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel task")
            } else {
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from list")
            }
        }
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch task.status {
        case .pending: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

// MARK: - Background Tasks Popover Button

struct BackgroundTasksButton: View {
    @ObservedObject var taskManager = BackgroundTaskManager.shared
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                if #available(macOS 15.0, *) {
                    Image(systemName: taskManager.isProcessingInBackground ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                        .symbolEffect(.rotate, isActive: taskManager.isProcessingInBackground)
                } else {
                    Image(systemName: taskManager.isProcessingInBackground ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                }

                if !taskManager.activeTasks.isEmpty {
                    Text("\(taskManager.activeTasks.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showPopover) {
            BackgroundTasksView()
                .frame(width: 350, height: 300)
        }
    }
}
