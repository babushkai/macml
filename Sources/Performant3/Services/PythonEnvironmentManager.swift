import Foundation

/// Manages the Python virtual environment for ML training
actor PythonEnvironmentManager {
    static let shared = PythonEnvironmentManager()

    private let venvPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".performant3/venv")

    private let requiredPackages = [
        "ultralytics",
        "torch",
        "torchvision",
        "numpy",
        "pillow",
        "pyyaml",
        "coremltools",
        "safetensors"
    ]

    enum Status: Equatable {
        case notChecked
        case checking
        case ready
        case missingVenv
        case missingPackages([String])
        case installing(String)
        case error(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    private(set) var status: Status = .notChecked

    var pythonPath: String {
        venvPath.appendingPathComponent("bin/python3").path
    }

    var pipPath: String {
        venvPath.appendingPathComponent("bin/pip").path
    }

    // MARK: - Public API

    /// Check environment status without modifying it
    func checkStatus() async -> Status {
        status = .checking

        // Check if venv exists
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            status = .missingVenv
            return status
        }

        // Check installed packages
        let missingPackages = await checkMissingPackages()
        if !missingPackages.isEmpty {
            status = .missingPackages(missingPackages)
            return status
        }

        status = .ready
        return status
    }

    /// Ensure environment is ready, creating/installing if needed
    func ensureReady(progressHandler: ((String) -> Void)? = nil) async throws {
        let currentStatus = await checkStatus()

        switch currentStatus {
        case .ready:
            return

        case .missingVenv:
            progressHandler?("Creating Python virtual environment...")
            try await createVenv()
            progressHandler?("Installing required packages...")
            try await installPackages(requiredPackages, progressHandler: progressHandler)
            status = .ready

        case .missingPackages(let packages):
            progressHandler?("Installing missing packages: \(packages.joined(separator: ", "))")
            try await installPackages(packages, progressHandler: progressHandler)
            status = .ready

        case .error(let message):
            throw PythonEnvironmentError.setupFailed(message)

        default:
            break
        }
    }

    // MARK: - Private Methods

    private func createVenv() async throws {
        // Create parent directory
        let parentDir = venvPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Create venv using system Python
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "venv", venvPath.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PythonEnvironmentError.venvCreationFailed(errorMessage)
        }

        // Upgrade pip
        try await runPip(["install", "--upgrade", "pip"])
    }

    private func checkMissingPackages() async -> [String] {
        guard FileManager.default.fileExists(atPath: pipPath) else {
            return requiredPackages
        }

        // Get installed packages
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pipPath)
        process.arguments = ["list", "--format=freeze"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            let installedPackages = Set(output.components(separatedBy: .newlines)
                .compactMap { line -> String? in
                    let name = line.split(separator: "=").first.map(String.init)
                    return name?.lowercased()
                })

            return requiredPackages.filter { package in
                !installedPackages.contains(package.lowercased())
            }
        } catch {
            return requiredPackages
        }
    }

    private func installPackages(_ packages: [String], progressHandler: ((String) -> Void)? = nil) async throws {
        for package in packages {
            status = .installing(package)
            progressHandler?("Installing \(package)...")
            try await runPip(["install", package])
        }
    }

    private func runPip(_ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pipPath)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "pip command failed"
            throw PythonEnvironmentError.packageInstallFailed(errorMessage)
        }
    }

    /// Get Python version string
    func getPythonVersion() async -> String? {
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["--version"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Get installed package versions
    func getPackageVersions() async -> [String: String] {
        guard FileManager.default.fileExists(atPath: pipPath) else {
            return [:]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pipPath)
        process.arguments = ["list", "--format=json"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()

            struct PackageInfo: Codable {
                let name: String
                let version: String
            }

            let packages = try JSONDecoder().decode([PackageInfo].self, from: data)
            var result: [String: String] = [:]
            for pkg in packages {
                result[pkg.name.lowercased()] = pkg.version
            }
            return result
        } catch {
            return [:]
        }
    }
}

// MARK: - Errors

enum PythonEnvironmentError: Error, LocalizedError {
    case venvCreationFailed(String)
    case packageInstallFailed(String)
    case setupFailed(String)
    case pythonNotAvailable

    var errorDescription: String? {
        switch self {
        case .venvCreationFailed(let message):
            return "Failed to create Python virtual environment: \(message)"
        case .packageInstallFailed(let message):
            return "Failed to install Python package: \(message)"
        case .setupFailed(let message):
            return "Python environment setup failed: \(message)"
        case .pythonNotAvailable:
            return "Python is not available on this system"
        }
    }
}
