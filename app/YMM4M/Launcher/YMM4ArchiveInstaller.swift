import CryptoKit
import Foundation

public struct YMM4ReleaseCatalog: Codable, Sendable {
    public let schema: Int
    public let releases: [YMM4Release]
    public let maintenanceFamilies: [YMM4MaintenanceFamily]?

    public init(
        schema: Int,
        releases: [YMM4Release],
        maintenanceFamilies: [YMM4MaintenanceFamily]? = nil
    ) {
        self.schema = schema
        self.releases = releases
        self.maintenanceFamilies = maintenanceFamilies
    }

    public static func load(from url: URL) throws -> Self {
        let catalog = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard (catalog.schema == 1 || catalog.schema == 2), !catalog.releases.isEmpty else {
            throw RuntimeError.unavailable(CoreMessages.catalogUnsupportedFormat())
        }
        var ids = Set<String>()
        var archives = Set<String>()
        for release in catalog.releases {
            guard release.hasValidMetadata,
                  ids.insert(release.id).inserted,
                  archives.insert(release.archiveSha256).inserted else {
                throw RuntimeError.unavailable(CoreMessages.catalogInvalidEntries())
            }
        }
        if catalog.schema == 2 {
            guard catalog.releases.allSatisfy({ $0.edition != nil }),
                  !(catalog.maintenanceFamilies ?? []).isEmpty else {
                throw RuntimeError.unavailable(CoreMessages.catalogMissingMaintenancePolicy())
            }
            var familyIDs = Set<String>()
            for family in catalog.maintenanceFamilies ?? [] {
                guard family.hasValidMetadata,
                      familyIDs.insert(family.id).inserted else {
                    throw RuntimeError.unavailable(CoreMessages.maintenancePolicyInvalid())
                }
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

    public func maintenanceFamily(
        version: String,
        edition: YMM4Edition
    ) -> YMM4MaintenanceFamily? {
        (maintenanceFamilies ?? []).first { $0.accepts(version: version, edition: edition) }
    }
}

public enum YMM4Edition: String, Codable, CaseIterable, Sendable {
    case standard
    case lite
}

public struct YMM4RequiredFile: Codable, Equatable, Sendable {
    public let path: String
    public let sha256: String

    public init(path: String, sha256: String) {
        self.path = path
        self.sha256 = sha256
    }
}

public struct YMM4MaintenanceFamily: Codable, Equatable, Sendable {
    public let id: String
    public let versionPrefix: String
    public let testedThroughVersion: String
    public let editions: [YMM4Edition]
    public let runtimeProfile: String
    public let requiredFiles: [YMM4RequiredFile]
    public let notes: String

    public init(
        id: String,
        versionPrefix: String,
        testedThroughVersion: String,
        editions: [YMM4Edition],
        runtimeProfile: String,
        requiredFiles: [YMM4RequiredFile],
        notes: String
    ) {
        self.id = id
        self.versionPrefix = versionPrefix
        self.testedThroughVersion = testedThroughVersion
        self.editions = editions
        self.runtimeProfile = runtimeProfile
        self.requiredFiles = requiredFiles
        self.notes = notes
    }

    fileprivate var hasValidMetadata: Bool {
        id.range(of: "^[A-Za-z0-9][A-Za-z0-9._+-]*$", options: .regularExpression) != nil
            && Self.components(versionPrefix)?.count == 3
            && Self.components(testedThroughVersion)?.count == 4
            && testedThroughVersion.hasPrefix(versionPrefix + ".")
            && !editions.isEmpty
            && Set(editions).count == editions.count
            && !runtimeProfile.isEmpty
            && requiredFiles.count >= 5
            && Set(requiredFiles.map { $0.path.lowercased() }).count == requiredFiles.count
            && requiredFiles.allSatisfy {
                !$0.path.isEmpty
                    && !$0.path.hasPrefix("/")
                    && !$0.path.split(separator: "/").contains("..")
                    && $0.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
            }
    }

    public func accepts(version: String, edition: YMM4Edition) -> Bool {
        guard editions.contains(edition),
              let candidate = Self.components(version),
              let tested = Self.components(testedThroughVersion),
              candidate.count == 4,
              tested.count == 4,
              Array(candidate.prefix(3)) == Array(tested.prefix(3)) else { return false }
        return candidate.lexicographicallyPrecedes(tested) == false && candidate != tested
    }

    private static func components(_ version: String) -> [Int]? {
        let pieces = version.split(separator: ".", omittingEmptySubsequences: false)
        guard !pieces.isEmpty,
              pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else { return nil }
        return pieces.compactMap { Int($0) }
    }
}

public struct YMM4Release: Codable, Equatable, Sendable {
    public let id: String
    public let displayVersion: String
    public let archiveSha256: String
    public let executableSha256: String
    public let executableRelativePath: String
    public let edition: YMM4Edition?
    public let classification: YMM4CompatibilityClassification
    public let runtimeProfile: String
    public let notes: String

    public init(
        id: String,
        displayVersion: String,
        archiveSha256: String,
        executableSha256: String,
        executableRelativePath: String,
        edition: YMM4Edition? = nil,
        classification: YMM4CompatibilityClassification,
        runtimeProfile: String,
        notes: String
    ) {
        self.id = id
        self.displayVersion = displayVersion
        self.archiveSha256 = archiveSha256
        self.executableSha256 = executableSha256
        self.executableRelativePath = executableRelativePath
        self.edition = edition
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
            throw RuntimeError.unavailable(CoreMessages.archiveNotOfficialZIP())
        }
        let values = try archive.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              let size = values.fileSize,
              size > 0,
              UInt64(size) <= maximumArchiveBytes else {
            throw RuntimeError.unavailable(CoreMessages.archiveExceedsSizeLimit())
        }
        let data = try Data(contentsOf: archive, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func installMaintenanceCandidate(
        archive: URL,
        receipt: YMM4OfficialAssetReceipt,
        family: YMM4MaintenanceFamily,
        paths: YMM4InstallationPaths = .defaults()
    ) async throws -> YMM4InstalledRelease {
        try await Task.detached(priority: .userInitiated) {
            try installMaintenanceCandidateSynchronously(
                archive: archive, receipt: receipt, family: family, paths: paths
            )
        }.value
    }

    public static func rollback(
        catalog: YMM4ReleaseCatalog,
        paths: YMM4InstallationPaths = .defaults()
    ) throws -> URL {
        let manager = FileManager.default
        let previous = paths.store.appendingPathComponent("previous")
        guard (try? manager.attributesOfItem(atPath: previous.path)[.type] as? FileAttributeType)
                == .typeSymbolicLink else {
            throw RuntimeError.unavailable(CoreMessages.noPreviousYMM4())
        }
        let previousTarget = previous.resolvingSymlinksInPath()
        let currentTarget = paths.current.resolvingSymlinksInPath()
        let previousExecutable = previousTarget.appendingPathComponent("YukkuriMovieMaker.exe")
        let previousHash = try sha256(of: previousExecutable)
        let exactRelease = catalog.release(executableSHA256: previousHash)
        let maintenance = try classifyInstalledMaintenanceCandidate(
            executable: previousExecutable, catalog: catalog, paths: paths
        )
        guard exactRelease?.classification == .knownCompatible
                || maintenance?.classification == .maintenanceCandidate else {
            throw RuntimeError.unavailable(CoreMessages.previousYMM4FailsCatalog())
        }
        _ = try VersionedDirectoryChannel.activate(store: paths.store, versionDirectory: previousTarget)
        if currentTarget != paths.current,
           currentTarget.deletingLastPathComponent().lastPathComponent == "versions" {
            _ = try VersionedDirectoryChannel.activate(
                store: paths.store, versionDirectory: currentTarget, channelName: "previous"
            )
        }
        let executable = paths.current.appendingPathComponent("YukkuriMovieMaker.exe")
        guard manager.isReadableFile(atPath: executable.path) else {
            throw RuntimeError.unavailable(CoreMessages.rolledBackExecutableUnverifiable())
        }
        return executable
    }

    private static func installSynchronously(
        archive: URL,
        catalog: YMM4ReleaseCatalog,
        paths: YMM4InstallationPaths
    ) throws -> YMM4InstalledRelease {
        let archiveHash = try archiveSHA256(at: archive)
        guard let release = catalog.release(archiveSHA256: archiveHash) else {
            throw RuntimeError.unavailable(
                CoreMessages.archiveUnverified(archiveHash)
            )
        }
        guard release.classification == .knownCompatible else {
            throw RuntimeError.unavailable(CoreMessages.archiveLaunchForbidden())
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
            do {
                _ = try verifiedExecutable(in: destination, release: release)
            } catch {
                _ = try retainForRecovery(
                    destination, store: paths.store, label: "incomplete-\(release.id)"
                )
            }
        }
        try recoverInvalidCurrentChannelIfNeeded(store: paths.store)

        if manager.fileExists(atPath: destination.path) {
            if let edition = release.edition {
                try attachSharedUserData(to: destination, store: paths.store, edition: edition)
            }
            try activateWithRollback(store: paths.store, destination: destination)
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
            if let edition = release.edition {
                try attachSharedUserData(to: staging, store: paths.store, edition: edition)
            }
            let metadata = try JSONEncoder().encode(InstalledMetadata(
                schema: 1,
                releaseID: release.id,
                archiveSha256: release.archiveSha256,
                executableSha256: release.executableSha256,
                runtimeProfile: release.runtimeProfile,
                classification: nil,
                version: nil,
                edition: nil,
                familyID: nil,
                sourceRepository: nil,
                sourceTag: nil,
                sourceAsset: nil
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
        try activateWithRollback(store: paths.store, destination: destination)
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
        let classification: YMM4CompatibilityClassification?
        let version: String?
        let edition: YMM4Edition?
        let familyID: String?
        let sourceRepository: String?
        let sourceTag: String?
        let sourceAsset: String?
    }

    public static func classifyInstalledMaintenanceCandidate(
        executable: URL,
        catalog: YMM4ReleaseCatalog,
        paths: YMM4InstallationPaths = .defaults()
    ) throws -> YMM4CompatibilityResult? {
        let resolvedExecutable = executable.standardizedFileURL.resolvingSymlinksInPath()
        let versions = paths.store.standardizedFileURL.resolvingSymlinksInPath()
            .appendingPathComponent("versions", isDirectory: true)
        let root = resolvedExecutable.deletingLastPathComponent()
        guard root.deletingLastPathComponent() == versions else { return nil }
        let metadataURL = root.appendingPathComponent("ymm4m-install.json")
        guard FileManager.default.isReadableFile(atPath: metadataURL.path) else { return nil }
        let metadata = try JSONDecoder().decode(
            InstalledMetadata.self, from: Data(contentsOf: metadataURL)
        )
        guard metadata.schema == 2,
              metadata.classification == .maintenanceCandidate,
              metadata.sourceRepository == "manju-summoner/YukkuriMovieMaker4",
              let version = metadata.version,
              let edition = metadata.edition,
              let familyID = metadata.familyID,
              let family = catalog.maintenanceFamily(version: version, edition: edition),
              family.id == familyID,
              metadata.runtimeProfile == family.runtimeProfile,
              metadata.sourceTag == "v\(version)",
              metadata.sourceAsset == officialAssetName(version: version, edition: edition),
              metadata.archiveSha256.range(
                of: "^[0-9a-f]{64}$", options: .regularExpression
              ) != nil,
              metadata.releaseID == root.lastPathComponent,
              metadata.releaseID == "\(version)-\(edition == .lite ? "Lite" : "Standard")-official-\(metadata.archiveSha256.prefix(12))"
        else {
            return nil
        }
        try verifyWindowsGUIAMD64(resolvedExecutable)
        let executableHash = try sha256(of: resolvedExecutable)
        guard executableHash == metadata.executableSha256 else { return nil }
        try verifyRequiredFiles(in: root, family: family)
        return YMM4CompatibilityResult(
            classification: .maintenanceCandidate,
            displayVersion: version + (edition == .lite ? " Lite" : ""),
            sha256: executableHash,
            requiredRuntimeProfile: family.runtimeProfile
        )
    }

    private static func installMaintenanceCandidateSynchronously(
        archive: URL,
        receipt: YMM4OfficialAssetReceipt,
        family: YMM4MaintenanceFamily,
        paths: YMM4InstallationPaths
    ) throws -> YMM4InstalledRelease {
        guard receipt.sourceRepository == "manju-summoner/YukkuriMovieMaker4",
              receipt.tag == "v\(receipt.version)",
              receipt.assetName == officialAssetName(version: receipt.version, edition: receipt.edition),
              family.hasValidMetadata,
              family.accepts(version: receipt.version, edition: receipt.edition),
              try archiveSHA256(at: archive) == receipt.archiveSha256,
              Int64(try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1)
                == receipt.assetSize else {
            throw RuntimeError.unavailable(CoreMessages.maintenanceReceiptMismatch())
        }
        let archiveData = try Data(contentsOf: archive, options: .mappedIfSafe)
        try validateZIPStructure(archiveData)
        let manager = FileManager.default
        let versions = paths.store.appendingPathComponent("versions", isDirectory: true)
        try manager.createDirectory(
            at: versions, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        let editionSuffix = receipt.edition == .lite ? "Lite" : "Standard"
        let releaseID = "\(receipt.version)-\(editionSuffix)-official-\(receipt.archiveSha256.prefix(12))"
        let destination = versions.appendingPathComponent(releaseID, isDirectory: true)
        var release: YMM4Release?
        var reused = false
        if manager.fileExists(atPath: destination.path) {
            let result = try? classifyInstalledMaintenanceCandidate(
                executable: destination.appendingPathComponent("YukkuriMovieMaker.exe"),
                catalog: YMM4ReleaseCatalog(
                    schema: 2, releases: [placeholderRelease()], maintenanceFamilies: [family]
                ),
                paths: paths
            )
            if let result {
                release = YMM4Release(
                    id: releaseID,
                    displayVersion: result.displayVersion ?? receipt.version,
                    archiveSha256: receipt.archiveSha256,
                    executableSha256: result.sha256,
                    executableRelativePath: "YukkuriMovieMaker.exe",
                    edition: receipt.edition,
                    classification: .maintenanceCandidate,
                    runtimeProfile: family.runtimeProfile,
                    notes: family.notes
                )
                try attachSharedUserData(
                    to: destination, store: paths.store, edition: receipt.edition
                )
                reused = true
            } else {
                _ = try retainForRecovery(
                    destination, store: paths.store, label: "incomplete-\(releaseID)"
                )
            }
        }
        try recoverInvalidCurrentChannelIfNeeded(store: paths.store)
        if !manager.fileExists(atPath: destination.path) {
            let staging = versions.appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
            try manager.createDirectory(
                at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]
            )
            do {
                try run("/usr/bin/ditto", arguments: ["-x", "-k", "--noqtn", archive.path, staging.path])
                try validateExtractedTree(staging)
                try verifyRequiredFiles(in: staging, family: family)
                let executable = staging.appendingPathComponent("YukkuriMovieMaker.exe")
                try verifyWindowsGUIAMD64(executable)
                let executableHash = try sha256(of: executable)
                release = YMM4Release(
                    id: releaseID,
                    displayVersion: receipt.version + (receipt.edition == .lite ? " Lite" : ""),
                    archiveSha256: receipt.archiveSha256,
                    executableSha256: executableHash,
                    executableRelativePath: "YukkuriMovieMaker.exe",
                    edition: receipt.edition,
                    classification: .maintenanceCandidate,
                    runtimeProfile: family.runtimeProfile,
                    notes: family.notes
                )
                let metadata = try JSONEncoder().encode(InstalledMetadata(
                    schema: 2,
                    releaseID: releaseID,
                    archiveSha256: receipt.archiveSha256,
                    executableSha256: executableHash,
                    runtimeProfile: family.runtimeProfile,
                    classification: .maintenanceCandidate,
                    version: receipt.version,
                    edition: receipt.edition,
                    familyID: family.id,
                    sourceRepository: receipt.sourceRepository,
                    sourceTag: receipt.tag,
                    sourceAsset: receipt.assetName
                ))
                try metadata.write(
                    to: staging.appendingPathComponent("ymm4m-install.json"),
                    options: [.atomic, .completeFileProtectionUnlessOpen]
                )
                try attachSharedUserData(
                    to: staging, store: paths.store, edition: receipt.edition
                )
                try manager.moveItem(at: staging, to: destination)
            } catch {
                try? manager.removeItem(at: staging)
                throw error
            }
        }
        try activateWithRollback(store: paths.store, destination: destination)
        guard let release else {
            throw RuntimeError.unavailable(CoreMessages.maintenanceCompletionFailed())
        }
        return YMM4InstalledRelease(
            release: release,
            executable: paths.current.appendingPathComponent("YukkuriMovieMaker.exe"),
            reusedExistingInstall: reused
        )
    }

    private static func activateWithRollback(store: URL, destination: URL) throws {
        let current = store.appendingPathComponent("current")
        if (try? FileManager.default.attributesOfItem(atPath: current.path)[.type] as? FileAttributeType)
            == .typeSymbolicLink {
            let oldTarget = current.resolvingSymlinksInPath()
            if oldTarget != destination,
               oldTarget.deletingLastPathComponent().lastPathComponent == "versions" {
                _ = try VersionedDirectoryChannel.activate(
                    store: store, versionDirectory: oldTarget, channelName: "previous"
                )
            }
        }
        _ = try VersionedDirectoryChannel.activate(store: store, versionDirectory: destination)
    }

    private static func recoverInvalidCurrentChannelIfNeeded(store: URL) throws {
        let manager = FileManager.default
        let current = store.appendingPathComponent("current")
        guard pathEntryExists(current, manager: manager) else { return }
        let attributes = try manager.attributesOfItem(atPath: current.path)
        if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
            let destination = try manager.destinationOfSymbolicLink(atPath: current.path)
            let target = destination.hasPrefix("/")
                ? URL(fileURLWithPath: destination)
                : store.appendingPathComponent(destination).standardizedFileURL
            let versionsPath = store.standardizedFileURL
                .appendingPathComponent("versions", isDirectory: true).path + "/"
            guard target.standardizedFileURL.path.hasPrefix(versionsPath) else {
                throw RuntimeError.unavailable(CoreMessages.ymm4ChannelOutsideStore())
            }
            if manager.fileExists(atPath: target.path) { return }
        }
        _ = try retainForRecovery(current, store: store, label: "incomplete-current")
    }

    private static func retainForRecovery(_ item: URL, store: URL, label: String) throws -> URL {
        let manager = FileManager.default
        let recovery = store.appendingPathComponent("Recovery", isDirectory: true)
        try prepareRecoveryDirectory(recovery, store: store, manager: manager)
        let retained = recovery.appendingPathComponent(
            "\(label)-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-"))-\(UUID().uuidString)"
        )
        try manager.moveItem(at: item, to: retained)
        return retained
    }

    private static func prepareRecoveryDirectory(
        _ recovery: URL,
        store: URL,
        manager: FileManager
    ) throws {
        if pathEntryExists(recovery, manager: manager) {
            let attributes = try manager.attributesOfItem(atPath: recovery.path)
            guard attributes[.type] as? FileAttributeType == .typeDirectory else {
                throw RuntimeError.unavailable(CoreMessages.ymm4RecoveryNotDirectory())
            }
        } else {
            try manager.createDirectory(
                at: recovery, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        guard recovery.resolvingSymlinksInPath().deletingLastPathComponent()
                == store.resolvingSymlinksInPath() else {
            throw RuntimeError.unavailable(CoreMessages.ymm4RecoveryOutsideStore())
        }
    }

    private static func pathEntryExists(_ url: URL, manager: FileManager) -> Bool {
        manager.fileExists(atPath: url.path)
            || (try? manager.attributesOfItem(atPath: url.path)) != nil
    }

    private static func verifyRequiredFiles(in root: URL, family: YMM4MaintenanceFamily) throws {
        for required in family.requiredFiles {
            let file = root.appendingPathComponent(required.path)
            guard try sha256(of: file) == required.sha256 else {
                throw RuntimeError.unavailable(CoreMessages.maintenanceBoundaryMismatch(required.path))
            }
        }
    }

    private static func sha256(of file: URL) throws -> String {
        guard FileManager.default.isReadableFile(atPath: file.path) else {
            throw RuntimeError.unavailable(CoreMessages.distributionFileMissing(file.lastPathComponent))
        }
        let data = try Data(contentsOf: file, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func verifyWindowsGUIAMD64(_ executable: URL) throws {
        let data = try Data(contentsOf: executable, options: .mappedIfSafe)
        func u16(_ offset: Int) -> UInt16? {
            guard offset >= 0, offset + 2 <= data.count else { return nil }
            return data.withUnsafeBytes {
                UInt16(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
            }
        }
        func u32(_ offset: Int) -> UInt32? {
            guard offset >= 0, offset + 4 <= data.count else { return nil }
            return data.withUnsafeBytes {
                UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
            }
        }
        guard u16(0) == 0x5a4d,
              let peOffsetValue = u32(0x3c),
              Int(peOffsetValue) + 92 <= data.count else {
            throw RuntimeError.unavailable(CoreMessages.candidateNotValidPE())
        }
        let peOffset = Int(peOffsetValue)
        guard u32(peOffset) == 0x0000_4550,
              u16(peOffset + 4) == 0x8664,
              u16(peOffset + 24) == 0x020b,
              u16(peOffset + 24 + 68) == 2 else {
            throw RuntimeError.unavailable(CoreMessages.candidateNotAMD64GUI())
        }
    }

    private static func officialAssetName(version: String, edition: YMM4Edition) -> String {
        "YukkuriMovieMaker_v\(version)\(edition == .lite ? "_Lite" : "").zip"
    }

    private static func placeholderRelease() -> YMM4Release {
        YMM4Release(
            id: "placeholder", displayVersion: "placeholder",
            archiveSha256: String(repeating: "0", count: 64),
            executableSha256: String(repeating: "0", count: 64),
            executableRelativePath: "YukkuriMovieMaker.exe", classification: .unknown,
            runtimeProfile: "placeholder", notes: "internal validation placeholder"
        )
    }

    private static func attachSharedUserData(
        to versionRoot: URL,
        store: URL,
        edition: YMM4Edition
    ) throws {
        let manager = FileManager.default
        let sharedParent = store.appendingPathComponent("user-data", isDirectory: true)
        let shared = sharedParent.appendingPathComponent(edition.rawValue, isDirectory: true)
        try manager.createDirectory(
            at: sharedParent, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        var copiedFromLocal = false
        if !manager.fileExists(atPath: shared.path) {
            let legacy = store.appendingPathComponent(
                edition == .lite ? "lite-current/user" : "standard-current/user",
                isDirectory: true
            )
            let local = versionRoot.appendingPathComponent("user", isDirectory: true)
            let source = isDirectory(local) ? local : (isDirectory(legacy) ? legacy : nil)
            if let source {
                copiedFromLocal = source.standardizedFileURL == local.standardizedFileURL
                let staging = store.appendingPathComponent(".user-data-\(UUID().uuidString)")
                do {
                    try manager.copyItem(at: source, to: staging)
                    try manager.moveItem(at: staging, to: shared)
                } catch {
                    try? manager.removeItem(at: staging)
                    throw error
                }
            } else {
                try manager.createDirectory(
                    at: shared, withIntermediateDirectories: false,
                    attributes: [.posixPermissions: 0o700]
                )
            }
        }

        let user = versionRoot.appendingPathComponent("user")
        if let attributes = try? manager.attributesOfItem(atPath: user.path),
           attributes[.type] as? FileAttributeType == .typeSymbolicLink {
            guard user.resolvingSymlinksInPath() == shared.resolvingSymlinksInPath() else {
                throw RuntimeError.unavailable(CoreMessages.userDataLinkElsewhere())
            }
            return
        }
        if isDirectory(user) {
            let entries = try manager.contentsOfDirectory(atPath: user.path)
            if !entries.isEmpty {
                let sharedEntries = try manager.contentsOfDirectory(atPath: shared.path)
                guard copiedFromLocal || sharedEntries.isEmpty
                else {
                    throw RuntimeError.unavailable(CoreMessages.userDataDuplicated())
                }
            }
            let retained = versionRoot.appendingPathComponent("user.pre-shared-\(UUID().uuidString)")
            try manager.moveItem(at: user, to: retained)
        } else if manager.fileExists(atPath: user.path) {
            throw RuntimeError.unavailable(CoreMessages.userPathNotDirectory())
        }
        try manager.createSymbolicLink(
            atPath: user.path,
            withDestinationPath: "../../user-data/\(edition.rawValue)"
        )
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var value: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &value) && value.boolValue
    }

    private static func verifiedExecutable(in root: URL, release: YMM4Release) throws -> URL {
        let executable = root.appendingPathComponent(release.executableRelativePath)
        let result = try YMM4CompatibilityPolicy.classify(executable: executable)
        guard result.sha256 == release.executableSha256 else {
            throw RuntimeError.unavailable(CoreMessages.extractedExecutableHashFailed())
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
            throw RuntimeError.unavailable(CoreMessages.archiveExtractionUninspectable())
        }
        var count = 0
        var bytes: UInt64 = 0
        for case let url as URL in enumerator {
            count += 1
            guard count <= maximumEntries else {
                throw RuntimeError.unavailable(CoreMessages.archiveFileCountExceeded())
            }
            let values = try url.resourceValues(forKeys: [
                .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey,
            ])
            guard values.isSymbolicLink != true,
                  values.isRegularFile == true || values.isDirectory == true else {
                throw RuntimeError.unavailable(CoreMessages.archiveForbiddenFileType())
            }
            if values.isRegularFile == true {
                bytes += UInt64(values.fileSize ?? 0)
                guard bytes <= maximumExpandedBytes else {
                    throw RuntimeError.unavailable(CoreMessages.archiveExpandedSizeExceeded())
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
        .unavailable(CoreMessages.archiveStructureInvalid())
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
            throw RuntimeError.unavailable(message.isEmpty ? CoreMessages.archiveExtractionFailed() : message)
        }
    }
}
