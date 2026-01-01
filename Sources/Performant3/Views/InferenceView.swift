import SwiftUI
import AppKit

struct InferenceView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HSplitView {
            // Left: Model & Input Selection
            InferenceInputPanel()
                .frame(minWidth: 450)

            // Right: Results
            InferenceResultsPanel()
        }
        .background(AppTheme.background)
    }
}

// MARK: - Input Panel

struct InferenceInputPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedModelId: String?
    @State private var selectedImage: NSImage?
    @State private var selectedImageURL: URL?
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var isDraggingImage = false

    var selectedModel: MLModel? {
        selectedModelId.flatMap { id in appState.models.first { $0.id == id } }
    }

    var trainedModels: [MLModel] {
        appState.models.filter { $0.framework == .mlx && $0.filePath != nil && $0.status == .ready }
    }

    var completedRuns: [TrainingRun] {
        appState.runs.filter { $0.status == .completed }
    }

    var inferenceButtonHelpText: String {
        if isRunning {
            return "Inference in progress..."
        } else if selectedModelId == nil && selectedImageURL == nil {
            return "Select a model and an image to run inference"
        } else if selectedModelId == nil {
            return "Select a model to run inference"
        } else if selectedImageURL == nil {
            return "Select an image to run inference"
        } else {
            return "Run inference with the selected model"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.secondaryGradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Inference")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Run predictions with your trained models")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            }
            .padding()
            .background(AppTheme.background)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // STEP 1: Select Model
                    StepSection(number: 1, title: "Select a Trained Model") {
                        if trainedModels.isEmpty {
                            // No trained models yet
                            NoTrainedModelsView(completedRuns: completedRuns)
                        } else {
                            // Show trained models as cards
                            VStack(spacing: 12) {
                                ForEach(trainedModels) { model in
                                    TrainedModelCard(
                                        model: model,
                                        isSelected: selectedModelId == model.id,
                                        onSelect: { selectedModelId = model.id }
                                    )
                                }
                            }
                        }
                    }

                    // STEP 2: Select Image (only enabled if model selected)
                    StepSection(
                        number: 2,
                        title: "Select Input Image",
                        isEnabled: selectedModelId != nil
                    ) {
                        ImageDropZone(
                            selectedImage: $selectedImage,
                            selectedImageURL: $selectedImageURL,
                            isDragging: $isDraggingImage,
                            isEnabled: selectedModelId != nil
                        )
                    }

                    // STEP 3: Run Inference
                    StepSection(
                        number: 3,
                        title: "Run Prediction",
                        isEnabled: selectedModelId != nil && selectedImageURL != nil
                    ) {
                        Button(action: runInference) {
                            HStack(spacing: 12) {
                                if isRunning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.title2)
                                }
                                VStack(alignment: .leading) {
                                    Text(isRunning ? "Running..." : "Run Inference")
                                        .font(.headline)
                                    if let model = selectedModel {
                                        Text("Using \(model.name)")
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(selectedModelId == nil || selectedImageURL == nil || isRunning)
                        .keyboardShortcut("r", modifiers: .command)
                        .help(inferenceButtonHelpText + " (⌘R)")
                    }

                    // Error Message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .onAppear {
            // Pre-select model from global selection if available and it's a trained model
            if let globalModelId = appState.selectedModelId,
               trainedModels.contains(where: { $0.id == globalModelId }) {
                selectedModelId = globalModelId
            }
        }
        .onChange(of: appState.selectedModelId) { _, newModelId in
            // Update selection when global model changes (e.g., user selected model in Models tab)
            if let modelId = newModelId,
               trainedModels.contains(where: { $0.id == modelId }) {
                selectedModelId = modelId
            }
        }
    }

    private func runInference() {
        guard let model = selectedModel, let imageURL = selectedImageURL else { return }

        isRunning = true
        errorMessage = nil

        Task {
            do {
                _ = try await appState.runInference(model: model, imageURL: imageURL)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
        }
    }
}

// MARK: - Step Section

struct StepSection<Content: View>: View {
    let number: Int
    let title: String
    var isEnabled: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Step number circle
                ZStack {
                    if isEnabled {
                        Circle()
                            .fill(AppTheme.primaryGradient)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(AppTheme.surface)
                            .frame(width: 32, height: 32)
                    }
                    Text("\(number)")
                        .font(.headline)
                        .foregroundColor(isEnabled ? .white : AppTheme.textMuted)
                }

                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(isEnabled ? AppTheme.textPrimary : AppTheme.textMuted)
            }

            content
                .opacity(isEnabled ? 1 : 0.5)
                .allowsHitTesting(isEnabled)
        }
    }
}

// MARK: - No Trained Models View

struct NoTrainedModelsView: View {
    let completedRuns: [TrainingRun]
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Trained Models Yet")
                    .font(.headline)

