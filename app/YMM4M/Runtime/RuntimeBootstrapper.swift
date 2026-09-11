import Foundation

public struct RuntimeSetupPaths: Sendable, Equatable {
    public static let currentRuntimeProfile = "wine-11.0-dxmt-e55ad281-patchset5"
    public static let currentPrefixSchema = 2

    public let runtimeRoot: URL
    public let prefix: URL
    public let runtimeInstallRoot: URL
    public let prefixInstallRoot: URL
    public let runtimeStore: URL?
    public let prefixStore: URL?
    public let runtimeProfile: String

    public init(runtimeRoot: URL, prefix: URL) {
        self.runtimeRoot = runtimeRoot
        self.prefix = prefix
        self.runtimeInstallRoot = runtimeRoot
        self.prefixInstallRoot = prefix
        self.runtimeStore = nil
        self.prefixStore = nil
        self.runtimeProfile = Self.currentRuntimeProfile
    }

    public static func defaults(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Self {
        let support = home.appendingPathComponent("Library/Application Support/YMM4M", isDirectory: true)
        return versionedStore(
            runtimeStore: support.appendingPathComponent("Runtimes", isDirectory: true),
            prefixStore: support.appendingPathComponent("Prefixes", isDirectory: true)
        )
    }

    /// Same versioned `versions/<profile>` + atomic `current` layout as
    /// `defaults()`, but rooted at developer-selected folders. The automatic
    /// installer can populate these exactly like the standard location.
    public static func custom(runtimeStore: URL, prefixStore: URL) -> Self {
        versionedStore(
            runtimeStore: runtimeStore.standardizedFileURL,
            prefixStore: prefixStore.standardizedFileURL
        )
    }

    private static func versionedStore(runtimeStore: URL, prefixStore: URL) -> Self {
        let runtimeInstall = runtimeStore.appendingPathComponent(
            "versions/\(currentRuntimeProfile)", isDirectory: true
        )
        let prefixID = "\(currentRuntimeProfile)-prefix-v\(currentPrefixSchema)"
        let prefixInstall = prefixStore.appendingPathComponent("versions/\(prefixID)", isDirectory: true)
        return Self(
            runtimeRoot: runtimeStore.appendingPathComponent("current", isDirectory: true),
            prefix: prefixStore.appendingPathComponent("current", isDirectory: true),
            runtimeInstallRoot: runtimeInstall,
            prefixInstallRoot: prefixInstall,
            runtimeStore: runtimeStore,
            prefixStore: prefixStore,
            runtimeProfile: currentRuntimeProfile
        )
    }

    private init(
        runtimeRoot: URL,
        prefix: URL,
        runtimeInstallRoot: URL,
        prefixInstallRoot: URL,
        runtimeStore: URL?,
        prefixStore: URL?,
        runtimeProfile: String
    ) {
        self.runtimeRoot = runtimeRoot
        self.prefix = prefix
        self.runtimeInstallRoot = runtimeInstallRoot
        self.prefixInstallRoot = prefixInstallRoot
        self.runtimeStore = runtimeStore
        self.prefixStore = prefixStore
        self.runtimeProfile = runtimeProfile
    }
}

public enum RuntimeBootstrapper {
    public static func install(
        paths: RuntimeSetupPaths = .defaults(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        progress: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let recovered = try recoverIncompleteManagedState(paths)
            for item in recovered {
                progress("[repair] \(item)")
            }
            if try migrateLegacyPairIfAvailable(paths) {
                return CoreMessages.setupMigratedLegacyPair()
            }
            if runtimeIsReady(paths.runtimeRoot),
               prefixIsReady(paths.prefix),
               pairIsCompatible(runtimeRoot: paths.runtimeRoot, prefix: paths.prefix,
                                expectedProfile: paths.runtimeProfile) {
                try RosettaWineBackend.validateCleanRuntime(at: paths.runtimeRoot)
                return CoreMessages.setupReusesVerifiedPair()
            }

            let resources = try resources(environment: environment)
            let logURL = try prepareSetupLog(paths: paths)
            progress(CoreMessages.setupStarted())
            let runtimeReady = runtimeIsReady(paths.runtimeInstallRoot)
            var output: String
            if runtimeReady {
                try RosettaWineBackend.validateCleanRuntime(at: paths.runtimeInstallRoot)
                if !prefixIsReady(paths.prefixInstallRoot) {
                    output = try run(
                        executable: resources.setupPrefix,
                        arguments: [],
                        environment: bootstrapEnvironment(inherited: environment).merging([
                            "YMM4M_WINE": paths.runtimeInstallRoot.appendingPathComponent("bin/wine").path,
                            "YMM4M_PREFIX": paths.prefixInstallRoot.path,
                            "YMM4M_BOOTSTRAP_LOCK": resources.lock.path,
                        ]) { _, new in new },
                        progress: progress,
                        logURL: logURL
                    )
                } else {
                    output = CoreMessages.setupReusedVersionedPair()
                }
            } else {
                output = try run(
                    executable: resources.bootstrap,
                    arguments: [
                        "--accept-third-party",
                        "--runtime", paths.runtimeInstallRoot.path,
                        "--prefix", paths.prefixInstallRoot.path,
                    ],
                    environment: bootstrapEnvironment(inherited: environment).merging([
                        "YMM4M_BOOTSTRAP_LOCK": resources.lock.path,
                        "YMM4M_PROJECT_RESOURCES": resources.projectResources.path,
                    ]) { _, new in new },
                    progress: progress,
                    logURL: logURL
                )
            }
            try RosettaWineBackend.validateCleanRuntime(at: paths.runtimeInstallRoot)
            guard prefixIsReady(paths.prefixInstallRoot) else {
                throw RuntimeError.unavailable(CoreMessages.setupPrefixReadinessFailed())
            }
            try writeBinding(prefix: paths.prefixInstallRoot, runtimeProfile: paths.runtimeProfile)
            try activateVersionedPaths(paths)
            progress(CoreMessages.setupCompleted())
            return output + "\n" + CoreMessages.setupActivatedSuffix()
        }.value
    }

