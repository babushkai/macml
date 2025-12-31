# Performant3

A native macOS MLOps platform built for Apple Silicon, featuring SwiftUI interface and MLX integration for local machine learning workflows.

## Features

- **Native Apple Silicon Performance** - Built with MLX for optimized ML operations on M1/M2/M3/M4 chips
- **Local-First Design** - Run ML workflows entirely on your Mac without cloud dependencies
- **SwiftUI Interface** - Modern, responsive UI with dark mode support
- **Model Management** - Track, version, and manage ML models locally
- **Training Integration** - Python training script integration with progress monitoring

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3/M4)
- Xcode 15.0+ (for building from source)

## Installation

### From Release

1. Download the latest `.dmg` from [Releases](../../releases)
2. Open the DMG and drag **Performant3** to Applications
3. Launch from Applications

> **Note:** On first launch, right-click and select "Open" if you see a Gatekeeper warning.

### Building from Source

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/performant3.git
cd performant3

# Build the app
./build-app.sh

# Run
open Performant3.app
```

## Development

### Prerequisites

- Xcode 15.0+
- Swift 5.9+

### Build Commands

```bash
# Build with xcodebuild (required for Metal shaders)
xcodebuild -scheme Performant3 -destination 'platform=macOS' -configuration Release build

# Or use the build script (creates .app and .dmg)
./build-app.sh
```

### Project Structure

```
performant3/
├── Sources/Performant3/
│   ├── main.swift           # App entry point
│   ├── Database/            # GRDB persistence layer
│   ├── Models/              # Data models
│   ├── Services/            # Business logic
│   ├── Storage/             # Content-addressed storage
│   └── Views/               # SwiftUI views
├── Resources/Scripts/       # Python training scripts
├── Package.swift            # SPM manifest
└── build-app.sh            # Build script
```

### Dependencies

| Package | Purpose |
|---------|---------|
| [mlx-swift](https://github.com/ml-explore/mlx-swift) | Apple Silicon ML framework |
| [GRDB.swift](https://github.com/groue/GRDB.swift) | SQLite database |
| [swift-crypto](https://github.com/apple/swift-crypto) | Cryptographic operations |

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Commit with conventional format: `git commit -m "feat: add feature"`
4. Push and create a PR: `gh pr create`

See [RELEASING.md](.github/RELEASING.md) for release process details.

## License

[Add your license here]
