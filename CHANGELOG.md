# Changelog

All notable changes to MacML will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-01-17

### ⚙️ Miscellaneous

- Bump version to 0.1.2 [skip ci]

- Merge main into feat/japanese-localization

- Add merge as allowed commit type in commitlint

- Bump version to 0.2.0 [skip ci]


### 🐛 Bug Fixes

- Resolve Task type mismatch in DistillationService

- Remove duplicate StepIndicator and use existing one


### 📚 Documentation

- Update CHANGELOG.md for v0.1.2 [skip ci]


### 🔨 Refactoring

- **dashboard:** Remove accuracy trend chart, add more gauge metrics


### 🚀 Features

- Add knowledge distillation feature

- Add language switch setting in Settings view

## [0.1.1] - 2026-01-16

### Merge

- Resolve conflict with main branch


### ⚙️ Miscellaneous

- Add Dependabot auto-merge for patch updates

- Bump version to 0.2.0 [skip ci]

- Bump version to 0.1.1 [skip ci]


### ⚡ Performance

- **ci:** Skip CI for docs, use docker swiftlint, conditional build


### 🐛 Bug Fixes

- Disable subject-case rule in commitlint

- **ci:** Remove GitHub API calls from git-cliff template

- **ci:** Remove GitHub API calls from git-cliff template


### 📚 Documentation

- Update CHANGELOG.md for v0.1.1 [skip ci]


### 🚀 Features

- Add categorized release notes and version constant

- Add commitlint for conventional commit enforcement

- Localize RunsView, DatasetsView, and InferenceView

- Complete Japanese localization for RunsView, DatasetsView, and InferenceView


### 🧪 Testing

- Add UI testing infrastructure with BDD-style tests

## [0.1.0] - 2026-01-16

### ⚙️ Miscellaneous

- Bump version to 0.1.0 [skip ci]

## [0.0.0-preview-ja] - 2026-01-16

### ⚙️ Miscellaneous

- Bump version to 1.4.2 [skip ci]

- Enhance CI workflow with coverage, security scans, and multi-Xcode testing

- Add dev build for preview


### ⚡ Performance

- **ci:** Optimize test and build times

- **ci:** Major optimization - parallel jobs, ubuntu for security


### 🐛 Bug Fixes

- Use two-step image preprocessing to match inference pipeline (#29)

- Update build.yml and add test directory

- **ci:** Use Xcode 16.2, remove strict lint mode, simplify test matrix

- **ci:** Relax SwiftLint rules and make lint non-blocking

- Add CFBundleLocalizations for Japanese support


### 🔨 Refactoring

- Rename project from Performant3 to MacML


### 🚀 Features

- Add comprehensive MLOps features for end-to-end workflow

- Add code quality infrastructure and ViewModels

- Add Japanese localization support

- Add commitlint for conventional commit enforcement

- Localize DashboardView and ModelsView with Japanese translations

- Partial localization of RunsView header

## [1.4.1] - 2026-01-01

### ⚙️ Miscellaneous

- Bump version to 1.4.1 [skip ci]


### 🐛 Bug Fixes

- Correct grayscale conversion for colored image preprocessing (#26)

## [1.4.0] - 2026-01-01

### ⚙️ Miscellaneous

- Bump version to 1.4.0 [skip ci]


### 🚀 Features

- Apply modern design to all panes (#25)

## [1.3.3] - 2026-01-01

### ⚙️ Miscellaneous

- Bump version to 1.3.3 [skip ci]


### 🚀 Features

- Production-ready Model & Dataset Hub (#24)

## [1.3.2] - 2026-01-01

### ⚙️ Miscellaneous

- Remove placeholder data, keep only functional examples (#22)

- Bump version to 1.3.2 [skip ci]


### 🐛 Bug Fixes

- Use center region for image inversion detection (#23)

## [1.3.1] - 2026-01-01

### ⚙️ Miscellaneous

- Bump version to 1.3.1 [skip ci]


### 🐛 Bug Fixes

- Inference parameter loading and add preview/class editing (#21)

## [1.3.0] - 2025-12-31

### ⚙️ Miscellaneous

- Bump version to 1.3.0 [skip ci]


### 🚀 Features

- Modern MLOps command center UI redesign (#20)

## [1.2.6] - 2025-12-31

### ⚙️ Miscellaneous

- Bump version to 1.2.6 [skip ci]


### 🐛 Bug Fixes

- Critical loss function and normalization for proper training (#19)

## [1.2.5] - 2025-12-31

### Improve

- Better training defaults for MNIST accuracy (#18)


### ⚙️ Miscellaneous

- Bump version to 1.2.5 [skip ci]

## [1.2.4] - 2025-12-31

### ⚙️ Miscellaneous

- Bump version to 1.2.4 [skip ci]


### 🐛 Bug Fixes

- Improve MNIST training accuracy and inference (#17)

## [1.2.3] - 2025-12-31

### ⚙️ Miscellaneous

- Bump version to 1.2.3 [skip ci]


### 🐛 Bug Fixes

- Implement real MNIST dataset loading (#16)

## [1.2.2] - 2025-12-31

### ⚙️ Miscellaneous

- Bump version to 1.2.2 [skip ci]


### 🐛 Bug Fixes

- Redesign app icon with sophisticated style (#15)

## [1.2.1] - 2025-12-31

### ⚙️ Miscellaneous

- Bump version to 1.2.1 [skip ci]


### 🚀 Features

- Add app icon for macOS (#14)

## [1.2.0] - 2025-12-31

### ⚙️ Miscellaneous

- Add contributing guidelines (#12)

- Bump version to 1.2.0 [skip ci]


### 🔨 Refactoring

- Extract magic numbers to Constants enum (#11)


### 🚀 Features

- Add PyTorch model conversion support (#13)

## [1.1.2] - 2025-12-31

### ⚙️ Miscellaneous

- Bump version to 1.1.2 [skip ci]


### 📦 Dependencies

- **deps:** Bump actions/upload-artifact from 4 to 6 (#3)

- **deps:** Bump actions/github-script from 7 to 8 (#4)

- **deps:** Bump actions/labeler from 5 to 6 (#5)

- **deps:** Bump actions/cache from 4 to 5 (#6)

- **deps:** Bump actions/checkout from 4 to 6 (#7)

- **deps:** Bump github.com/apple/swift-crypto from 3.15.1 to 4.2.0 (#8)

## [1.1.1] - 2025-12-31

### ⚙️ Miscellaneous

- Bump version to 1.1.1 [skip ci]


### 🐛 Bug Fixes

- Improve database initialization error logging (#10)

## [1.1.0] - 2025-12-31

### ⚙️ Miscellaneous

- Bump version to 1.1.0 [skip ci]


### 🐛 Bug Fixes

- Skip tag creation if already exists

- Add write permissions to release workflow


### 🚀 Features

- Add CI enhancements (#2)

## [1.0.1] - 2025-12-31

### ⚙️ Miscellaneous

- Add README with project documentation

- Bump version to 1.0.1


### 🐛 Bug Fixes

- Use known derivedDataPath in CI workflows

- Add PR comment permissions to build workflow

- Add write permissions to release workflows


### 🚀 Features

- Finetuning the auth step

- Finetuning the auth step

- Finetuning the auth step

- Finetuning the auth step

## [1.0.0] - 2025-12-31
---
Generated by [git-cliff](https://git-cliff.org/)
