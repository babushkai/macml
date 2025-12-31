import SwiftUI
import AppKit

struct NewModelSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Basic state
    @State private var name = ""
    @State private var framework: MLFramework = .coreML
    @State private var selectedURL: URL?
    @State private var isImporting = false
    @State private var errorMessage: String?

    // PyTorch conversion state
    @State private var isPyTorchModel = false
    @State private var targetFormat: ConversionFormat = .coreml
    @State private var inputShapePreset: InputShapePreset = .image224
    @State private var customShape: [Int] = [1, 3, 224, 224]
    @State private var isConverting = false
    @State private var conversionProgress: Double = 0
    @State private var conversionStep: String = ""

    var canImport: Bool {
        if isPyTorchModel {
            return !name.isEmpty && selectedURL != nil && !isImporting && !isConverting && isValidShape
        }
        return !name.isEmpty && selectedURL != nil && !isImporting
    }

    var isValidShape: Bool {
        if inputShapePreset != .custom { return true }
        return customShape.count >= 2 && customShape.allSatisfy { $0 > 0 }
    }

    var currentInputShape: [Int] {
        inputShapePreset.shape ?? customShape
    }

    var importButtonText: String {
        isPyTorchModel ? "Convert & Import" : "Import Model"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Model")
                    .font(.title2)
                    .fontWeight(.bold)
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

            // Content - Scrollable
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Step 1: Select File
                    fileSelectionSection

                    // PyTorch detected banner
                    if isPyTorchModel && selectedURL != nil {
                        pytorchDetectedBanner
                    }

                    // Step 2: Model Name
                    modelNameSection

                    // Step 3: Framework or Conversion Settings
                    if isPyTorchModel {
                        conversionSettingsSection
                    } else {
                        frameworkSection
                    }

                    // Error display
                    if let error = errorMessage {
                        errorView(error)
                    }

                    // Conversion progress
                    if isConverting {
                        conversionProgressView
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 550, height: isPyTorchModel ? 600 : 450)
    }

    // MARK: - Sections

    private var fileSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("1.")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Text("Select Model File")
                    .font(.headline)
            }

            if let url = selectedURL {
                HStack {
                    Image(systemName: isPyTorchModel ? "flame.fill" : "doc.fill")
                        .font(.title2)
                        .foregroundColor(isPyTorchModel ? .orange : .green)
                    VStack(alignment: .leading) {
                        Text(url.lastPathComponent)
                            .fontWeight(.medium)
                        Text(url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Change") { selectFile() }
                        .buttonStyle(.bordered)
                        .disabled(isConverting)
                }
                .padding()
                .background(isPyTorchModel ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                Button(action: selectFile) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Choose Model File...")
                                .fontWeight(.medium)
                            Text(".mlmodel, .mlmodelc, .mlpackage, .pt, .pth")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private var pytorchDetectedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("PyTorch Model Detected")
                    .fontWeight(.semibold)
                Text("This model will be converted to a compatible format before import.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    private var modelNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("2.")
                    .font(.headline)
                    .foregroundColor(selectedURL != nil ? .accentColor : .secondary)
                Text("Model Name")
                    .font(.headline)
                    .foregroundColor(selectedURL != nil ? .primary : .secondary)
            }
            TextField("Enter model name", text: $name)
                .textFieldStyle(.roundedBorder)
                .disabled(selectedURL == nil || isConverting)
        }
    }

    private var frameworkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("3.")
                    .font(.headline)
                    .foregroundColor(selectedURL != nil ? .accentColor : .secondary)
                Text("Framework")
                    .font(.headline)
                    .foregroundColor(selectedURL != nil ? .primary : .secondary)
            }
            Picker("", selection: $framework) {
                ForEach(MLFramework.allCases, id: \.self) { fw in
                    Text(fw.rawValue).tag(fw)
                }
            }
            .pickerStyle(.segmented)
            .disabled(selectedURL == nil)
        }
    }

    private var conversionSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Target Format
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("3.")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Text("Target Format")
                        .font(.headline)
                }

                Picker("", selection: $targetFormat) {
                    ForEach(ConversionFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isConverting)

                Text(targetFormat.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Input Shape
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("4.")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Text("Input Shape")
                        .font(.headline)
                }

                Text("Specify the input dimensions the model expects")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Preset picker
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(InputShapePreset.allCases) { preset in
                        Button {
                            inputShapePreset = preset
                        } label: {
                            VStack(spacing: 4) {
                                Text(preset.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(inputShapePreset == preset ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                            .foregroundColor(inputShapePreset == preset ? .white : .primary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(isConverting)
                    }
                }

                // Custom shape input
                if inputShapePreset == .custom {
                    HStack(spacing: 8) {
                        Text("Shape:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(0..<4, id: \.self) { index in
                            TextField("", value: Binding(
                                get: { customShape.indices.contains(index) ? customShape[index] : 1 },
                                set: { newValue in
                                    while customShape.count <= index {
                                        customShape.append(1)
                                    }
                                    customShape[index] = max(1, newValue)
                                }
                            ), formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .disabled(isConverting)
                        }

                        Text("(batch, channels, H, W)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }

                if inputShapePreset != .custom {
                    Text(inputShapePreset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error")
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            Text(error)
                .font(.callout)
                .foregroundColor(.secondary)

            // Recovery suggestion for CoreML failures
            if error.contains("CoreML") || error.contains("STATE_DICT_ONLY") || error.contains("UNSUPPORTED_OP") {
                Button("Try MLX Format Instead") {
                    targetFormat = .mlx
                    errorMessage = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    private var conversionProgressView: some View {
        VStack(spacing: 12) {
            ProgressView(value: conversionProgress)
                .progressViewStyle(.linear)

            HStack {
                Text(conversionStep)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(conversionProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Text("This may take a few minutes for large models.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var footerSection: some View {
        HStack {
            Button("Cancel") {
                if isConverting {
                    Task {
                        await ModelConversionService.shared.cancel()
                    }
                }
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button(action: importModel) {
                if isImporting || isConverting {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Label(importButtonText, systemImage: isPyTorchModel ? "arrow.triangle.2.circlepath" : "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canImport)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Actions

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "mlmodel")!,
            .init(filenameExtension: "mlmodelc")!,
            .init(filenameExtension: "mlpackage")!,
            .init(filenameExtension: "pt")!,
            .init(filenameExtension: "pth")!
        ]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            selectedURL = url
            isPyTorchModel = url.isPyTorchModel

            if name.isEmpty {
                name = url.deletingPathExtension().lastPathComponent
                if isPyTorchModel {
                    name += "-converted"
                }
            }

            // Reset error when selecting new file
            errorMessage = nil
        }
    }

    private func importModel() {
        guard let url = selectedURL else { return }

        errorMessage = nil

        if isPyTorchModel {
            convertAndImport(url: url)
        } else {
            directImport(url: url)
        }
    }

    private func directImport(url: URL) {
        isImporting = true

        Task {
            do {
                try await appState.importModel(from: url, name: name, framework: framework)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isImporting = false
        }
    }

    private func convertAndImport(url: URL) {
        isConverting = true
        conversionProgress = 0
        conversionStep = "Preparing..."

        Task {
            do {
                // Generate output path
                let modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Performant3/Models", isDirectory: true)

                // Create directory if needed
                try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

                let outputName = "\(UUID().uuidString).\(targetFormat.fileExtension)"
                let outputPath = modelsDir.appendingPathComponent(outputName)

                let config = ConversionConfig(
                    inputPath: url,
                    outputPath: outputPath,
                    targetFormat: targetFormat,
                    inputShape: currentInputShape,
                    modelName: name
                )

                let model = try await ModelConversionService.shared.convert(config: config) { progress, step in
                    Task { @MainActor in
                        if progress >= 0 {
                            self.conversionProgress = progress
                        }
                        self.conversionStep = step
                    }
                }

                // Add the converted model to app state
                await appState.addModel(model)

                await MainActor.run {
                    dismiss()
                }

            } catch let error as ConversionError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    if let suggestion = error.recoverySuggestion {
                        errorMessage! += "\n\n" + suggestion
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isConverting = false
            }
        }
    }
}
