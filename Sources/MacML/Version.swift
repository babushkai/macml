import Foundation

/// Application version information
/// This provides compile-time and runtime version access
public enum AppVersion {
    // MARK: - Version Components

    /// Marketing version (e.g., "1.5.0")
    public static let version: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }()

    /// Build number (e.g., "1.5.0" or "42")
    public static let build: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }()

    /// Full version string (e.g., "1.5.0 (42)")
    public static var fullVersion: String {
        if version == build {
            return version
        }
        return "\(version) (\(build))"
    }

    // MARK: - Semantic Version Components

    /// Major version number
    public static var major: Int {
        let components = version.split(separator: ".")
        return Int(components.first ?? "0") ?? 0
    }

    /// Minor version number
    public static var minor: Int {
        let components = version.split(separator: ".")
        guard components.count > 1 else { return 0 }
        return Int(components[1]) ?? 0
    }

    /// Patch version number
    public static var patch: Int {
        let components = version.split(separator: ".")
        guard components.count > 2 else { return 0 }
        // Remove any pre-release suffix (e.g., "0-beta.1" -> "0")
        let patchString = String(components[2]).split(separator: "-").first ?? "0"
        return Int(patchString) ?? 0
    }

    /// Pre-release identifier if present (e.g., "beta.1", "rc.2")
    public static var preRelease: String? {
        let components = version.split(separator: "-")
        guard components.count > 1 else { return nil }
        return String(components.dropFirst().joined(separator: "-"))
    }

    /// Whether this is a pre-release version
    public static var isPreRelease: Bool {
        preRelease != nil
    }

    // MARK: - Build Information

    /// Git commit SHA (if available via build settings)
    public static let gitSHA: String? = {
        Bundle.main.infoDictionary?["GitCommitSHA"] as? String
    }()

    /// Build date (if available via build settings)
    public static let buildDate: String? = {
        Bundle.main.infoDictionary?["BuildDate"] as? String
    }()

    /// Short git SHA (first 7 characters)
    public static var shortGitSHA: String? {
        gitSHA.map { String($0.prefix(7)) }
    }

    // MARK: - App Information

    /// Application name
    public static let appName: String = {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "MacML"
    }()

    /// Bundle identifier
    public static let bundleIdentifier: String = {
        Bundle.main.bundleIdentifier ?? "com.macml.app"
    }()

    /// Copyright string
    public static let copyright: String = {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
    }()

    // MARK: - System Information

    /// macOS version
    public static var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    /// Whether running on Apple Silicon
    public static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// Architecture string
    public static var architecture: String {
        #if arch(arm64)
        return "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Unknown"
        #endif
    }

    // MARK: - User Agent

    /// User agent string for API requests
    public static var userAgent: String {
        "\(appName)/\(version) (macOS \(macOSVersion); \(architecture))"
    }

    // MARK: - Debug Information

    /// Comprehensive version info for debugging/about screens
    public static var debugInfo: String {
        var info = """
        \(appName) v\(fullVersion)
        Bundle ID: \(bundleIdentifier)
        Architecture: \(architecture)
        macOS: \(macOSVersion)
        """

        if let sha = shortGitSHA {
            info += "\nCommit: \(sha)"
        }

        if let date = buildDate {
            info += "\nBuilt: \(date)"
        }

        return info
    }

    // MARK: - Version Comparison

    /// Compare with another version string
    /// Returns: negative if self < other, 0 if equal, positive if self > other
    public static func compare(to other: String) -> Int {
        let selfComponents = version.split(separator: ".").compactMap { Int($0.split(separator: "-").first ?? "0") }
        let otherComponents = other.split(separator: ".").compactMap { Int($0.split(separator: "-").first ?? "0") }

        for i in 0..<max(selfComponents.count, otherComponents.count) {
            let selfValue = i < selfComponents.count ? selfComponents[i] : 0
            let otherValue = i < otherComponents.count ? otherComponents[i] : 0

            if selfValue != otherValue {
                return selfValue - otherValue
            }
        }

        return 0
    }

    /// Check if current version is at least the specified version
    public static func isAtLeast(_ minimumVersion: String) -> Bool {
        compare(to: minimumVersion) >= 0
    }
}

// MARK: - String Representation

extension AppVersion {
    /// String representation of the version
    public static var versionString: String {
        fullVersion
    }
}
