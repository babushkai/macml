import SwiftUI

struct DistillationView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedRunId: String?

    var body: some View {
        HSplitView {
            // Run list
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Distillation Runs")
                        .font(.headline)
                    Spacer()
                    Button(action: { appState.showNewDistillationSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
                .padding()

                Divider()

                if appState.distillationRuns.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No Distillation Runs")
                            .font(.headline)
                        Text("Create a new distillation to train a small local model from a cloud LLM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("New Distillation") {
                            appState.showNewDistillationSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List(appState.distillationRuns, selection: $selectedRunId) { run in
                        DistillationRunRow(run: run)
                            .tag(run.id)
                    }
                }
            }
            .frame(minWidth: 250, maxWidth: 350)

            // Detail view
            if let runId = selectedRunId,
               let run = appState.distillationRuns.first(where: { $0.id == runId }) {
                DistillationDetailView(run: run)
            } else {
                VStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select a distillation run")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Run Row

struct DistillationRunRow: View {
    let run: DistillationRun
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: run.status.icon)
                        .foregroundColor(run.status.color)
                    Text(run.name)
                        .fontWeight(.medium)
                }
                Text(run.phase)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if run.status.isActive {
                    ProgressView(value: run.progress)
                        .progressViewStyle(.linear)
                }
            }
            Spacer()
            if run.status.isActive {
                Button(action: { appState.cancelDistillation(runId: run.id) }) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail View

struct DistillationDetailView: View {
    let run: DistillationRun
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(run.name)
                            .font(.title.bold())
                        HStack {
                            Image(systemName: run.status.icon)
                                .foregroundColor(run.status.color)
                            Text(run.status.rawValue)
                                .foregroundColor(run.status.color)
                            Text("- \(run.phase)")
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if run.status.isActive {
                        Button("Cancel") {
                            appState.cancelDistillation(runId: run.id)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Progress
                if run.status.isActive {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(run.progress * 100))%")
                        }
                        ProgressView(value: run.progress)
                            .progressViewStyle(.linear)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    DistillationStatBox(title: "Samples Generated", value: "\(run.samplesGenerated)", icon: "doc.text")
                    DistillationStatBox(title: "API Calls", value: "\(run.apiCallsMade)", icon: "network")
                    DistillationStatBox(title: "Est. Cost", value: String(format: "$%.2f", run.estimatedCost), icon: "dollarsign.circle")
                    if let studentAcc = run.studentAccuracy {
                        DistillationStatBox(title: "Student Accuracy", value: String(format: "%.1f%%", studentAcc * 100), icon: "target")
                    }
                    if let compression = run.compressionRatio {
                        DistillationStatBox(title: "Compression", value: String(format: "%.1fx", compression), icon: "arrow.down.right.and.arrow.up.left")
                    }
                    DistillationStatBox(title: "Duration", value: run.duration, icon: "clock")
                }

                // Configuration
                GroupBox("Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Teacher", value: run.config.teacherType.rawValue)
                        if let provider = run.config.cloudProvider {
                            LabeledContent("Provider", value: provider.rawValue)
                        }
                        LabeledContent("Student Architecture", value: run.config.studentArchitecture.rawValue)
                        LabeledContent("Epochs", value: "\(run.config.epochs)")
                    }
                }

                // Logs
                GroupBox("Logs") {
                    if run.logs.isEmpty {
                        Text("No logs yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(run.logs.suffix(50)) { entry in
                                    HStack(alignment: .top) {
                                        Text(entry.level.prefix)
                                            .font(.caption.monospaced())
                                            .foregroundColor(entry.level.color)
                                            .frame(width: 50, alignment: .leading)
                                        Text(entry.message)
                                            .font(.caption.monospaced())
                                    }
                                }
                            }
                            .padding(8)
                        }
                        .frame(height: 200)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
            }
            .padding()
        }
    }
}

struct DistillationStatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