                if completedRuns.isEmpty {
                    Text("Train a model first to use it for inference")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: { appState.selectedTab = .runs; appState.showNewRunSheet = true }) {
                        Label("Start Training", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                } else {
                    Text("You have \(completedRuns.count) completed training run(s), but the models haven't been registered yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Try running a new training to see it here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Trained Model Card

struct TrainedModelCard: View {
    @EnvironmentObject var appState: AppState
    let model: MLModel
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var showingClassEditor = false

    var architectureType: String {
        model.metadata["architectureType"] ?? "MLP"
    }

    var classLabels: [String] {
        if let labelsJson = model.metadata["classLabels"],
           let labelsData = labelsJson.data(using: .utf8),
           let labels = try? JSONDecoder().decode([String].self, from: labelsData) {
            return labels
        }
        return []
    }

    var numClasses: Int {
        Int(model.metadata["numClasses"] ?? "0") ?? classLabels.count
    }

    var architectureIcon: String {
        switch architectureType {
        case "MLP": return "point.3.connected.trianglepath.dotted"
        case "CNN": return "square.grid.3x3.topleft.filled"
        case "ResNet": return "arrow.triangle.branch"
        case "Transformer": return "brain.head.profile"
        default: return "cpu"
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(model.framework.color.opacity(0.2))
                            .frame(width: 56, height: 56)
                        Image(systemName: architectureIcon)
                            .font(.title2)
                            .foregroundColor(model.framework.color)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack(spacing: 8) {
                            Label(architectureType, systemImage: architectureIcon)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if model.accuracy > 0 {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f%% accuracy", model.accuracy * 100))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 16, height: 16)
                        }
                    }
                }

                // Show class labels when selected
                if isSelected && !classLabels.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Output Classes (\(numClasses))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { showingClassEditor = true }) {
                                Label("Edit", systemImage: "pencil")
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                        }

                        FlowLayout(spacing: 6) {
                            ForEach(Array(classLabels.enumerated()), id: \.offset) { index, label in
                                HStack(spacing: 4) {
                                    Text("\(index):")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(label)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppTheme.primary : Color.white.opacity(0.05), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingClassEditor) {
            ClassLabelEditorView(model: model, classLabels: classLabels)
        }
    }
}

// MARK: - Class Label Editor

struct ClassLabelEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let model: MLModel
    let classLabels: [String]
    @State private var editedLabels: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Output Classes")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { saveLabels() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Class labels list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(editedLabels.indices, id: \.self) { index in
                        HStack {
                            Text("Class \(index):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .trailing)

                            TextField("Label", text: $editedLabels[index])
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Class labels map model output indices to human-readable names")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        }
        .frame(width: 400, height: 400)
        .onAppear {
            editedLabels = classLabels
        }
    }

    private func saveLabels() {
        // Update model metadata with new labels
        var updatedModel = model
        if let labelsData = try? JSONEncoder().encode(editedLabels),
           let labelsJson = String(data: labelsData, encoding: .utf8) {
            updatedModel.metadata["classLabels"] = labelsJson
            appState.updateModel(updatedModel)
        }
        dismiss()
    }
}

// MARK: - Flow Layout for Class Labels

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

// MARK: - Image Drop Zone

struct ImageDropZone: View {
    @Binding var selectedImage: NSImage?
    @Binding var selectedImageURL: URL?
    @Binding var isDragging: Bool
    var isEnabled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: selectedImage == nil ? [8] : [])
                        )
                )

            if let image = selectedImage {
                // Show selected image and preprocessed preview side by side
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        // Original image
                        VStack(spacing: 4) {
                            Text("Original")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(8)
                                .frame(maxHeight: 150)
                        }

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        // Preprocessed preview (what model sees)
                        VStack(spacing: 4) {
                            Text("Model Input (28×28)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if let preprocessed = generatePreprocessedImage(from: image) {
                                Image(nsImage: preprocessed)
                                    .resizable()
                                    .interpolation(.none)  // Keep pixelated for clarity
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 112, height: 112)  // 4x scale for visibility
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.orange, lineWidth: 1)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 112, height: 112)
                                    .overlay(Text("Preview\nUnavailable").font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center))
                            }
                        }
                    }

                    HStack {
                        if let url = selectedImageURL {
                            Image(systemName: "photo.fill")
                                .foregroundColor(.green)
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Change") { selectImage() }
                            .buttonStyle(.borderless)
                        Button("Clear") {
                            selectedImage = nil
                            selectedImageURL = nil
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                }
                .padding()
            } else {
                // Drop zone placeholder
                VStack(spacing: 12) {
                    Image(systemName: isDragging ? "arrow.down.circle.fill" : "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(isDragging ? .accentColor : .secondary)

                    VStack(spacing: 4) {
                        Text(isDragging ? "Drop Image Here" : "Drag & Drop Image")
                            .font(.headline)
                            .foregroundColor(isDragging ? .accentColor : .primary)
                        Text("or click to browse")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Button("Browse Files") { selectImage() }
                        .buttonStyle(.bordered)
                        .disabled(!isEnabled)
                }
                .padding(32)
            }
        }
        .frame(height: selectedImage == nil ? 200 : nil)
        .onTapGesture {
            if isEnabled && selectedImage == nil {
                selectImage()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            guard isEnabled else { return false }
            return handleDrop(providers: providers)
        }
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            if let data = data as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    loadImage(from: url)
                }
            }
        }
        return true
    }

    private func loadImage(from url: URL) {
        if let image = NSImage(contentsOf: url) {
            selectedImage = image
            selectedImageURL = url
        }
    }

    /// Generate a 28x28 preprocessed image preview matching what the model will see
    private func generatePreprocessedImage(from nsImage: NSImage) -> NSImage? {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let targetSize = 28

        // Create grayscale context for resizing
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize,
            space: colorSpace,
            bitmapInfo: 0
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        // Flip to match MNIST coordinate system
        context.translateBy(x: 0, y: CGFloat(targetSize))
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

        guard let data = context.data else { return nil }
        let pixelData = data.bindMemory(to: UInt8.self, capacity: targetSize * targetSize)

        // Calculate average from CENTER region (to ignore borders/axes in matplotlib plots)
        // Use center 14x14 region (50% of image) - matches inference preprocessing
        let centerSize = 14
        let startOffset = (targetSize - centerSize) / 2  // Start at pixel 7
        var centerSum = 0
        for row in startOffset..<(startOffset + centerSize) {
            for col in startOffset..<(startOffset + centerSize) {
                let idx = row * targetSize + col
                centerSum += Int(pixelData[idx])
            }
        }
        let centerAvgPixel = centerSum / (centerSize * centerSize)
        let shouldInvert = centerAvgPixel > 127

        // Create output image with inversion applied
        var outputPixels = [UInt8](repeating: 0, count: targetSize * targetSize)
        for i in 0..<(targetSize * targetSize) {
            if shouldInvert {
                outputPixels[i] = 255 - pixelData[i]
            } else {
                outputPixels[i] = pixelData[i]
            }
        }

        // Create NSImage from processed pixels
        guard let outputContext = CGContext(
            data: &outputPixels,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize,
            space: colorSpace,
            bitmapInfo: 0
        ), let outputCGImage = outputContext.makeImage() else {
            return nil
        }

        return NSImage(cgImage: outputCGImage, size: NSSize(width: targetSize, height: targetSize))
    }
}

