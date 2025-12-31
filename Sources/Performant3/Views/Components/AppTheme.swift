import SwiftUI

// MARK: - Modern MLOps Theme

enum AppTheme {
    // MARK: - Colors

    // Primary palette - Professional dark theme
    static let background = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let surface = Color(red: 0.11, green: 0.12, blue: 0.16)
    static let surfaceElevated = Color(red: 0.14, green: 0.15, blue: 0.20)
    static let surfaceHover = Color(red: 0.18, green: 0.19, blue: 0.24)

    // Accent colors
    static let primary = Color(red: 0.35, green: 0.55, blue: 1.0)  // Electric blue
    static let secondary = Color(red: 0.55, green: 0.35, blue: 1.0)  // Purple
    static let success = Color(red: 0.2, green: 0.85, blue: 0.55)  // Vibrant green
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.25)  // Warm yellow
    static let error = Color(red: 1.0, green: 0.35, blue: 0.4)  // Coral red

    // Gradient presets
    static let primaryGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let successGradient = LinearGradient(
        colors: [Color(red: 0.2, green: 0.85, blue: 0.55), Color(red: 0.1, green: 0.7, blue: 0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.5, blue: 0.3), Color(red: 1.0, green: 0.3, blue: 0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let textMuted = Color(white: 0.45)

    // MARK: - Typography

    static func heroTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(textPrimary)
    }

    static func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(textPrimary)
    }

    // MARK: - Card Styles

    static func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(surfaceElevated.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
    }

    static func metricCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [surfaceElevated, surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 15, y: 8)
    }
}

// MARK: - Animated Components

struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .scaleEffect(isPulsing ? 2 : 1)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
    }
}

struct ThemeAnimatedCounter: View {
    let value: Int
    let format: String

    @State private var displayValue: Double = 0

    var body: some View {
        Text(String(format: format, displayValue))
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(AppTheme.primaryGradient)
            .onChange(of: value) { oldValue, newValue in
                withAnimation(.spring(duration: 0.8)) {
                    displayValue = Double(newValue)
                }
            }
            .onAppear {
                withAnimation(.spring(duration: 0.8)) {
                    displayValue = Double(value)
                }
            }
    }
}

struct GlowingIcon: View {
    let systemName: String
    let color: Color
    let size: CGFloat

    @State private var isGlowing = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(color)
            .shadow(color: color.opacity(isGlowing ? 0.8 : 0.3), radius: isGlowing ? 12 : 4)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                ) {
                    isGlowing = true
                }
            }
    }
}

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.5)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 1), value: progress)
        }
    }
}

// MARK: - HuggingFace Model Hub Data

struct HFModel: Identifiable {
    let id: String
    let name: String
    let description: String
    let downloads: String
    let likes: Int
    let task: String
    let icon: String
}

let popularHFModels: [HFModel] = [
    HFModel(
        id: "bert-base",
        name: "BERT Base",
        description: "Bidirectional encoder for NLP tasks",
        downloads: "50M+",
        likes: 12500,
        task: "NLP",
        icon: "text.bubble"
    ),
    HFModel(
        id: "resnet-50",
        name: "ResNet-50",
        description: "Deep residual network for image classification",
        downloads: "25M+",
        likes: 8900,
        task: "Vision",
        icon: "photo"
    ),
    HFModel(
        id: "gpt2",
        name: "GPT-2",
        description: "Generative pre-trained transformer",
        downloads: "35M+",
        likes: 15600,
        task: "Text Gen",
        icon: "text.justify"
    ),
    HFModel(
        id: "vit-base",
        name: "ViT Base",
        description: "Vision Transformer for image classification",
        downloads: "18M+",
        likes: 7200,
        task: "Vision",
        icon: "viewfinder"
    ),
    HFModel(
        id: "whisper-small",
        name: "Whisper Small",
        description: "Speech recognition and transcription",
        downloads: "22M+",
        likes: 9800,
        task: "Audio",
        icon: "waveform"
    ),
    HFModel(
        id: "yolov8",
        name: "YOLOv8",
        description: "Real-time object detection",
        downloads: "15M+",
        likes: 11200,
        task: "Detection",
        icon: "square.3.layers.3d"
    )
]

// MARK: - Popular Datasets

struct PopularDataset: Identifiable {
    let id: String
    let name: String
    let description: String
    let samples: String
    let task: String
    let icon: String
}

let popularDatasets: [PopularDataset] = [
    PopularDataset(
        id: "mnist",
        name: "MNIST",
        description: "Handwritten digit recognition",
        samples: "70K",
        task: "Classification",
        icon: "number"
    ),
    PopularDataset(
        id: "cifar10",
        name: "CIFAR-10",
        description: "10 classes of 32x32 images",
        samples: "60K",
        task: "Classification",
        icon: "photo.stack"
    ),
    PopularDataset(
        id: "imagenet",
        name: "ImageNet",
        description: "Large-scale image classification",
        samples: "14M+",
        task: "Classification",
        icon: "photo.on.rectangle"
    ),
    PopularDataset(
        id: "coco",
        name: "COCO",
        description: "Object detection and segmentation",
        samples: "330K",
        task: "Detection",
        icon: "square.3.layers.3d"
    ),
    PopularDataset(
        id: "squad",
        name: "SQuAD",
        description: "Question answering dataset",
        samples: "100K",
        task: "QA",
        icon: "questionmark.bubble"
    ),
    PopularDataset(
        id: "librispeech",
        name: "LibriSpeech",
        description: "English speech recognition",
        samples: "1K hrs",
        task: "Speech",
        icon: "waveform.circle"
    )
]
