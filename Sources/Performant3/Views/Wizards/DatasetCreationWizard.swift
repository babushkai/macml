import SwiftUI

// MARK: - Dataset Creation Wizard

struct DatasetCreationWizard: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var currentStep = 0
    @State private var datasetName = ""
    @State private var datasetDescription = ""
    @State private var selectedType: DatasetType = .images
    @State private var selectedPath: String?
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var classes: [String] = []
    @State private var newClass = ""
    @State private var isCreating = false

    private let steps = ["Basic Info", "Data Type", "Source", "Review"]

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress
            WizardHeader(
                title: "Create New Dataset",
                steps: steps,
                currentStep: currentStep,
                onCancel: { dismiss() }
            )

            Divider()

            // Step content
            ScrollView {
                VStack(spacing: 24) {
                    switch currentStep {
                    case 0:
                        DatasetBasicInfoStep(
                            name: $datasetName,
                            description: $datasetDescription,
                            tags: $tags,
                            newTag: $newTag
                        )
                    case 1:
                        DataTypeStep(
                            selectedType: $selectedType
                        )
                    case 2:
                        DataSourceStep(
                            selectedPath: $selectedPath,
                            selectedType: selectedType,
                            classes: $classes,
                            newClass: $newClass
                        )
                    case 3:
                        DatasetReviewStep(
                            name: datasetName,
                            description: datasetDescription,
                            dataType: selectedType,
                            sourcePath: selectedPath,
                            classes: classes,
                            tags: tags
                        )
                    default:
                        EmptyView()
                    }
                }
                .padding(24)
            }

            Divider()

            // Navigation buttons
            WizardNavigation(
                currentStep: $currentStep,
                totalSteps: steps.count,
                canProceed: canProceedToNextStep,
                isLastStep: currentStep == steps.count - 1,
                isProcessing: isCreating,
                onBack: { currentStep -= 1 },
                onNext: {
                    if currentStep == steps.count - 1 {
                        createDataset()
                    } else {
                        currentStep += 1
                    }
                },
                nextButtonText: currentStep == steps.count - 1 ? "Create Dataset" : "Next"
            )
        }
        .frame(width: 600, height: 550)
    }

    private var canProceedToNextStep: Bool {
        switch currentStep {
        case 0: return !datasetName.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return true
        case 2: return true
        case 3: return true
        default: return false
        }
    }

    private func createDataset() {
        isCreating = true

        let dataset = Dataset(
            name: datasetName.trimmingCharacters(in: .whitespaces),
            description: datasetDescription,
            type: selectedType,
            status: .active,
            path: selectedPath,
            sampleCount: 0,
            size: calculateSize(),
            classes: classes,
            metadata: [
                "tags": tags.joined(separator: ",")
            ]
        )

        Task {
            await appState.addDataset(dataset)
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }

    private func calculateSize() -> Int64 {
        guard let path = selectedPath else { return 0 }
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(atPath: path) {
            while let file = enumerator.nextObject() as? String {
                let filePath = (path as NSString).appendingPathComponent(file)
                if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                   let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        return totalSize
    }
}

// MARK: - Dataset Step Views

struct DatasetBasicInfoStep: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var tags: [String]
    @Binding var newTag: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardStepHeader(
                icon: "folder.badge.plus",
                title: "Basic Information",
                subtitle: "Give your dataset a name and description"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Dataset Name")
                    .font(.headline)
                TextField("e.g., CIFAR-10 Training Set", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.headline)
                TextEditor(text: $description)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.headline)

                HStack {
                    TextField("Add tag...", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addTag()
                        }

                    Button("Add") {
                        addTag()
                    }
                    .disabled(newTag.isEmpty)
                }

                if !tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagChip(text: tag) {
                                tags.removeAll { $0 == tag }
                            }
                        }
                    }
                }
            }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            newTag = ""
        }
    }
}

struct DataTypeStep: View {
    @Binding var selectedType: DatasetType

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardStepHeader(
                icon: "doc.on.doc",
                title: "Data Type",
                subtitle: "Select the type of data in your dataset"
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(DatasetType.allCases, id: \.self) { type in
                    DataTypeCard(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }

            InfoBanner(
                icon: "info.circle",
                message: dataTypeHint,
                color: selectedType.color
            )
        }
    }

