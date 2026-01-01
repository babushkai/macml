import Foundation

/// Provides seed data for the ML platform
/// All data here must be functional and production-ready
struct DemoDataProvider {

    // MARK: - Seed Models (Templates for Training)

    /// Model templates that users can train - these are NOT pre-trained models
    /// They define architectures that can be used with the MLX training pipeline
    static var seedModels: [MLModel] {
        [
            MLModel(
                id: "template-mlp",
                name: "MLP Classifier",
                framework: .mlx,
                status: .draft,
                accuracy: 0,
                fileSize: 0,
                metadata: [
                    "description": "Multi-Layer Perceptron - good for tabular data and simple classification",
                    "architectureType": "MLP",
                    "inputSize": "784",
                    "hiddenSizes": "[256, 128]",
                    "numClasses": "10"
                ]
            ),
            MLModel(
                id: "template-cnn",
                name: "CNN Image Classifier",
                framework: .mlx,
                status: .draft,
                accuracy: 0,
                fileSize: 0,
                metadata: [
                    "description": "Convolutional Neural Network - best for image classification",
                    "architectureType": "CNN",
                    "inputChannels": "1",
                    "numClasses": "10"
                ]
            ),
            MLModel(
                id: "template-resnet",
                name: "ResNet Mini",
                framework: .mlx,
                status: .draft,
                accuracy: 0,
                fileSize: 0,
                metadata: [
                    "description": "Residual Network - deep learning with skip connections",
                    "architectureType": "ResNet",
                    "numClasses": "10"
                ]
            ),
            MLModel(
                id: "template-transformer",
                name: "Transformer Classifier",
                framework: .mlx,
                status: .draft,
                accuracy: 0,
                fileSize: 0,
                metadata: [
                    "description": "Transformer encoder - attention-based architecture",
                    "architectureType": "Transformer",
                    "inputDim": "784",
                    "modelDim": "128",
                    "numHeads": "4",
                    "numLayers": "2",
                    "numClasses": "10"
                ]
            )
        ]
    }

    // MARK: - Seed Datasets (Actually Functional)

    /// Datasets that actually work - only include datasets with real implementations
    static var seedDatasets: [Dataset] {
        [
            // MNIST - the only fully functional built-in dataset
            Dataset(
                id: "builtin-mnist",
                name: "MNIST Handwritten Digits",
                description: "Classic dataset of 60,000 handwritten digit images (28x28 grayscale). Downloads automatically on first use.",
                type: .images,
                status: .active,
                path: "builtin:mnist",
                sampleCount: 60000,
                size: 11_000_000,  // Actual compressed size
                classes: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"],
                metadata: [
                    "builtin": "true",
                    "source": "https://storage.googleapis.com/cvdf-datasets/mnist/",
                    "imageSize": "28x28",
                    "channels": "1"
                ]
            )
        ]
    }

    // MARK: - Empty Collections (No Fake Data)

    /// No sample models - users should train their own
    static var sampleModels: [MLModel] { [] }

    /// No sample runs - these would be misleading
    static var sampleRuns: [TrainingRun] { [] }

    /// No sample datasets beyond seed - only show what works
    static var sampleDatasets: [Dataset] { seedDatasets }

    /// No sample inference results - let real results speak
    static var sampleInferenceResults: [InferenceResult] { [] }
}
