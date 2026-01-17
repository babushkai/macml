import SwiftUI

struct DistillationView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedRunId: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text(L.distillation)
                .font(.largeTitle.bold())

            Text(L.distillationDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { appState.showNewDistillationSheet = true }) {
                Label(L.newDistillation, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !appState.distillationRuns.isEmpty {
                Divider()
                    .padding(.vertical)

                List(appState.distillationRuns, selection: $selectedRunId) { run in
                    DistillationRunRow(run: run)
                        .tag(run.id)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
                        Button(L.cancel) {
                            appState.cancelDistillation(runId: run.id)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Progress
                if run.status.isActive {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L.progress)
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
                    DistillationStatBox(title: L.samplesGenerated, value: "\(run.samplesGenerated)", icon: "doc.text")
                    DistillationStatBox(title: L.apiCalls, value: "\(run.apiCallsMade)", icon: "network")
                    DistillationStatBox(title: L.estimatedCost, value: String(format: "$%.2f", run.estimatedCost), icon: "dollarsign.circle")
                    if let studentAcc = run.studentAccuracy {
                        DistillationStatBox(title: L.studentAccuracy, value: String(format: "%.1f%%", studentAcc * 100), icon: "target")
                    }
                    if let compression = run.compressionRatio {
                        DistillationStatBox(title: L.compressionRatio, value: String(format: "%.1fx", compression), icon: "arrow.down.right.and.arrow.up.left")
                    }
                    DistillationStatBox(title: L.duration, value: run.duration, icon: "clock")
                }

                // Configuration
                GroupBox(L.configuration) {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(L.teacher, value: run.config.teacherType.rawValue)
                        if let provider = run.config.cloudProvider {
                            LabeledContent(L.provider, value: provider.rawValue)
                        }
                        LabeledContent(L.studentArchitecture, value: run.config.studentArchitecture.rawValue)
                        LabeledContent(L.epochs, value: "\(run.config.epochs)")
                    }
                }

                // Logs
                GroupBox(L.logs) {
                    if run.logs.isEmpty {
                        Text(L.noLogsYet)
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
