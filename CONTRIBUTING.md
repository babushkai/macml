# Contributing to Performant3

Thank you for your interest in contributing to Performant3!

## Development Setup

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3/M4)
- Xcode 15.0 or later
- Swift 5.9 or later

### Building

```bash
# Clone the repository
git clone https://github.com/babushkai/performant3.git
cd performant3

# Resolve dependencies
swift package resolve

# Build the app
./build-app.sh
```

## Making Changes

### Branch Naming

Use descriptive branch names with prefixes:

- `feat/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation changes
- `chore/` - Maintenance tasks

### Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature (triggers minor release)
- `fix:` - Bug fix (triggers patch release)
- `refactor:` - Code refactoring (no release)
- `docs:` - Documentation (no release)
- `chore:` - Maintenance (no release)
- `test:` - Tests (no release)

Example: `feat: add export to ONNX format`

### Pull Requests

1. Create a branch from `main`
2. Make your changes
3. Push and create a PR
4. Add appropriate labels if needed:
   - `release:major` - Breaking changes
   - `release:minor` - New features
   - `release:patch` - Bug fixes
   - `release:skip` - No release needed

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small

## Questions?

Open an issue for any questions or suggestions.
