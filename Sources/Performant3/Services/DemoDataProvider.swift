import Foundation

/// Provides sample/demo data for the ML platform
struct DemoDataProvider {

    // MARK: - Sample Models

    static var sampleModels: [MLModel] {
        [
            MLModel(
                id: "demo-model-1",
                name: "ImageClassifier-ResNet50",
                framework: .coreML,
                status: .ready,
                accuracy: 0.923,
                fileSize: 97_000_000,
                metadata: ["architecture": "ResNet50", "task": "image_classification"]
            ),
            MLModel(
                id: "demo-model-2",
                name: "TextSentiment-BERT",
                framework: .pytorch,
                status: .ready,
                accuracy: 0.891,
                fileSize: 440_000_000,
                metadata: ["architecture": "BERT-base", "task": "sentiment_analysis"]
            ),
            MLModel(
                id: "demo-model-3",
                name: "ObjectDetector-YOLOv8",
                framework: .coreML,
                status: .training,
                accuracy: 0.756,
                fileSize: 25_000_000,
                metadata: ["architecture": "YOLOv8n", "task": "object_detection"]
            ),
            MLModel(
                id: "demo-model-4",
                name: "SpeechRecognition-Whisper",
                framework: .mlx,
                status: .draft,
                accuracy: 0,
                fileSize: 0,
                metadata: ["architecture": "Whisper-small", "task": "speech_recognition"]
            )
        ]
    }

    // MARK: - Sample Training Runs

    static var sampleRuns: [TrainingRun] {
        var runs: [TrainingRun] = []

        // Active training run
        var activeRun = TrainingRun(
            id: "demo-run-1",
            name: "YOLOv8 Training - COCO Dataset",
            modelId: "demo-model-3",
            modelName: "ObjectDetector-YOLOv8",
            epochs: 100,
            batchSize: 16,
            learningRate: 0.001
        )
        activeRun.status = .running
        activeRun.currentEpoch = 42
        activeRun.progress = 0.42
        activeRun.loss = 0.234
        activeRun.accuracy = 0.756
        activeRun.metrics = generateMetrics(epochs: 42)
        activeRun.logs = generateLogs(epochs: 42)
        runs.append(activeRun)

        // Completed run
        var completedRun = TrainingRun(
            id: "demo-run-2",
            name: "ResNet50 Fine-tuning",
            modelId: "demo-model-1",
            modelName: "ImageClassifier-ResNet50",
            epochs: 50,
            batchSize: 32,
            learningRate: 0.0001
        )
        completedRun.status = .completed
        completedRun.currentEpoch = 50
        completedRun.progress = 1.0
        completedRun.loss = 0.0312
        completedRun.accuracy = 0.923
        completedRun.finishedAt = Date().addingTimeInterval(-3600)
        completedRun.metrics = generateMetrics(epochs: 50)
        completedRun.logs = generateLogs(epochs: 50, completed: true)
        runs.append(completedRun)

        // Another completed run
        var completedRun2 = TrainingRun(
            id: "demo-run-3",
            name: "BERT Sentiment Analysis",
            modelId: "demo-model-2",
            modelName: "TextSentiment-BERT",
            epochs: 10,
            batchSize: 64,
            learningRate: 2e-5
        )
        completedRun2.status = .completed
        completedRun2.currentEpoch = 10
        completedRun2.progress = 1.0
        completedRun2.loss = 0.0891
        completedRun2.accuracy = 0.891
        completedRun2.finishedAt = Date().addingTimeInterval(-86400)
        completedRun2.metrics = generateMetrics(epochs: 10)
        completedRun2.logs = generateLogs(epochs: 10, completed: true)
        runs.append(completedRun2)

        return runs
    }

    // MARK: - Sample Datasets