    private var dataTypeHint: String {
        switch selectedType {
        case .images: return "Supports PNG, JPEG, HEIC, and other common image formats"
        case .text: return "Supports TXT, CSV, JSON, and other text-based formats"
        case .audio: return "Supports WAV, MP3, M4A, and other audio formats"
        case .video: return "Supports MP4, MOV, and other video formats"
        case .tabular: return "Supports CSV, TSV, and structured data files"
        case .custom: return "For specialized data formats not covered above"
        }
    }
}

struct DataSourceStep: View {
    @Binding var selectedPath: String?
    let selectedType: DatasetType
    @Binding var classes: [String]
    @Binding var newClass: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardStepHeader(
                icon: "folder",
                title: "Data Source",
                subtitle: "Select the folder containing your data"
            )

            // Folder selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Source Folder")
                    .font(.headline)

                HStack {
                    Text(selectedPath ?? "No folder selected")
                        .foregroundColor(selectedPath == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Browse...") {
                        selectFolder()
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            if selectedPath != nil {
                // Show folder info
                FolderInfoView(path: selectedPath!)
            }

            Divider()
                .padding(.vertical)

            // Class labels (for classification tasks)
            VStack(alignment: .leading, spacing: 8) {
                Text("Class Labels (Optional)")
                    .font(.headline)

                Text("Define class labels for classification tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Add class label...", text: $newClass)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addClass()
                        }

                    Button("Add") {
                        addClass()
                    }
                    .disabled(newClass.isEmpty)
                }

                if !classes.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(classes, id: \.self) { cls in
                            ClassChip(text: cls) {
                                classes.removeAll { $0 == cls }
                            }
                        }
                    }
                }
            }
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
        }
    }

    private func addClass() {
        let trimmed = newClass.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !classes.contains(trimmed) {
            classes.append(trimmed)
            newClass = ""
        }
    }
}

struct FolderInfoView: View {
    let path: String

    @State private var fileCount: Int = 0
    @State private var totalSize: Int64 = 0

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(fileCount)")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Divider()
                .frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatBytes(totalSize))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            calculateFolderInfo()
        }
    }

    private func calculateFolderInfo() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            var count = 0
            var size: Int64 = 0

            if let enumerator = fileManager.enumerator(atPath: path) {
                while let file = enumerator.nextObject() as? String {
                    let filePath = (path as NSString).appendingPathComponent(file)
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: filePath, isDirectory: &isDir) && !isDir.boolValue {
                        count += 1
                        if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
                           let fileSize = attrs[.size] as? Int64 {
                            size += fileSize
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.fileCount = count
                self.totalSize = size
            }
        }
    }
}

struct DatasetReviewStep: View {
    let name: String
    let description: String
    let dataType: DatasetType
    let sourcePath: String?
    let classes: [String]
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardStepHeader(
                icon: "checkmark.circle",
                title: "Review & Create",
                subtitle: "Confirm your dataset configuration"
            )

            VStack(spacing: 16) {
                ReviewRow(label: "Name", value: name)
                ReviewRow(label: "Description", value: description.isEmpty ? "No description" : description)

                HStack(alignment: .top) {
                    Text("Data Type")
                        .foregroundColor(.secondary)
                        .frame(width: 120, alignment: .leading)

                    HStack(spacing: 8) {
                        Image(systemName: dataType.icon)
                            .foregroundColor(dataType.color)
                        Text(dataType.rawValue)
                            .fontWeight(.medium)
                    }

                    Spacer()
                }

                ReviewRow(label: "Source", value: sourcePath ?? "No folder selected")

                if !classes.isEmpty {
                    HStack(alignment: .top) {
                        Text("Classes")
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .leading)

                        FlowLayout(spacing: 4) {
                            ForEach(classes, id: \.self) { cls in
                                Text(cls)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                if !tags.isEmpty {
                    HStack(alignment: .top) {
                        Text("Tags")
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .leading)

                        FlowLayout(spacing: 4) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            InfoBanner(
                icon: "lightbulb",
                message: "After creation, you can use this dataset to train your models",
                color: .green
            )
        }
    }
}

// MARK: - Supporting Components

struct DataTypeCard: View {
    let type: DatasetType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.title)
                    .foregroundColor(isSelected ? .white : type.color)

                Text(type.rawValue)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(typeDescription)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? type.color : Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? type.color : Color.gray.opacity(0.2), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var typeDescription: String {
        switch type {
        case .images: return "Photos, drawings, etc."
        case .text: return "Documents, logs, etc."
        case .audio: return "Sound files, speech"
        case .video: return "Video clips, streams"
        case .tabular: return "Structured data"
        case .custom: return "Other formats"
        }
    }
}

struct ClassChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.2))
        .cornerRadius(12)
    }
}
