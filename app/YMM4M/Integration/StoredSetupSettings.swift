import Foundation

public struct StoredSetupSettings: Equatable, Sendable {
    public enum Key {
        public static let runtimeRootPath = "runtimeRootPath"
        public static let winePrefixPath = "winePrefixPath"
        public static let ymm4ExecutablePath = "ymm4ExecutablePath"
        public static let ymm4ArchivePath = "ymm4ArchivePath"
        public static let mediaRootPath = "mediaRootPath"
    }

    public var runtimeRootPath: String
    public var winePrefixPath: String
    public var ymm4ExecutablePath: String
    public var ymm4ArchivePath: String
    public var mediaRootPath: String

    public init(
        runtimeRootPath: String = "",
        winePrefixPath: String = "",
        ymm4ExecutablePath: String = "",
        ymm4ArchivePath: String = "",
        mediaRootPath: String = ""
    ) {
        self.runtimeRootPath = runtimeRootPath
        self.winePrefixPath = winePrefixPath
        self.ymm4ExecutablePath = ymm4ExecutablePath
        self.ymm4ArchivePath = ymm4ArchivePath
        self.mediaRootPath = mediaRootPath
    }

    public init(defaults: UserDefaults) {
        self.init(
            runtimeRootPath: defaults.string(forKey: Key.runtimeRootPath) ?? "",
            winePrefixPath: defaults.string(forKey: Key.winePrefixPath) ?? "",
            ymm4ExecutablePath: defaults.string(forKey: Key.ymm4ExecutablePath) ?? "",
            ymm4ArchivePath: defaults.string(forKey: Key.ymm4ArchivePath) ?? "",
            mediaRootPath: defaults.string(forKey: Key.mediaRootPath) ?? ""
        )
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(runtimeRootPath, forKey: Key.runtimeRootPath)
        defaults.set(winePrefixPath, forKey: Key.winePrefixPath)
        defaults.set(ymm4ExecutablePath, forKey: Key.ymm4ExecutablePath)
        defaults.set(ymm4ArchivePath, forKey: Key.ymm4ArchivePath)
        defaults.set(mediaRootPath, forKey: Key.mediaRootPath)
    }

    public func migratingManagedPaths(
        home: URL,
        fileManager: FileManager = .default
    ) -> StoredSetupSettingsMigration {
        let applicationSupport = home
            .appendingPathComponent("Library/Application Support/YMM4M", isDirectory: true)
        let runtimeCurrent = applicationSupport
            .appendingPathComponent("Runtimes/current", isDirectory: true)
        let prefixCurrent = applicationSupport
            .appendingPathComponent("Prefixes/current", isDirectory: true)
        let ymm4Root = applicationSupport.appendingPathComponent("YMM4", isDirectory: true)
        let ymm4CurrentExecutable = ymm4Root
            .appendingPathComponent("current/YukkuriMovieMaker.exe")

        var migrated = self
        var needsRuntimeSetup = false
        var needsYMM4Setup = false

        let legacyRuntime = applicationSupport
            .appendingPathComponent("Runtimes/ymm4m-wine-11.0-dxmt", isDirectory: true)
        if samePath(runtimeRootPath, legacyRuntime.path) {
            if fileManager.fileExists(atPath: runtimeCurrent.path) {
                migrated.runtimeRootPath = runtimeCurrent.path
            } else {
                needsRuntimeSetup = true
            }
        }

        let legacyPrefix = applicationSupport
            .appendingPathComponent("Prefixes/YMM4", isDirectory: true)
        if samePath(winePrefixPath, legacyPrefix.path) {
            if fileManager.fileExists(atPath: prefixCurrent.path) {
                migrated.winePrefixPath = prefixCurrent.path
            } else {
                needsRuntimeSetup = true
            }
        }

        if isManagedYMM4Executable(ymm4ExecutablePath, root: ymm4Root) {
            if fileManager.isReadableFile(atPath: ymm4CurrentExecutable.path) {
                migrated.ymm4ExecutablePath = ymm4CurrentExecutable.path
            } else {
                needsYMM4Setup = true
            }
        }

        return StoredSetupSettingsMigration(
            settings: migrated,
            changed: migrated != self,
            needsRuntimeSetup: needsRuntimeSetup,
            needsYMM4Setup: needsYMM4Setup
        )
    }
}

public struct StoredSetupSettingsMigration: Equatable, Sendable {
    public let settings: StoredSetupSettings
    public let changed: Bool
    public let needsRuntimeSetup: Bool
    public let needsYMM4Setup: Bool
}

private func samePath(_ lhs: String, _ rhs: String) -> Bool {
    guard !lhs.isEmpty else { return false }
    return URL(fileURLWithPath: lhs).standardizedFileURL.path
        == URL(fileURLWithPath: rhs).standardizedFileURL.path
}

private func isManagedYMM4Executable(_ path: String, root: URL) -> Bool {
    guard !path.isEmpty else { return false }
    let standardized = URL(fileURLWithPath: path).standardizedFileURL
    guard standardized.lastPathComponent.caseInsensitiveCompare("YukkuriMovieMaker.exe") == .orderedSame
    else { return false }
    let rootPath = root.standardizedFileURL.path
    guard standardized.path.hasPrefix(rootPath + "/") else { return false }
    let relativePath = String(standardized.path.dropFirst(rootPath.count))
    return relativePath == "/lite-current/YukkuriMovieMaker.exe"
        || relativePath.hasPrefix("/versions/")
        || relativePath == "/current/YukkuriMovieMaker.exe"
}