    public static func validateActivePair(_ paths: RuntimeSetupPaths) throws {
        guard runtimeIsReady(paths.runtimeRoot), prefixIsReady(paths.prefix) else {
            throw RuntimeError.unavailable(CoreMessages.activePairNotReady())
        }
        if paths.runtimeStore != nil,
           !pairIsCompatible(runtimeRoot: paths.runtimeRoot, prefix: paths.prefix,
                             expectedProfile: paths.runtimeProfile) {
            throw RuntimeError.unavailable(CoreMessages.activePairMismatch())
        }
    }

    /// Moves only invalid entries at YMM4M's versioned destinations into a
    /// recoverable holding area. Valid active/older versions are never removed.
    @discardableResult
    public static func recoverIncompleteManagedState(
        _ paths: RuntimeSetupPaths,
        fileManager manager: FileManager = .default
    ) throws -> [String] {
        guard let runtimeStore = paths.runtimeStore, let prefixStore = paths.prefixStore else {
            return []
        }
        try validateManagedPath(paths.runtimeInstallRoot, store: runtimeStore)
        try validateManagedPath(paths.prefixInstallRoot, store: prefixStore)

        var recovered: [String] = []
        if pathEntryExists(paths.runtimeInstallRoot, manager: manager) {
            let valid = runtimeIsReady(paths.runtimeInstallRoot)
                && (try? RosettaWineBackend.validateCleanRuntime(at: paths.runtimeInstallRoot)) != nil
            if !valid {
                let retained = try retainForRecovery(
                    paths.runtimeInstallRoot, store: runtimeStore, label: "runtime", manager: manager
                )
                recovered.append(CoreMessages.recoveredIncompleteRuntime(retained.path))
            }
        }

        if pathEntryExists(paths.prefixInstallRoot, manager: manager) {
            let valid = prefixIsReady(paths.prefixInstallRoot)
                && pairIsCompatible(
                    runtimeRoot: paths.runtimeInstallRoot,
                    prefix: paths.prefixInstallRoot,
                    expectedProfile: paths.runtimeProfile
                )
            if !valid {
                let retained = try retainForRecovery(
                    paths.prefixInstallRoot, store: prefixStore, label: "prefix", manager: manager
                )
                recovered.append(CoreMessages.recoveredIncompletePrefix(retained.path))
            }
        }

        try recoverInvalidChannelIfNeeded(
            store: runtimeStore, channelName: "current", manager: manager, recovered: &recovered
        )
        try recoverInvalidChannelIfNeeded(
            store: prefixStore, channelName: "current", manager: manager, recovered: &recovered
        )
        return recovered
    }

