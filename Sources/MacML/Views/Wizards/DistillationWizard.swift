import SwiftUI

struct DistillationWizard: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var currentStep = 0
    @State private var config = DistillationConfig.default
    @State private var runName = ""

    private let steps = ["Task", "Teacher", "Student", "Review"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Distillation")
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Step indicator
            HStack(spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { index in
                    StepIndicator(
                        number: index + 1,
                        title: steps[index],
                        isActive: index == currentStep,
                        isCompleted: index < currentStep
                    )
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch currentStep {
                    case 0:
                        TaskStepView(config: $config, runName: $runName)
                    case 1:
                        TeacherStepView(config: $config)
                    case 2:
                        StudentStepView(config: $config)
                    case 3:
                        ReviewStepView(config: config, runName: runName)
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }

            Divider()

            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                } else {
                    Button("Start Distillation") {
                        startDistillation()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 550)
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return !runName.isEmpty && !config.taskDescription.isEmpty
        case 1:
            return config.teacherType == .localModel || config.cloudProvider != nil
        case 2:
            return true
        case 3:
            return true
        default:
            return false
        }
    }

    private func startDistillation() {
        let run = DistillationRun(name: runName, config: config)
        appState.startDistillation(run: run)
        dismiss()
    }
}

// MARK: - Step Views

struct TaskStepView: View {
    @Binding var config: DistillationConfig
    @Binding var runName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Define Your Task")
                .font(.headline)

            Text("Describe what you want the student model to learn from the teacher.")
                .foregroundColor(.secondary)

            TextField("Run Name", text: $runName)
                .textFieldStyle(.roundedBorder)

            Text("Task Description")
                .font(.subheadline.bold())

            TextEditor(text: $config.taskDescription)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )

            Text("Example: \"Classify customer support tickets into categories: billing, technical, general inquiry\"")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TeacherStepView: View {
    @Binding var config: DistillationConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Teacher Model")
                .font(.headline)

            Text("Choose the model that will generate training data for your student.")
                .foregroundColor(.secondary)

            // Teacher type selection
            ForEach(TeacherType.allCases, id: \.self) { type in
                Button(action: { config.teacherType = type }) {
                    HStack {
                        Image(systemName: type.icon)
                            .frame(width: 30)
                        VStack(alignment: .leading) {
                            Text(type.rawValue)
                                .fontWeight(.medium)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if config.teacherType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                    .background(config.teacherType == type ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            if config.teacherType == .cloudLLM {
                Divider()

                Text("Cloud Provider")
                    .font(.subheadline.bold())

                HStack(spacing: 12) {
                    ForEach(CloudProvider.allCases, id: \.self) { provider in
                        Button(action: {
                            config.cloudProvider = provider
                            config.teacherModelId = provider.models.first
                        }) {
                            VStack {
                                Image(systemName: provider.icon)
                                    .font(.title2)
                                Text(provider.rawValue)
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 60)
                            .background(config.cloudProvider == provider ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(config.cloudProvider == provider ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let provider = config.cloudProvider {
                    Picker("Model", selection: $config.teacherModelId) {
                        ForEach(provider.models, id: \.self) { model in
                            Text(model).tag(Optional(model))
                        }
                    }
                }
            }
        }
    }
}

struct StudentStepView: View {
    @Binding var config: DistillationConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configure Student Model")
                .font(.headline)

            Text("Choose the architecture and hyperparameters for your local student model.")
                .foregroundColor(.secondary)

            // Architecture selection
            Text("Architecture")
                .font(.subheadline.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(StudentArchitecture.allCases, id: \.self) { arch in
                    Button(action: { config.studentArchitecture = arch }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: arch.icon)
                                Spacer()
                                Text(arch.parameterCount)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            Text(arch.rawValue)
                                .fontWeight(.medium)
                            Text(arch.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(config.studentArchitecture == arch ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(config.studentArchitecture == arch ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Hyperparameters
            Text("Training Parameters")
                .font(.subheadline.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Synthetic Samples")
                        .font(.caption)
                    TextField("Samples", value: $config.syntheticSamples, format: .number)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Epochs")
                        .font(.caption)
                    TextField("Epochs", value: $config.epochs, format: .number)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Batch Size")
                        .font(.caption)
                    TextField("Batch Size", value: $config.batchSize, format: .number)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Learning Rate")
                        .font(.caption)
                    TextField("LR", value: $config.learningRate, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Temperature: \(String(format: "%.1f", config.temperature))")
                        .font(.caption)
                    Slider(value: $config.temperature, in: 0.1...5.0, step: 0.1)
                }

                VStack(alignment: .leading) {
                    Text("Distillation Alpha: \(String(format: "%.2f", config.alpha))")
                        .font(.caption)
                    Slider(value: $config.alpha, in: 0...1, step: 0.05)
                }
            }
        }
    }
}

struct ReviewStepView: View {
    let config: DistillationConfig
    let runName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Configuration")
                .font(.headline)

            Text("Please review your distillation settings before starting.")
                .foregroundColor(.secondary)

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Run Name", value: runName)
                    LabeledContent("Task", value: config.taskDescription.prefix(50) + (config.taskDescription.count > 50 ? "..." : ""))
                }
            }

            GroupBox("Teacher Model") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Type", value: config.teacherType.rawValue)
                    if let provider = config.cloudProvider {
                        LabeledContent("Provider", value: provider.rawValue)
                    }
                    if let modelId = config.teacherModelId {
                        LabeledContent("Model", value: modelId)
                    }
                }
            }

            GroupBox("Student Model") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Architecture", value: config.studentArchitecture.rawValue)
                    LabeledContent("Parameters", value: config.studentArchitecture.parameterCount)
                    LabeledContent("Synthetic Samples", value: "\(config.syntheticSamples)")
                    LabeledContent("Epochs", value: "\(config.epochs)")
                    LabeledContent("Batch Size", value: "\(config.batchSize)")
                    LabeledContent("Learning Rate", value: String(format: "%.4f", config.learningRate))
                    LabeledContent("Temperature", value: String(format: "%.1f", config.temperature))
                    LabeledContent("Alpha", value: String(format: "%.2f", config.alpha))
                }
            }

            // Estimated cost
            if config.teacherType == .cloudLLM {
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .foregroundColor(.orange)
                    Text("Estimated API Cost: ")
                    Text(String(format: "$%.2f - $%.2f", Double(config.syntheticSamples) * 0.001, Double(config.syntheticSamples) * 0.005))
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
