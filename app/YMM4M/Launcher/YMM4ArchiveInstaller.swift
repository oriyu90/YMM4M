import CryptoKit
import Foundation

public struct YMM4ReleaseCatalog: Codable, Sendable {
    public let schema: Int
    public let releases: [YMM4Release]

    public init(schema: Int, releases: [YMM4Release]) {
        self.schema = schema
        self.releases = releases
    }

    public static func load(from url: URL) throws -> Self {
        let catalog = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard catalog.schema == 1, !catalog.releases.isEmpty else {
            throw RuntimeError.unavailable("YMM4互換カタログの形式が対応外です。")
        }
        var ids = Set<String>()
        var archives = Set<String>()
        for release in catalog.releases {
            guard release.hasValidMetadata,
                  ids.insert(release.id).inserted,
                  archives.insert(release.archiveSha256).inserted else {
                throw RuntimeError.unavailable("YMM4互換カタログに無効または重複した項目があります。")
            }
        }
        return catalog
    }

    public func release(archiveSHA256: String) -> YMM4Release? {
        releases.first { $0.archiveSha256 == archiveSHA256.lowercased() }
    }

    public func release(executableSHA256: String) -> YMM4Release? {
        releases.first { $0.executableSha256 == executableSHA256.lowercased() }
    }
}

public struct YMM4Release: Codable, Equatable, Sendable {
    public let id: String
    public let displayVersion: String
    public let archiveSha256: String
    public let executableSha256: String
    public let executableRelativePath: String
    public let classification: YMM4CompatibilityClassification
    public let runtimeProfile: String
    public let notes: String

    public init(
        id: String,
        displayVersion: String,
        archiveSha256: String,
        executableSha256: String,
        executableRelativePath: String,
        classification: YMM4CompatibilityClassification,
        runtimeProfile: String,
        notes: String
    ) {
        self.id = id
        self.displayVersion = displayVersion
        self.archiveSha256 = archiveSha256
        self.executableSha256 = executableSha256
        self.executableRelativePath = executableRelativePath
        self.classification = classification
        self.runtimeProfile = runtimeProfile
        self.notes = notes
    }

    fileprivate var hasValidMetadata: Bool {
        id.range(of: "^[A-Za-z0-9][A-Za-z0-9._+-]*$", options: .regularExpression) != nil
            && archiveSha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
            && executableSha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
            && executableRelativePath == "YukkuriMovieMaker.exe"
            && !runtimeProfile.isEmpty
    }
}

public struct YMM4InstallationPaths: Equatable, Sendable {
    public let store: URL
    public let current: URL

    public init(store: URL) {
        self.store = store
        self.current = store.appendingPathComponent("current", isDirectory: true)
    }

    public static func defaults(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Self {
        Self(store: home.appendingPathComponent(
            "Library/Application Support/YMM4M/YMM4", isDirectory: true
        ))
    }
}

public struct YMM4InstalledRelease: Equatable, Sendable {
    public let release: YMM4Release
    public let executable: URL
    public let reusedExistingInstall: Bool
}

public enum YMM4ArchiveInstaller {
    private static let maximumArchiveBytes: UInt64 = 2 * 1_024 * 1_024 * 1_024
    private static let maximumExpandedBytes: UInt64 = 4 * 1_024 * 1_024 * 1_024
    private static let maximumEntries = 20_000

    public static func install(
        archive: URL,
        catalog: YMM4ReleaseCatalog,
        paths: YMM4InstallationPaths = .defaults()
    ) async throws -> YMM4InstalledRelease {
        try await Task.detached(priority: .userInitiated) {
            try installSynchronously(archive: archive, catalog: catalog, paths: paths)
        }.value
    }

