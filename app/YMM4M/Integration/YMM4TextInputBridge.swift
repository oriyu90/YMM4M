import Foundation

public enum YMM4TextInputError: LocalizedError, Equatable {
    case emptyText
    case textTooLarge
    case invalidHostPath
    case temporaryFileCreationFailed

    public var errorDescription: String? {
        switch self {
        case .emptyText: "入力する文字がありません。"
        case .textTooLarge: "一度に入力できる文字データは64 KiBまでです。"
        case .invalidHostPath: "一時ファイルのパスをWine用に変換できません。"
        case .temporaryFileCreationFailed: "入力用の一時ファイルを安全に作成できませんでした。"
        }
    }
}

public struct YMM4TextInputBridge: Sendable {
    public static let maximumUTF8Bytes = 64 * 1024

    private let backend: RosettaWineBackend
    private let helperURL: URL
    private let temporaryDirectory: URL

    public init(
        backend: RosettaWineBackend = RosettaWineBackend(),
        helperURL: URL,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.backend = backend
        self.helperURL = helperURL
        self.temporaryDirectory = temporaryDirectory
    }

    public static func configured(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> YMM4TextInputBridge? {
        guard let helperPath = environment["YMM4M_TEXT_COMMIT_HELPER"], !helperPath.isEmpty else {
            return nil
        }
        return YMM4TextInputBridge(helperURL: URL(fileURLWithPath: helperPath))
    }

    public static func winePath(forHostURL url: URL) throws -> String {
        guard url.isFileURL else { throw YMM4TextInputError.invalidHostPath }
        let path = url.standardizedFileURL.path
        guard path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0") else {
            throw YMM4TextInputError.invalidHostPath
        }
        return "Z:" + path.replacingOccurrences(of: "/", with: "\\")
    }

    public func commit(_ text: String) async throws {
        guard !text.isEmpty else { throw YMM4TextInputError.emptyText }
        let data = Data(text.utf8)
        guard data.count <= Self.maximumUTF8Bytes else { throw YMM4TextInputError.textTooLarge }

        let temporaryURL = temporaryDirectory
            .appendingPathComponent("ymm4m-text-input-\(UUID().uuidString)")
            .appendingPathExtension("utf8")
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        guard FileManager.default.createFile(
            atPath: temporaryURL.path,
            contents: data,
            attributes: attributes
        ) else {
            throw YMM4TextInputError.temporaryFileCreationFailed
        }
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let winePath = try Self.winePath(forHostURL: temporaryURL)
        try await backend.runAuxiliary(
            executable: helperURL,
            arguments: ["--commit-file", winePath]
        )
    }
}
