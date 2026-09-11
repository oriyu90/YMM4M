import Foundation

public enum RuntimeSupportLevel: String, Codable, Sendable {
    case productionCandidate
    case research
    case unavailable
}

public struct RuntimeProbeResult: Codable, Equatable, Sendable {
    public let available: Bool
    public let architecture: String
    public let runtimePath: String?
    public let reason: String

    public init(available: Bool, architecture: String, runtimePath: String?, reason: String) {
        self.available = available
        self.architecture = architecture
        self.runtimePath = runtimePath
        self.reason = reason
    }
}

public struct RuntimeProcessHandle: Equatable, Sendable {
    public let processIdentifier: Int32
}

public struct RuntimeDiagnostics: Codable, Equatable, Sendable {
    public let backend: String
    public let probe: RuntimeProbeResult
    public let collectedAt: Date
}

public protocol RuntimeBackend: Sendable {
    var identifier: String { get }
    var supportLevel: RuntimeSupportLevel { get }
    func probe() async throws -> RuntimeProbeResult
    func prepare() async throws
    func launch(executable: URL, arguments: [String]) async throws -> RuntimeProcessHandle
    func terminate() async throws
    func collectDiagnostics() async throws -> RuntimeDiagnostics
}

public enum RuntimeError: LocalizedError {
    case unavailable(String)
    case invalidExecutable(URL)
    case processFailed(Int32)
    case processTimedOut

    public func message(for language: CoreLanguage) -> String {
        switch self {
        case .unavailable(let reason):
            // Already localized at the throw site via CoreMessages.
            return reason
        case .invalidExecutable(let url):
            switch language {
            case .japanese: return "実行ファイルが見つかりません: \(url.path)"
            case .english: return "Executable not found: \(url.path)"
            }
        case .processFailed(let status):
            switch language {
            case .japanese: return "Windows補助処理が終了コード \(status) で失敗しました。"
            case .english: return "Windows helper process failed with exit code \(status)."
            }
        case .processTimedOut:
            switch language {
            case .japanese: return "Windows補助処理が10秒以内に完了しませんでした。"
            case .english: return "Windows helper process did not finish within 10 seconds."
            }
        }
    }

    public var errorDescription: String? {
        message(for: CoreLanguage.current)
    }
}
