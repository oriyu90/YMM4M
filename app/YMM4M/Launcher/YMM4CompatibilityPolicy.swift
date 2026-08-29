import CryptoKit
import Foundation

public enum YMM4CompatibilityClassification: String, Codable, Sendable {
    case knownCompatible
    case unknown
    case knownBroken
}

public struct YMM4CompatibilityResult: Equatable, Sendable {
    public let classification: YMM4CompatibilityClassification
    public let displayVersion: String?
    public let sha256: String
}

public struct YMM4CompatibilityPolicy: Sendable {
    // This is the public-inventory hash pinned by runtime.lock.json.
    public static let knownCompatibleExecutables = [
        "96d80e18c52f00f16b7568e96346e5f8dfa99b57b5a531e60ca0c645dda0a822": "4.55.1.1 Lite",
    ]

    // Add an entry only after a reproducible current-state failure is recorded.
    public static let knownBrokenExecutables: [String: String] = [:]

    public static func classify(executable: URL) throws -> YMM4CompatibilityResult {
        guard executable.isFileURL, FileManager.default.isReadableFile(atPath: executable.path) else {
            throw RuntimeError.invalidExecutable(executable)
        }
        let data = try Data(contentsOf: executable, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let version = knownCompatibleExecutables[hash] {
            return YMM4CompatibilityResult(
                classification: .knownCompatible,
                displayVersion: version,
                sha256: hash
            )
        }
        if let version = knownBrokenExecutables[hash] {
            return YMM4CompatibilityResult(
                classification: .knownBroken,
                displayVersion: version,
                sha256: hash
            )
        }
        return YMM4CompatibilityResult(classification: .unknown, displayVersion: nil, sha256: hash)
    }
}