    private struct PrefixBinding: Codable {
        let schema: Int
        let runtimeProfile: String
    }

    private static func runtimeIsReady(_ root: URL) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent("ymm4m-runtime.json").path)
    }

    private static func prefixIsReady(_ prefix: URL) -> Bool {
        RosettaWineBackend.hasRequiredWPFSoftwareProfile(at: prefix)
            && FileManager.default.fileExists(atPath: prefix.appendingPathComponent(
                "drive_c/windows/Fonts/NotoSansCJKjp-Regular.otf"
            ).path)
    }

    private static func pairIsCompatible(
        runtimeRoot: URL,
        prefix: URL,
        expectedProfile: String
    ) -> Bool {
        guard runtimeIsReady(runtimeRoot), prefixIsReady(prefix),
              let data = try? Data(contentsOf: prefix.appendingPathComponent("ymm4m-runtime-binding.json")),
              let binding = try? JSONDecoder().decode(PrefixBinding.self, from: data) else {
            return false
        }
        return binding.schema == RuntimeSetupPaths.currentPrefixSchema
            && binding.runtimeProfile == expectedProfile
    }

    private static func writeBinding(prefix: URL, runtimeProfile: String) throws {
        let data = try JSONEncoder().encode(PrefixBinding(
            schema: RuntimeSetupPaths.currentPrefixSchema,
            runtimeProfile: runtimeProfile
        ))
        try data.write(
            to: prefix.appendingPathComponent("ymm4m-runtime-binding.json"),
            options: .atomic
        )
    }

    private static func activateVersionedPaths(_ paths: RuntimeSetupPaths) throws {
        guard let runtimeStore = paths.runtimeStore, let prefixStore = paths.prefixStore else { return }
        _ = try VersionedDirectoryChannel.activate(
            store: prefixStore, versionDirectory: paths.prefixInstallRoot
        )
        _ = try VersionedDirectoryChannel.activate(
            store: runtimeStore, versionDirectory: paths.runtimeInstallRoot
        )
    }

    private static func validateManagedPath(_ item: URL, store: URL) throws {
        let expectedParent = store.standardizedFileURL
            .appendingPathComponent("versions", isDirectory: true).path + "/"
        guard item.standardizedFileURL.path.hasPrefix(expectedParent),
              item.standardizedFileURL.deletingLastPathComponent().path
                == String(expectedParent.dropLast()) else {
            throw RuntimeError.unavailable(CoreMessages.managedPathOutsideStore())
        }
    }

    private static func recoverInvalidChannelIfNeeded(
        store: URL,
        channelName: String,
        manager: FileManager,
        recovered: inout [String]
    ) throws {
        let channel = store.appendingPathComponent(channelName)
        guard pathEntryExists(channel, manager: manager) else { return }
        let attributes = try manager.attributesOfItem(atPath: channel.path)
        if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
            let destination = try manager.destinationOfSymbolicLink(atPath: channel.path)
            let target = destination.hasPrefix("/")
                ? URL(fileURLWithPath: destination)
                : store.appendingPathComponent(destination).standardizedFileURL
            let versionsPath = store.standardizedFileURL
                .appendingPathComponent("versions", isDirectory: true).path + "/"
            guard target.standardizedFileURL.path.hasPrefix(versionsPath) else {
                throw RuntimeError.unavailable(CoreMessages.existingChannelOutsideStore())
            }
            if manager.fileExists(atPath: target.path) { return }
        }
        let retained = try retainForRecovery(
            channel, store: store, label: channelName, manager: manager
        )
        recovered.append(CoreMessages.recoveredIncompleteChannel(channelName, retained.path))
    }

    private static func retainForRecovery(
        _ item: URL,
        store: URL,
        label: String,
        manager: FileManager
    ) throws -> URL {
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
                throw RuntimeError.unavailable(CoreMessages.recoveryNotDirectory())
            }
        } else {
            try manager.createDirectory(
                at: recovery, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        guard recovery.resolvingSymlinksInPath().deletingLastPathComponent()
                == store.resolvingSymlinksInPath() else {
            throw RuntimeError.unavailable(CoreMessages.recoveryOutsideStore())
        }
    }

    private static func pathEntryExists(_ url: URL, manager: FileManager) -> Bool {
        manager.fileExists(atPath: url.path)
            || (try? manager.attributesOfItem(atPath: url.path)) != nil
    }

    private static func migrateLegacyPairIfAvailable(_ paths: RuntimeSetupPaths) throws -> Bool {
        guard let runtimeStore = paths.runtimeStore, let prefixStore = paths.prefixStore else {
            return false
        }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: paths.runtimeInstallRoot.path),
              !manager.fileExists(atPath: paths.prefixInstallRoot.path) else { return false }
        let legacyRuntime = runtimeStore.appendingPathComponent(
            "ymm4m-wine-11.0-dxmt", isDirectory: true
        )
        let legacyPrefix = prefixStore.appendingPathComponent("YMM4", isDirectory: true)
        guard runtimeIsReady(legacyRuntime), prefixIsReady(legacyPrefix) else { return false }
        try RosettaWineBackend.validateCleanRuntime(at: legacyRuntime)
        try manager.createDirectory(
            at: paths.runtimeInstallRoot.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try manager.createDirectory(
            at: paths.prefixInstallRoot.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try manager.moveItem(at: legacyRuntime, to: paths.runtimeInstallRoot)
        do {
            try manager.moveItem(at: legacyPrefix, to: paths.prefixInstallRoot)
        } catch {
            if !manager.fileExists(atPath: legacyPrefix.path),
               manager.fileExists(atPath: paths.prefixInstallRoot.path) {
                try? manager.moveItem(at: paths.prefixInstallRoot, to: legacyPrefix)
            }
            if !manager.fileExists(atPath: legacyRuntime.path),
               manager.fileExists(atPath: paths.runtimeInstallRoot.path) {
                try? manager.moveItem(at: paths.runtimeInstallRoot, to: legacyRuntime)
            }
            throw error
        }
        try writeBinding(prefix: paths.prefixInstallRoot, runtimeProfile: paths.runtimeProfile)
        try activateVersionedPaths(paths)
        return true
    }

    public static func bootstrapEnvironment(
        inherited: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        let allowedKeys = [
            "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE",
            "DEVELOPER_DIR", "YMM4M_SUPPORT_ROOT", "YMM4M_DOWNLOAD_CACHE",
            "YMM4M_COMPILE_CACHE_ROOT", "YMM4M_SOURCE_ROOT", "YMM4M_BUILD_ROOT",
            "YMM4M_LLVM15_ROOT",
            "YMM4M_WINE_BASE_RESOURCES", "YMM4M_WINE_BUILD_DIR",
            "YMM4M_DXMT_BUILD_DIR", "YMM4M_FREETYPE_SOURCE_DIR",
            "YMM4M_WINE_BASE_LIB_LINK",
        ]
        var result = Dictionary(uniqueKeysWithValues: allowedKeys.compactMap { key in
            inherited[key].map { (key, $0) }
        })
        let standardToolPaths = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin",
            "/usr/local/sbin", "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ]
        let inheritedPaths = inherited["PATH"]?.split(separator: ":").map(String.init) ?? []
        result["PATH"] = (standardToolPaths + inheritedPaths).reduce(into: [String]()) {
            if !$0.contains($1) { $0.append($1) }
        }.joined(separator: ":")
        return result
    }

    private struct Resources {
        let bootstrap: URL
        let setupPrefix: URL
        let lock: URL
        let projectResources: URL
    }

    private static func resources(environment: [String: String]) throws -> Resources {
        if let override = environment["YMM4M_SETUP_RESOURCES"], !override.isEmpty {
            let root = URL(fileURLWithPath: override, isDirectory: true)
            return Resources(
                bootstrap: root.appendingPathComponent("bootstrap-wine-dxmt-runtime.sh"),
                setupPrefix: root.appendingPathComponent("setup-prefix-from-runtime.sh"),
                lock: root.appendingPathComponent("bootstrap.lock.json"),
                projectResources: root
            )
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("RuntimeBootstrap", isDirectory: true),
           FileManager.default.fileExists(atPath: bundled.appendingPathComponent("bootstrap-wine-dxmt-runtime.sh").path) {
            return Resources(
                bootstrap: bundled.appendingPathComponent("bootstrap-wine-dxmt-runtime.sh"),
                setupPrefix: bundled.appendingPathComponent("setup-prefix-from-runtime.sh"),
                lock: bundled.appendingPathComponent("bootstrap.lock.json"),
                projectResources: bundled
            )
        }
        let repositoryCandidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        guard FileManager.default.fileExists(
            atPath: repositoryCandidate.appendingPathComponent("tools/bootstrap-wine-dxmt-runtime.sh").path
        ) else {
            throw RuntimeError.unavailable(CoreMessages.setupResourcesMissing())
        }
        return Resources(
            bootstrap: repositoryCandidate.appendingPathComponent("tools/bootstrap-wine-dxmt-runtime.sh"),
            setupPrefix: repositoryCandidate.appendingPathComponent("tools/setup-prefix-from-runtime.sh"),
            lock: repositoryCandidate.appendingPathComponent("runtime/bootstrap.lock.json"),
            projectResources: repositoryCandidate
        )
    }

    private static func run(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        progress: @escaping @Sendable (String) -> Void,
        logURL: URL
    ) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw RuntimeError.unavailable(CoreMessages.setupFileNotExecutable(executable.lastPathComponent))
        }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let logHandle = try FileHandle(forWritingTo: logURL)
        try logHandle.seekToEnd()
        defer { try? logHandle.close() }
        var data = Data()
        var pending = ""
        while true {
            let chunk = pipe.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            try logHandle.write(contentsOf: chunk)
            data.append(chunk)
            if data.count > 2 * 1_024 * 1_024 {
                data.removeFirst(data.count - 2 * 1_024 * 1_024)
            }
            pending += String(decoding: chunk, as: UTF8.self)
                .replacingOccurrences(of: "\r", with: "\n")
            let pieces = pending.components(separatedBy: "\n")
            pending = pieces.last ?? ""
            for line in pieces.dropLast() {
                if let message = setupProgressMessage(line) { progress(message) }
            }
        }
        if let message = setupProgressMessage(pending) { progress(message) }
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            let detail = output.isEmpty ? CoreMessages.setupFailed() : output
            throw RuntimeError.unavailable("\(detail)\n\(CoreMessages.diagnosticLogPath(logURL.path))")
        }
        return output
    }

    private static func prepareSetupLog(paths: RuntimeSetupPaths) throws -> URL {
        let support = paths.runtimeStore?.deletingLastPathComponent()
            ?? paths.runtimeRoot.deletingLastPathComponent()
        let directory = support.appendingPathComponent("Logs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let log = directory.appendingPathComponent("automatic-setup.log")
        let header = "YMM4M automatic setup\nstarted=\(ISO8601DateFormatter().string(from: Date()))\n"
        try Data(header.utf8).write(to: log, options: .atomic)
        return log
    }

    private static func setupProgressMessage(_ rawLine: String) -> String? {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }
        let prefixes = [
            "[repair]", "[download]", "[cache]", "[prepare]", "[build]", "[stage]", "[prefix]",
            "SETUP_RUNTIME=", "SETUP_PREFIX=",
        ]
        return prefixes.contains(where: { line.hasPrefix($0) }) ? String(line.prefix(500)) : nil
    }
}