    static var sampleDatasets: [Dataset] {
        [
            // Built-in MNIST dataset for quick start
            Dataset(
                id: "builtin-mnist",
                name: "MNIST (Built-in)",
                description: "Classic handwritten digit recognition dataset with 60,000 training images and 10,000 test images of 28x28 grayscale digits.",
                type: .images,
                status: .active,
                path: "builtin:mnist",  // Special path to indicate built-in dataset
                sampleCount: 60000,
                size: 50_000_000,
                classes: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"],
                metadata: ["builtin": "true"]
            ),
            Dataset(
                id: "demo-dataset-1",
                name: "COCO 2017",
                description: "Large-scale object detection, segmentation, and captioning dataset with 80 object categories.",
                type: .images,
                status: .active,
                path: nil,
                sampleCount: 118287,
                size: 19_000_000_000,
                classes: ["person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow"]
            ),
            Dataset(
                id: "demo-dataset-2",
                name: "IMDB Reviews",
                description: "Binary sentiment classification dataset of 50,000 movie reviews for natural language processing.",
                type: .text,
                status: .active,
                path: nil,
                sampleCount: 50000,
                size: 84_000_000,
                classes: ["positive", "negative"]
            ),
            Dataset(
                id: "demo-dataset-3",
                name: "ImageNet-1K Subset",
                description: "Subset of ImageNet with 100,000 images across 1000 classes for image classification benchmarking.",
                type: .images,
                status: .active,
                path: nil,
                sampleCount: 100000,
                size: 14_000_000_000,
                classes: ["tench", "goldfish", "great white shark", "tiger shark", "hammerhead", "electric ray", "stingray", "cock", "hen", "ostrich"]
            ),
            Dataset(
                id: "demo-dataset-4",
                name: "LibriSpeech",
                description: "Large corpus of read English speech for training and evaluating speech recognition systems.",
                type: .audio,
                status: .active,
                path: nil,
                sampleCount: 28539,
                size: 6_300_000_000,
                classes: []
            )
        ]
    }

    // MARK: - Seed Data (Auto-loaded on first run)

    static var seedModels: [MLModel] {
        [
            MLModel(
                id: "seed-model-mlp",
                name: "MLP Classifier",
                framework: .mlx,
                status: .draft,
                accuracy: 0,
                fileSize: 0,
                metadata: ["description": "Simple Multi-Layer Perceptron for classification tasks", "architecture": "MLP"]
            ),
            MLModel(
                id: "seed-model-cnn",
                name: "CNN Image Classifier",
                framework: .mlx,
                status: .draft,
                accuracy: 0,
                fileSize: 0,
                metadata: ["description": "Convolutional Neural Network for image classification", "architecture": "CNN"]
            ),
            MLModel(
                id: "seed-model-resnet",
                name: "ResNet-18",
                framework: .coreML,
                status: .draft,
                accuracy: 0,
                fileSize: 0,
                metadata: ["description": "Residual Network with 18 layers for deep learning", "architecture": "ResNet"]
            )
        ]
    }

    static var seedDatasets: [Dataset] {
        [
            Dataset(
                id: "builtin-mnist",
                name: "MNIST (Built-in)",
                description: "Classic handwritten digit recognition dataset with 60,000 training images of 28x28 grayscale digits.",
                type: .images,
                status: .active,
                path: "builtin:mnist",
                sampleCount: 60000,
                size: 50_000_000,
                classes: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"],
                metadata: ["builtin": "true"]
            ),
            Dataset(
                id: "seed-dataset-fashion",
                name: "Fashion-MNIST",
                description: "Drop-in replacement for MNIST with 70,000 grayscale images of fashion items in 10 categories.",
                type: .images,
                status: .active,
                path: nil,
                sampleCount: 70000,
                size: 30_000_000,
                classes: ["T-shirt/top", "Trouser", "Pullover", "Dress", "Coat", "Sandal", "Shirt", "Sneaker", "Bag", "Ankle boot"],
                metadata: ["source": "zalando"]
            ),
            Dataset(
                id: "seed-dataset-cifar",
                name: "CIFAR-10",
                description: "Collection of 60,000 32x32 color images in 10 classes, with 6,000 images per class.",
                type: .images,
                status: .active,
                path: nil,
                sampleCount: 60000,
                size: 170_000_000,
                classes: ["airplane", "automobile", "bird", "cat", "deer", "dog", "frog", "horse", "ship", "truck"],
                metadata: ["source": "toronto"]
            )
        ]
    }

