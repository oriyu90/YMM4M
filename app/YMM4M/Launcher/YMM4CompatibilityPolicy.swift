import CryptoKit
import Foundation

public enum YMM4CompatibilityClassification: String, Codable, Sendable {
    case knownCompatible
    case maintenanceCandidate
    case unknown
    case knownBroken
}

public struct YMM4CompatibilityResult: Equatable, Sendable {
    public let classification: YMM4CompatibilityClassification
    public let displayVersion: String?
    public let sha256: String
    public let requiredRuntimeProfile: String?
}

public struct YMM4CompatibilityPolicy: Sendable {
    // Add hashes only after public inventory and current-candidate evidence exist.
    public static let knownCompatibleExecutables = [
        "96d80e18c52f00f16b7568e96346e5f8dfa99b57b5a531e60ca0c645dda0a822": "4.55.1.1 Lite",
        "53153b7098d40ad41d3495a57757754f1681731f2c0eaeeee7e821a92a0c33bd": "4.55.1.1",
    ]

    // Add an entry only after a reproducible current-state failure is recorded.
    public static let knownBrokenExecutables: [String: String] = [:]

    public static func classify(
        executable: URL,
        catalog: YMM4ReleaseCatalog? = nil
    ) throws -> YMM4CompatibilityResult {
        guard executable.isFileURL, FileManager.default.isReadableFile(atPath: executable.path) else {
            throw RuntimeError.invalidExecutable(executable)
        }
        let data = try Data(contentsOf: executable, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let release = catalog?.release(executableSHA256: hash) {
            return YMM4CompatibilityResult(
                classification: release.classification,
                displayVersion: release.displayVersion,
                sha256: hash,
                requiredRuntimeProfile: release.runtimeProfile
            )
        }
        if let version = knownCompatibleExecutables[hash] {
            return YMM4CompatibilityResult(
                classification: .knownCompatible,
                displayVersion: version,
                sha256: hash,
                requiredRuntimeProfile: RuntimeSetupPaths.currentRuntimeProfile
            )
        }
        if let version = knownBrokenExecutables[hash] {
            return YMM4CompatibilityResult(
                classification: .knownBroken,
                displayVersion: version,
                sha256: hash,
                requiredRuntimeProfile: nil
            )
        }
        if let catalog,
           let managed = try YMM4ArchiveInstaller.classifyInstalledMaintenanceCandidate(
               executable: executable, catalog: catalog
           ) {
            return managed
        }
        return YMM4CompatibilityResult(
            classification: .unknown,
            displayVersion: nil,
            sha256: hash,
            requiredRuntimeProfile: nil
        )
    }
}