// MARK: - Results Panel

struct InferenceResultsPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedResult: InferenceResult?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Results")
                    .font(.headline)
                Spacer()
                if !appState.inferenceHistory.isEmpty {
                    Text("\(appState.inferenceHistory.count) predictions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            Divider()

            if appState.inferenceHistory.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No predictions yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Run inference to see results here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Results list with scroll reader for auto-scroll
                ScrollViewReader { scrollProxy in
                    List(selection: $selectedResult) {
                        ForEach(appState.inferenceHistory) { result in
                            InferenceResultRow(result: result)
                                .tag(result)
                                .id(result.id)
                        }
                    }
                    .listStyle(.inset)
                    .onChange(of: appState.inferenceHistory.count) { oldCount, newCount in
                        // Auto-scroll and select new result when inference completes
                        if newCount > oldCount, let firstResult = appState.inferenceHistory.first {
                            selectedResult = firstResult
                            withAnimation(.easeInOut(duration: 0.3)) {
                                scrollProxy.scrollTo(firstResult.id, anchor: .top)
                            }
                        }
                    }
                }

                // Selected result detail
                if let result = selectedResult ?? appState.inferenceHistory.first {
                    Divider()
                    InferenceResultDetail(result: result)
                }
            }
        }
    }
}

// MARK: - Result Row

struct InferenceResultRow: View {
    let result: InferenceResult

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let top = result.predictions.first {
                    Text(top.label)
                        .fontWeight(.medium)
                    Text(String(format: "%.1f%% confidence", top.confidence * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f ms", result.inferenceTimeMs))
                    .font(.caption)
                    .monospacedDigit()
                Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Result Detail

struct InferenceResultDetail: View {
    let result: InferenceResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Predictions")
                .font(.headline)

            ForEach(result.predictions) { prediction in
                HStack {
                    Text(prediction.label)
                        .fontWeight(.medium)
                    Spacer()
                    Text(String(format: "%.1f%%", prediction.confidence * 100))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                ProgressView(value: prediction.confidence)
                    .tint(prediction.confidence > 0.5 ? .green : .orange)
            }

            Divider()

            HStack {
                Label(String(format: "%.1f ms", result.inferenceTimeMs), systemImage: "clock")
                Spacer()
                Label(result.timestamp.formatted(), systemImage: "calendar")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(AppTheme.surface)
    }
}