    // MARK: - Sample Inference Results

    static var sampleInferenceResults: [InferenceResult] {
        [
            InferenceResult(
                id: "demo-inference-1",
                requestId: "req-1",
                modelId: "demo-model-1",
                predictions: [
                    Prediction(label: "golden retriever", confidence: 0.923),
                    Prediction(label: "labrador retriever", confidence: 0.045),
                    Prediction(label: "flat-coated retriever", confidence: 0.018),
                    Prediction(label: "chesapeake bay retriever", confidence: 0.008),
                    Prediction(label: "curly-coated retriever", confidence: 0.003)
                ],
                inferenceTimeMs: 23.4,
                timestamp: Date().addingTimeInterval(-300)
            ),
            InferenceResult(
                id: "demo-inference-2",
                requestId: "req-2",
                modelId: "demo-model-1",
                predictions: [
                    Prediction(label: "sports car", confidence: 0.874),
                    Prediction(label: "convertible", confidence: 0.089),
                    Prediction(label: "racer", confidence: 0.021),
                    Prediction(label: "beach wagon", confidence: 0.009),
                    Prediction(label: "minivan", confidence: 0.004)
                ],
                inferenceTimeMs: 18.7,
                timestamp: Date().addingTimeInterval(-600)
            )
        ]
    }

    // MARK: - Helper Functions

    private static func generateMetrics(epochs: Int) -> [MetricPoint] {
        var metrics: [MetricPoint] = []
        for epoch in 1...epochs {
            let baseLoss = 2.5 * exp(-0.05 * Double(epoch))
            let noise = Double.random(in: -0.05...0.05)
            let loss = max(0.01, baseLoss + noise)

            let baseAccuracy = 1.0 - exp(-0.08 * Double(epoch))
            let accNoise = Double.random(in: -0.02...0.02)
            let accuracy = min(0.99, max(0.1, baseAccuracy + accNoise))

            metrics.append(MetricPoint(epoch: epoch, loss: loss, accuracy: accuracy))
        }
        return metrics
    }

    private static func generateLogs(epochs: Int, completed: Bool = false) -> [LogEntry] {
        var logs: [LogEntry] = []

        logs.append(LogEntry(level: .info, message: "Training started"))
        logs.append(LogEntry(level: .info, message: "Configuration: epochs=\(epochs), batch_size=32, lr=0.001"))
        logs.append(LogEntry(level: .info, message: "Using GPU: Apple M1 Pro"))
        logs.append(LogEntry(level: .info, message: "Dataset loaded: 50000 samples"))

        for epoch in 1...min(epochs, 5) {
            let loss = 2.5 * exp(-0.05 * Double(epoch))
            let accuracy = 1.0 - exp(-0.08 * Double(epoch))
            logs.append(LogEntry(
                level: .info,
                message: String(format: "Epoch %d/%d - loss: %.4f, accuracy: %.2f%%", epoch, epochs, loss, accuracy * 100)
            ))
        }

        if epochs > 5 {
            logs.append(LogEntry(level: .info, message: "... (training in progress)"))
        }

        if completed {
            logs.append(LogEntry(level: .info, message: "Training completed successfully"))
            logs.append(LogEntry(level: .info, message: "Final metrics - loss: 0.0312, accuracy: 92.30%"))
            logs.append(LogEntry(level: .info, message: "Model checkpoint saved"))
        }

        return logs
    }
}