    public static func archiveSHA256(at archive: URL) throws -> String {
        guard archive.isFileURL,
              FileManager.default.isReadableFile(atPath: archive.path),
              archive.pathExtension.lowercased() == "zip" else {
            throw RuntimeError.unavailable("公式YMM4のZIPファイルを選択してください。")
        }
        let values = try archive.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              let size = values.fileSize,
              size > 0,
              UInt64(size) <= maximumArchiveBytes else {
            throw RuntimeError.unavailable("YMM4 ZIPのサイズが安全上の上限を超えています。")
        }
        let data = try Data(contentsOf: archive, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func installSynchronously(
        archive: URL,
        catalog: YMM4ReleaseCatalog,
        paths: YMM4InstallationPaths
    ) throws -> YMM4InstalledRelease {
        let archiveHash = try archiveSHA256(at: archive)
        guard let release = catalog.release(archiveSHA256: archiveHash) else {
            throw RuntimeError.unavailable(
                "このYMM4 ZIPは未検証です。更新後のZIPは、互換性テストとカタログ更新が完了するまで導入しません。SHA-256: \(archiveHash)"
            )
        }
        guard release.classification == .knownCompatible else {
            throw RuntimeError.unavailable("このYMM4 ZIPはカタログ上で起動許可されていません。")
        }
        let archiveData = try Data(contentsOf: archive, options: .mappedIfSafe)
        try validateZIPStructure(archiveData)

        let manager = FileManager.default
        let versions = paths.store.appendingPathComponent("versions", isDirectory: true)
        let destination = versions.appendingPathComponent(release.id, isDirectory: true)
        try manager.createDirectory(
            at: versions,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        if manager.fileExists(atPath: destination.path) {
            _ = try verifiedExecutable(in: destination, release: release)
            _ = try VersionedDirectoryChannel.activate(store: paths.store, versionDirectory: destination)
            return YMM4InstalledRelease(
                release: release,
                executable: paths.current.appendingPathComponent(release.executableRelativePath),
                reusedExistingInstall: true
            )
        }

        let staging = versions.appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(
            at: staging,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        do {
            try run("/usr/bin/ditto", arguments: ["-x", "-k", "--noqtn", archive.path, staging.path])
            try validateExtractedTree(staging)
            _ = try verifiedExecutable(in: staging, release: release)
            let metadata = try JSONEncoder().encode(InstalledMetadata(
                schema: 1,
                releaseID: release.id,
                archiveSha256: release.archiveSha256,
                executableSha256: release.executableSha256,
                runtimeProfile: release.runtimeProfile
            ))
            try metadata.write(
                to: staging.appendingPathComponent("ymm4m-install.json"),
                options: [.atomic, .completeFileProtectionUnlessOpen]
            )
            try manager.moveItem(at: staging, to: destination)
        } catch {
            try? manager.removeItem(at: staging)
            throw error
        }
        _ = try VersionedDirectoryChannel.activate(store: paths.store, versionDirectory: destination)
        return YMM4InstalledRelease(
            release: release,
            executable: paths.current.appendingPathComponent(release.executableRelativePath),
            reusedExistingInstall: false
        )
    }

    private struct InstalledMetadata: Codable {
        let schema: Int
        let releaseID: String
        let archiveSha256: String
        let executableSha256: String
        let runtimeProfile: String
    }

    private static func verifiedExecutable(in root: URL, release: YMM4Release) throws -> URL {
        let executable = root.appendingPathComponent(release.executableRelativePath)
        let result = try YMM4CompatibilityPolicy.classify(executable: executable)
        guard result.sha256 == release.executableSha256 else {
            throw RuntimeError.unavailable("展開後のYMM4実行ファイルがhash検証に失敗しました。")
        }
        return executable
    }

    private static func validateExtractedTree(_ root: URL) throws {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw RuntimeError.unavailable("YMM4 ZIPの展開結果を検査できません。")
        }
        var count = 0
        var bytes: UInt64 = 0
        for case let url as URL in enumerator {
            count += 1
            guard count <= maximumEntries else {
                throw RuntimeError.unavailable("YMM4 ZIPのファイル数が安全上の上限を超えています。")
            }
            let values = try url.resourceValues(forKeys: [
                .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey,
            ])
            guard values.isSymbolicLink != true,
                  values.isRegularFile == true || values.isDirectory == true else {
                throw RuntimeError.unavailable("YMM4 ZIPに許可されないファイル種別が含まれています。")
            }
            if values.isRegularFile == true {
                bytes += UInt64(values.fileSize ?? 0)
                guard bytes <= maximumExpandedBytes else {
                    throw RuntimeError.unavailable("YMM4 ZIPの展開後サイズが安全上の上限を超えています。")
                }
            }
        }
    }

    private static func validateZIPStructure(_ data: Data) throws {
        func u16(_ offset: Int) throws -> UInt16 {
            guard offset >= 0, offset + 2 <= data.count else { throw invalidZIP() }
            return data.withUnsafeBytes {
                UInt16(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
            }
        }
        func u32(_ offset: Int) throws -> UInt32 {
            guard offset >= 0, offset + 4 <= data.count else { throw invalidZIP() }
            return data.withUnsafeBytes {
                UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
            }
        }
        let minimum = max(0, data.count - 65_557)
        guard data.count >= 22,
              let eocd = stride(from: data.count - 22, through: minimum, by: -1).first(where: {
                  (try? u32($0)) == 0x0605_4b50
              }) else { throw invalidZIP() }
        let entries = Int(try u16(eocd + 10))
        let centralSize = Int(try u32(eocd + 12))
        let centralOffset = Int(try u32(eocd + 16))
        guard entries > 0,
              entries <= maximumEntries,
              centralOffset >= 0,
              centralSize >= 0,
              centralOffset + centralSize <= eocd else { throw invalidZIP() }

        var offset = centralOffset
        var expanded: UInt64 = 0
        var names = Set<String>()
        for _ in 0..<entries {
            guard try u32(offset) == 0x0201_4b50 else { throw invalidZIP() }
            let flags = try u16(offset + 8)
            let uncompressed = try u32(offset + 24)
            let nameLength = Int(try u16(offset + 28))
            let extraLength = Int(try u16(offset + 30))
            let commentLength = Int(try u16(offset + 32))
            let externalAttributes = try u32(offset + 38)
            let localOffset = Int(try u32(offset + 42))
            guard flags & 0x0001 == 0,
                  uncompressed != UInt32.max,
                  nameLength > 0,
                  offset + 46 + nameLength + extraLength + commentLength <= data.count,
                  localOffset + 30 <= data.count,
                  try u32(localOffset) == 0x0403_4b50 else { throw invalidZIP() }
            let nameData = data[(offset + 46)..<(offset + 46 + nameLength)]
            guard let rawName = String(data: nameData, encoding: .utf8),
                  !rawName.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) else {
                throw invalidZIP()
            }
            let normalized = rawName.replacingOccurrences(of: "\\", with: "/")
            let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
            guard !normalized.hasPrefix("/"),
                  !normalized.hasPrefix("~"),
                  !parts.contains(".."),
                  !parts.dropLast().contains(where: { $0.isEmpty }),
                  names.insert(normalized.lowercased()).inserted else { throw invalidZIP() }
            let unixMode = UInt16((externalAttributes >> 16) & 0xffff)
            guard unixMode & 0xf000 != 0xa000 else { throw invalidZIP() }
            let localNameLength = Int(try u16(localOffset + 26))
            let localExtraLength = Int(try u16(localOffset + 28))
            guard localOffset + 30 + localNameLength + localExtraLength <= data.count,
                  localNameLength == nameLength,
                  data[(localOffset + 30)..<(localOffset + 30 + localNameLength)].elementsEqual(nameData) else {
                throw invalidZIP()
            }
            expanded += UInt64(uncompressed)
            guard expanded <= maximumExpandedBytes else { throw invalidZIP() }
            offset += 46 + nameLength + extraLength + commentLength
        }
        guard offset == centralOffset + centralSize else { throw invalidZIP() }
    }

    private static func invalidZIP() -> RuntimeError {
        .unavailable("YMM4 ZIPの構造が不正または安全上の制限を超えています。")
    }

    private static func run(_ executable: String, arguments: [String]) throws {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = [
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "LANG": "C",
        ]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            let message = String(decoding: output, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw RuntimeError.unavailable(message.isEmpty ? "YMM4 ZIPの展開に失敗しました。" : message)
        }
    }
}
