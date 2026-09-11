import Foundation
import CryptoKit
import YMM4MCore
import YMM4MProtocol

enum ContractFailure: Error { case failed(String) }

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw ContractFailure.failed(message) }
}

func testProtocolRoundTrip() throws {
    let hello = BridgeProtocol.Hello(sessionToken: "test-token")
    let payload = try BridgeProtocol.jsonPayload(hello)
    let encoded = try BridgeProtocol.encode(.init(type: .hello, payload: payload))
    let decoded = try BridgeProtocol.decode(encoded)
    try expect(decoded.type == .hello, "message type did not round-trip")
    let decodedHello = try JSONDecoder().decode(BridgeProtocol.Hello.self, from: decoded.payload)
    try expect(decodedHello == hello, "hello did not round-trip")
}

func testRejectsOversizedMessage() {
    var length = UInt32(BridgeProtocol.maximumMessageSize + 1).bigEndian
    let data = Data(bytes: &length, count: 4)
    do {
        _ = try BridgeProtocol.decode(data)
        fatalError("oversized message was accepted")
    } catch {}
}

func testMapsOnlyInsideMediaRoot() throws {
    let mapper = PathMapper(mediaRoot: URL(fileURLWithPath: "/Users/example/Media"))
    let mapped = try mapper.winePath(for: URL(fileURLWithPath: "/Users/example/Media/a/clip.mp4"))
    try expect(mapped == "M:\\a\\clip.mp4", "inside path mapping failed")
    do {
        _ = try mapper.winePath(for: URL(fileURLWithPath: "/Users/example/private.txt"))
        throw ContractFailure.failed("outside path was accepted")
    } catch PathMappingError.outsideMediaRoot {}
    do {
        _ = try mapper.winePath(for: URL(string: "https://example.invalid/project.ymmp")!)
        throw ContractFailure.failed("non-file URL was accepted")
    } catch PathMappingError.notAFileURL {}
}

func testConfiguresMediaDriveWithoutOverwriting() throws {
    let manager = FileManager.default
    let temporaryRoot = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-media-drive-test-\(UUID().uuidString)", isDirectory: true)
    let prefix = temporaryRoot.appendingPathComponent("prefix", isDirectory: true)
    let dosDevices = prefix.appendingPathComponent("dosdevices", isDirectory: true)
    let media = temporaryRoot.appendingPathComponent("media", isDirectory: true)
    let other = temporaryRoot.appendingPathComponent("other", isDirectory: true)
    try manager.createDirectory(at: dosDevices, withIntermediateDirectories: true)
    try manager.createDirectory(at: media, withIntermediateDirectories: true)
    try manager.createDirectory(at: other, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: temporaryRoot) }

    try WineMediaDrive.configure(prefix: prefix, mediaRoot: media)
    try WineMediaDrive.configure(prefix: prefix, mediaRoot: media)
    let mapping = dosDevices.appendingPathComponent("m:")
    let configuredDestination = try manager.destinationOfSymbolicLink(atPath: mapping.path)
    try expect(configuredDestination == media.path,
               "M: did not map to the selected media root")

    try manager.removeItem(at: mapping)
    try manager.createSymbolicLink(at: mapping, withDestinationURL: other)
    do {
        try WineMediaDrive.configure(prefix: prefix, mediaRoot: media)
        throw ContractFailure.failed("conflicting M: mapping was overwritten")
    } catch WineMediaDriveError.conflictingMapping {}
    let preservedDestination = try manager.destinationOfSymbolicLink(atPath: mapping.path)
    try expect(preservedDestination == other.path,
               "conflicting M: mapping was modified")
    try WineMediaDrive.configure(
        prefix: prefix, mediaRoot: media, replaceExistingMapping: true
    )
    let replacedDestination = try manager.destinationOfSymbolicLink(atPath: mapping.path)
    try expect(replacedDestination == media.path,
               "explicit complete setup did not replace the prior M: symlink")
}

func testUnknownYMM4ExecutableIsClassifiedByHash() throws {
    let manager = FileManager.default
    let executable = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-unknown-executable-\(UUID().uuidString)")
    try Data("not a YMM4 executable".utf8).write(to: executable, options: .atomic)
    defer { try? manager.removeItem(at: executable) }
    let result = try YMM4CompatibilityPolicy.classify(executable: executable)
    try expect(result.classification == .unknown, "unknown executable was treated as compatible")
    try expect(result.displayVersion == nil, "unknown executable received a version claim")
    try expect(result.sha256.count == 64, "executable hash was not recorded")
}

func testRedactsSensitiveValues() throws {
    let input = "/Users/alice/file Authorization: Bearer abc\napi_key=secret"
    let output = DiagnosticRedactor.redact(input, environment: ["HOME": "/Users/alice"])
    try expect(!output.contains("Bearer abc"), "authorization was not redacted")
    try expect(!output.contains("secret"), "API key was not redacted")
    try expect(output.contains("<HOME>"), "home was not redacted")
}

func testUnavailableWineIsReportedWithoutLaunching() async throws {
    let backend = RosettaWineBackend(wineURL: nil)
    let probe = try await backend.probe()
    try expect(!probe.available, "missing Wine was reported available")
    try expect(probe.runtimePath == nil, "missing Wine returned a path")
}

func testWineLaunchEnvironmentUsesAllowList() throws {
    let runtimeRoot = URL(fileURLWithPath: "/tmp/verified-runtime")
    let environment = RosettaWineBackend.launchEnvironment(inherited: [
        "HOME": "/Users/alice",
        "TMPDIR": "/tmp/example",
        "WINEPREFIX": "/tmp/prefix",
        "YMM4M_PREFIX": "/tmp/dedicated-prefix",
        "API_TOKEN": "must-not-leak",
        "SSH_AUTH_SOCK": "/tmp/agent.sock",
        "DYLD_INSERT_LIBRARIES": "/tmp/inject.dylib",
        "WINEDLLPATH": "/tmp/injected-wine-libraries",
        "CX_ROOT": "/tmp/crossover",
    ], runtimeRoot: runtimeRoot)
    try expect(environment["HOME"] == "/Users/alice", "HOME was not preserved")
    try expect(environment["WINEPREFIX"] == "/tmp/dedicated-prefix", "dedicated Wine prefix was not enforced")
    try expect(environment["API_TOKEN"] == nil, "credential leaked into Wine environment")
    try expect(environment["SSH_AUTH_SOCK"] == nil, "SSH agent leaked into Wine environment")
    try expect(environment["DYLD_INSERT_LIBRARIES"] == nil, "dynamic-loader injection was preserved")
    try expect(environment["CX_ROOT"] == nil, "CrossOver configuration leaked into clean runtime")
    try expect(environment["WINEDLLPATH"] == "/tmp/verified-runtime/lib/wine:/tmp/verified-runtime/lib/dxmt",
               "verified runtime library path was not enforced")
    try expect(environment["WINEDLLOVERRIDES"] == "d3d10core,d3d11,dxgi,winemetal,d2d1,dwrite=b",
               "verified runtime DLL overrides were not enforced")
    try expect(environment["PATH"] == "/usr/bin:/bin:/usr/sbin:/sbin", "PATH was not constrained")
    let explicitlyConfigured = RosettaWineBackend.launchEnvironment(
        inherited: [
            "HOME": "/Users/alice",
            "YMM4M_PREFIX": "/tmp/environment-prefix",
        ],
        prefixURL: URL(fileURLWithPath: "/tmp/ui-selected-prefix")
    )
    try expect(explicitlyConfigured["WINEPREFIX"] == "/tmp/ui-selected-prefix",
               "UI-selected dedicated prefix did not override the environment setting")
    try expect(RosettaWineBackend.isSafePrefixPath("/tmp/dedicated-prefix", home: "/Users/alice"),
               "dedicated absolute prefix was rejected")
    try expect(!RosettaWineBackend.isSafePrefixPath("relative-prefix", home: "/Users/alice"),
               "relative prefix was accepted")
    try expect(!RosettaWineBackend.isSafePrefixPath("/", home: "/Users/alice"),
               "filesystem root was accepted as a prefix")
    try expect(!RosettaWineBackend.isSafePrefixPath("/Users/alice", home: "/Users/alice"),
               "home directory was accepted as a prefix")
    let inheritedOnly = RosettaWineBackend.launchEnvironment(inherited: [
        "HOME": "/Users/alice",
        "WINEPREFIX": "/tmp/inherited-prefix",
    ])
    try expect(inheritedOnly["WINEPREFIX"] == nil, "inherited generic Wine prefix was accepted")
    let validRegistry = """
    [Software\\\\Microsoft\\\\Avalon.Graphics] 123
    #time=123
    "DisableHWAcceleration"=dword:00000001
    """
    try expect(RosettaWineBackend.registryContainsRequiredWPFSoftwareProfile(validRegistry),
               "required WPF software profile was not recognized")
    try expect(!RosettaWineBackend.registryContainsRequiredWPFSoftwareProfile(
        validRegistry.replacingOccurrences(of: "00000001", with: "00000000")
    ), "disabled WPF software profile was accepted")
}

func testConfiguredCleanRuntimeWhenProvided() async throws {
    guard let runtimePath = ProcessInfo.processInfo.environment["YMM4M_RUNTIME"] else { return }
    try RosettaWineBackend.validateCleanRuntime(at: URL(fileURLWithPath: runtimePath))
    if let prefixPath = ProcessInfo.processInfo.environment["YMM4M_PREFIX"] {
        try expect(RosettaWineBackend.hasRequiredWPFSoftwareProfile(
            at: URL(fileURLWithPath: prefixPath)
        ), "configured prefix is missing the required WPF software profile")
    }
    let probe = try await RosettaWineBackend().probe()
    try expect(probe.available, "verified clean runtime was not available: \(probe.reason)")
}

func testTextInputBridgePathAndLimits() throws {
    let mapped = try YMM4TextInputBridge.winePath(
        forHostURL: URL(fileURLWithPath: "/private/tmp/ymm4m-input.utf8")
    )
    try expect(mapped == "Z:\\private\\tmp\\ymm4m-input.utf8", "text input path mapping failed")
    do {
        _ = try YMM4TextInputBridge.winePath(forHostURL: URL(string: "https://example.invalid/input")!)
        throw ContractFailure.failed("non-file text input path was accepted")
    } catch YMM4TextInputError.invalidHostPath {}
    try expect(YMM4TextInputBridge.maximumUTF8Bytes == 65_536, "text input byte limit changed")
}

func testAutomaticSetupUsesDedicatedDefaultPaths() throws {
    let paths = RuntimeSetupPaths.defaults(home: URL(fileURLWithPath: "/Users/example"))
    try expect(paths.runtimeRoot.path == "/Users/example/Library/Application Support/YMM4M/Runtimes/current",
               "automatic runtime path changed unexpectedly")
    try expect(paths.prefix.path == "/Users/example/Library/Application Support/YMM4M/Prefixes/current",
               "automatic prefix path changed unexpectedly")
    try expect(paths.runtimeInstallRoot.path.contains("/Runtimes/versions/"),
               "runtime updates are not staged in a versioned directory")
    try expect(paths.prefixInstallRoot.path.contains("/Prefixes/versions/"),
               "prefix updates are not staged in a versioned directory")

    let bootstrapEnvironment = RuntimeBootstrapper.bootstrapEnvironment(inherited: [
        "HOME": "/Users/example",
        "PATH": "/custom/bin:/usr/bin",
        "AWS_SECRET_ACCESS_KEY": "must-not-leak",
        "DYLD_INSERT_LIBRARIES": "/tmp/untrusted.dylib",
        "YMM4M_LLVM15_ROOT": "/safe/llvm15",
    ])
    try expect(bootstrapEnvironment["AWS_SECRET_ACCESS_KEY"] == nil,
               "runtime bootstrap inherited a credential")
    try expect(bootstrapEnvironment["DYLD_INSERT_LIBRARIES"] == nil,
               "runtime bootstrap inherited a dynamic-loader injection")
    try expect(bootstrapEnvironment["YMM4M_LLVM15_ROOT"] == "/safe/llvm15",
               "runtime bootstrap dropped an allowed toolchain override")
    try expect(bootstrapEnvironment["PATH"]?.contains("/opt/homebrew/bin") == true,
               "runtime bootstrap PATH is missing Homebrew tools")
    try expect(paths.runtimeRoot.path != paths.prefix.path,
               "runtime and dedicated prefix paths overlap")
}

func testAutomaticSetupRecoversIncompleteManagedState() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-incomplete-setup-test-\(UUID().uuidString)", isDirectory: true)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let paths = RuntimeSetupPaths.defaults(home: home)
    defer { try? manager.removeItem(at: root) }

    try manager.createDirectory(at: paths.runtimeInstallRoot, withIntermediateDirectories: true)
    try Data("partial runtime".utf8).write(
        to: paths.runtimeInstallRoot.appendingPathComponent("download.part")
    )
    try manager.createDirectory(at: paths.prefixInstallRoot, withIntermediateDirectories: true)
    try Data("partial prefix".utf8).write(
        to: paths.prefixInstallRoot.appendingPathComponent("user.reg")
    )
    try manager.createDirectory(at: paths.runtimeRoot, withIntermediateDirectories: true)
    try manager.createDirectory(at: paths.prefix, withIntermediateDirectories: true)

    let recovered = try RuntimeBootstrapper.recoverIncompleteManagedState(
        paths, fileManager: manager
    )
    try expect(recovered.count == 4,
               "incomplete runtime/prefix/channels were not all retained for recovery")
    try expect(!manager.fileExists(atPath: paths.runtimeInstallRoot.path),
               "incomplete runtime remained at the fixed install destination")
    try expect(!manager.fileExists(atPath: paths.prefixInstallRoot.path),
               "incomplete prefix remained at the fixed install destination")
    let runtimeRecovery = paths.runtimeStore!.appendingPathComponent("Recovery")
    let prefixRecovery = paths.prefixStore!.appendingPathComponent("Recovery")
    let runtimeRecoveryEntries = try manager.contentsOfDirectory(atPath: runtimeRecovery.path)
    let prefixRecoveryEntries = try manager.contentsOfDirectory(atPath: prefixRecovery.path)
    try expect(runtimeRecoveryEntries.count == 2,
               "runtime recovery did not preserve both incomplete entries")
    try expect(prefixRecoveryEntries.count == 2,
               "prefix recovery did not preserve both incomplete entries")

    try manager.createSymbolicLink(
        atPath: paths.runtimeRoot.path,
        withDestinationPath: "versions/missing-runtime"
    )
    let brokenChannelRecovery = try RuntimeBootstrapper.recoverIncompleteManagedState(
        paths, fileManager: manager
    )
    try expect(brokenChannelRecovery.count == 1,
               "broken internal runtime channel was not retained for recovery")
    try expect(!manager.fileExists(atPath: paths.runtimeRoot.path),
               "broken internal runtime channel remained active")

    let external = root.appendingPathComponent("external", isDirectory: true)
    try manager.createDirectory(at: external, withIntermediateDirectories: true)
    try manager.createSymbolicLink(at: paths.runtimeRoot, withDestinationURL: external)
    do {
        _ = try RuntimeBootstrapper.recoverIncompleteManagedState(paths, fileManager: manager)
        throw ContractFailure.failed("external runtime channel was replaced during repair")
    } catch RuntimeError.unavailable {}
    try expect(paths.runtimeRoot.resolvingSymlinksInPath() == external.resolvingSymlinksInPath(),
               "external runtime channel changed during refused repair")

    let unsafeHome = root.appendingPathComponent("unsafe-home", isDirectory: true)
    let unsafePaths = RuntimeSetupPaths.defaults(home: unsafeHome)
    try manager.createDirectory(at: unsafePaths.runtimeInstallRoot, withIntermediateDirectories: true)
    try Data("partial".utf8).write(
        to: unsafePaths.runtimeInstallRoot.appendingPathComponent("partial")
    )
    let externalRecovery = root.appendingPathComponent("external-recovery", isDirectory: true)
    try manager.createDirectory(at: externalRecovery, withIntermediateDirectories: true)
    try manager.createSymbolicLink(
        at: unsafePaths.runtimeStore!.appendingPathComponent("Recovery"),
        withDestinationURL: externalRecovery
    )
    do {
        _ = try RuntimeBootstrapper.recoverIncompleteManagedState(
            unsafePaths, fileManager: manager
        )
        throw ContractFailure.failed("external Recovery directory was used")
    } catch RuntimeError.unavailable {}
    try expect(manager.fileExists(atPath: unsafePaths.runtimeInstallRoot.path),
               "partial runtime moved through an external Recovery link")
}

func testAutomaticSetupPopulatesDeveloperSelectedStoreRoots() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-custom-store-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? manager.removeItem(at: root) }
    let runtimeStore = root.appendingPathComponent("dev-runtime", isDirectory: true)
    let prefixStore = root.appendingPathComponent("dev-prefix", isDirectory: true)
    try manager.createDirectory(at: runtimeStore, withIntermediateDirectories: true)
    try manager.createDirectory(at: prefixStore, withIntermediateDirectories: true)

    let paths = RuntimeSetupPaths.custom(runtimeStore: runtimeStore, prefixStore: prefixStore)
    try expect(paths.runtimeStore?.standardizedFileURL == runtimeStore.standardizedFileURL,
               "custom runtime store root was not preserved")
    try expect(paths.prefixStore?.standardizedFileURL == prefixStore.standardizedFileURL,
               "custom prefix store root was not preserved")
    try expect(paths.runtimeRoot.path == runtimeStore.appendingPathComponent("current").path,
               "custom runtime channel is not <store>/current")
    try expect(paths.prefix.path == prefixStore.appendingPathComponent("current").path,
               "custom prefix channel is not <store>/current")
    try expect(paths.runtimeInstallRoot.deletingLastPathComponent().lastPathComponent == "versions",
               "custom runtime is not staged under versions/")
    try expect(paths.runtimeInstallRoot.deletingLastPathComponent().deletingLastPathComponent()
                .standardizedFileURL == runtimeStore.standardizedFileURL,
               "custom runtime versions/ is not inside the selected folder")
    try expect(paths.runtimeProfile == RuntimeSetupPaths.currentRuntimeProfile,
               "custom store dropped the current runtime profile")

    // The recovery machinery must work identically against a custom store.
    try manager.createDirectory(at: paths.runtimeInstallRoot, withIntermediateDirectories: true)
    try Data("partial".utf8).write(
        to: paths.runtimeInstallRoot.appendingPathComponent("download.part")
    )
    let recovered = try RuntimeBootstrapper.recoverIncompleteManagedState(paths, fileManager: manager)
    try expect(recovered.count == 1, "incomplete custom-store runtime was not retained")
    try expect(!manager.fileExists(atPath: paths.runtimeInstallRoot.path),
               "incomplete custom-store runtime remained at the install destination")
    let recoveryEntries = try manager.contentsOfDirectory(
        atPath: runtimeStore.appendingPathComponent("Recovery").path
    )
    try expect(recoveryEntries.count == 1, "custom-store Recovery did not keep the incomplete entry")

    // Atomic activation must produce <store>/current -> versions/<profile>.
    try manager.createDirectory(at: paths.runtimeInstallRoot, withIntermediateDirectories: true)
    _ = try VersionedDirectoryChannel.activate(
        store: runtimeStore, versionDirectory: paths.runtimeInstallRoot
    )
    try expect(
        paths.runtimeRoot.resolvingSymlinksInPath().standardizedFileURL
            == paths.runtimeInstallRoot.resolvingSymlinksInPath().standardizedFileURL,
        "custom-store current channel did not point at the activated version"
    )
}

private final class SetupProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String] = []

    func append(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        messages.append(message)
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return messages
    }
}

func testAutomaticSetupStreamsProgressAndWritesFailureLog() async throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-bootstrap-progress-test-\(UUID().uuidString)", isDirectory: true)
    let resources = root.appendingPathComponent("resources", isDirectory: true)
    try manager.createDirectory(at: resources, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }

    let bootstrap = resources.appendingPathComponent("bootstrap-wine-dxmt-runtime.sh")
    let setupPrefix = resources.appendingPathComponent("setup-prefix-from-runtime.sh")
    try Data("""
    #!/bin/sh
    echo '[download] synthetic source'
    echo '[build] synthetic runtime'
    echo 'synthetic setup failure' >&2
    exit 2
    """.utf8).write(to: bootstrap, options: .atomic)
    try Data("#!/bin/sh\nexit 2\n".utf8).write(to: setupPrefix, options: .atomic)
    try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: bootstrap.path)
    try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: setupPrefix.path)
    try Data("{}\n".utf8).write(
        to: resources.appendingPathComponent("bootstrap.lock.json"), options: .atomic
    )

    let paths = RuntimeSetupPaths(
        runtimeRoot: root.appendingPathComponent("runtime", isDirectory: true),
        prefix: root.appendingPathComponent("prefix", isDirectory: true)
    )
    let recorder = SetupProgressRecorder()
    var failureDescription = ""
    do {
        _ = try await RuntimeBootstrapper.install(
            paths: paths,
            environment: [
                "HOME": root.path,
                "YMM4M_SETUP_RESOURCES": resources.path,
            ],
            progress: recorder.append
        )
        throw ContractFailure.failed("synthetic setup failure was accepted")
    } catch let error as ContractFailure {
        throw error
    } catch {
        failureDescription = error.localizedDescription
    }

    let messages = recorder.snapshot()
    try expect(messages.contains(where: { $0.hasPrefix("[開始]") }),
               "automatic setup did not report its start")
    try expect(messages.contains("[download] synthetic source"),
               "download progress was not streamed")
    try expect(messages.contains("[build] synthetic runtime"),
               "build progress was not streamed")
    let log = root.appendingPathComponent("Logs/automatic-setup.log")
    let logContents = try String(contentsOf: log, encoding: .utf8)
    try expect(logContents.contains("[download] synthetic source"),
               "download output was not written to the setup log")
    try expect(logContents.contains("synthetic setup failure"),
               "setup failure was not written to the setup log")
    try expect(failureDescription.contains(log.path),
               "setup failure did not identify its diagnostic log")
    try expect(!manager.fileExists(atPath: paths.runtimeRoot.path),
               "failed setup exposed a partial runtime")
}

func testConfiguredAutomaticSetupActivationWhenRequested() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["YMM4M_ACTIVATE_SETUP_TEST"] == "1" else { return }
    _ = try await RuntimeBootstrapper.install(environment: environment)
    let paths = RuntimeSetupPaths.defaults()
    try RuntimeBootstrapper.validateActivePair(paths)
    try RosettaWineBackend.validateCleanRuntime(at: paths.runtimeRoot)
}

func testConfiguredIncompleteCompleteSetupRecoveryWhenRequested() async throws {
    let inherited = ProcessInfo.processInfo.environment
    guard inherited["YMM4M_RECOVERY_SETUP_TEST"] == "1" else { return }
    guard let archivePath = inherited["YMM4M_ARCHIVE_TEST"],
          let catalogPath = inherited["YMM4M_YMM4_CATALOG"] else {
        throw ContractFailure.failed("recovery setup test requires a configured YMM4 archive/catalog")
    }

    let manager = FileManager.default
    let root = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-real-recovery-setup-\(UUID().uuidString)", isDirectory: true)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let paths = RuntimeSetupPaths.defaults(home: home)
    defer { try? manager.removeItem(at: root) }

    try manager.createDirectory(at: paths.runtimeInstallRoot, withIntermediateDirectories: true)
    try Data("interrupted runtime".utf8).write(
        to: paths.runtimeInstallRoot.appendingPathComponent("partial")
    )
    try manager.createDirectory(at: paths.prefixInstallRoot, withIntermediateDirectories: true)
    try Data("interrupted prefix".utf8).write(
        to: paths.prefixInstallRoot.appendingPathComponent("partial")
    )
    try manager.createDirectory(at: paths.runtimeRoot, withIntermediateDirectories: true)
    try manager.createDirectory(at: paths.prefix, withIntermediateDirectories: true)

    var setupEnvironment = inherited
    setupEnvironment["HOME"] = home.path
    let recorder = SetupProgressRecorder()
    _ = try await RuntimeBootstrapper.install(
        paths: paths, environment: setupEnvironment, progress: recorder.append
    )
    try RuntimeBootstrapper.validateActivePair(paths)
    try RosettaWineBackend.validateCleanRuntime(at: paths.runtimeRoot)
    try expect(recorder.snapshot().contains { $0.hasPrefix("[repair]") },
               "real recovery setup did not report repairing the interrupted state")

    let catalog = try YMM4ReleaseCatalog.load(from: URL(fileURLWithPath: catalogPath))
    let ymm4Paths = YMM4InstallationPaths(
        store: home.appendingPathComponent("Library/Application Support/YMM4M/YMM4")
    )
    let archive = URL(fileURLWithPath: archivePath)
    let installed = try await YMM4ArchiveInstaller.install(
        archive: archive, catalog: catalog, paths: ymm4Paths
    )
    let mediaRoot = root.appendingPathComponent("media", isDirectory: true)
    try manager.createDirectory(at: mediaRoot, withIntermediateDirectories: true)
    try WineMediaDrive.configure(
        prefix: paths.prefix, mediaRoot: mediaRoot, replaceExistingMapping: true
    )
    try expect(manager.isReadableFile(atPath: installed.executable.path),
               "real complete setup did not copy YMM4 into the managed store")
    try expect(
        paths.prefix.appendingPathComponent("dosdevices/m:").resolvingSymlinksInPath()
            == mediaRoot.resolvingSymlinksInPath(),
        "real complete setup did not configure the selected media root"
    )

    _ = try await RuntimeBootstrapper.install(paths: paths, environment: setupEnvironment)
    let repeated = try await YMM4ArchiveInstaller.install(
        archive: archive, catalog: catalog, paths: ymm4Paths
    )
    try expect(repeated.reusedExistingInstall,
               "second complete setup did not reuse the verified YMM4 copy")
    try RuntimeBootstrapper.validateActivePair(paths)
}

func testStoredSettingsPersistAndMigrateManagedPaths() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-settings-test-\(UUID().uuidString)", isDirectory: true)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let support = home.appendingPathComponent("Library/Application Support/YMM4M", isDirectory: true)
    let runtimeCurrent = support.appendingPathComponent("Runtimes/current", isDirectory: true)
    let prefixCurrent = support.appendingPathComponent("Prefixes/current", isDirectory: true)
    let ymm4Current = support.appendingPathComponent("YMM4/current", isDirectory: true)
    try manager.createDirectory(at: runtimeCurrent, withIntermediateDirectories: true)
    try manager.createDirectory(at: prefixCurrent, withIntermediateDirectories: true)
    try manager.createDirectory(at: ymm4Current, withIntermediateDirectories: true)
    try Data("test".utf8).write(to: ymm4Current.appendingPathComponent("YukkuriMovieMaker.exe"))
    defer { try? manager.removeItem(at: root) }

    let suite = "dev.yukiorita.YMM4M.contracts.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        throw ContractFailure.failed("could not create isolated defaults suite")
    }
    defer { defaults.removePersistentDomain(forName: suite) }
    let legacy = StoredSetupSettings(
        runtimeRootPath: support.appendingPathComponent("Runtimes/ymm4m-wine-11.0-dxmt").path,
        winePrefixPath: support.appendingPathComponent("Prefixes/YMM4").path,
        ymm4ExecutablePath: support
            .appendingPathComponent("YMM4/versions/4.55.1.1-Lite/YukkuriMovieMaker.exe").path,
        ymm4ArchivePath: "/Users/example/Downloads/YukkuriMovieMaker_v4_Lite.zip",
        mediaRootPath: "/Users/example/YMM4 Projects"
    )
    legacy.save(to: defaults)

    let nextLaunch = StoredSetupSettings(defaults: defaults)
    try expect(nextLaunch == legacy, "saved setup settings did not survive a new defaults read")
    let migration = nextLaunch.migratingManagedPaths(home: home, fileManager: manager)
    try expect(migration.changed, "managed legacy paths were not migrated")
    try expect(migration.settings.runtimeRootPath == runtimeCurrent.path,
               "legacy runtime did not migrate to current")
    try expect(migration.settings.winePrefixPath == prefixCurrent.path,
               "legacy prefix did not migrate to current")
    try expect(migration.settings.ymm4ExecutablePath
        == ymm4Current.appendingPathComponent("YukkuriMovieMaker.exe").path,
               "managed version executable did not migrate to current")
    try expect(migration.settings.ymm4ArchivePath == legacy.ymm4ArchivePath,
               "source ZIP location was not retained")
    try expect(migration.settings.mediaRootPath == legacy.mediaRootPath,
               "media-root setting was not retained")
    let repeated = migration.settings.migratingManagedPaths(home: home, fileManager: manager)
    try expect(!repeated.changed, "managed-path migration was not idempotent")

    let custom = StoredSetupSettings(
        runtimeRootPath: "/opt/custom/runtime",
        winePrefixPath: "/opt/custom/prefix",
        ymm4ExecutablePath: "/opt/custom/YukkuriMovieMaker.exe"
    ).migratingManagedPaths(home: home, fileManager: manager)
    try expect(!custom.changed, "custom paths were mistaken for managed legacy paths")

    let missingHome = root.appendingPathComponent("missing-home", isDirectory: true)
    let missing = StoredSetupSettings(
        runtimeRootPath: missingHome
            .appendingPathComponent("Library/Application Support/YMM4M/Runtimes/ymm4m-wine-11.0-dxmt").path,
        winePrefixPath: missingHome
            .appendingPathComponent("Library/Application Support/YMM4M/Prefixes/YMM4").path,
        ymm4ExecutablePath: missingHome
            .appendingPathComponent("Library/Application Support/YMM4M/YMM4/lite-current/YukkuriMovieMaker.exe").path
    ).migratingManagedPaths(home: missingHome, fileManager: manager)
    try expect(!missing.changed, "missing current channels rewrote stored paths")
    try expect(missing.needsRuntimeSetup && missing.needsYMM4Setup,
               "missing managed channels did not request setup")
}

func testVersionedChannelAndYMM4ZIPInstall() async throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-zip-install-test-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let archive = root.appendingPathComponent("YMM4.zip")
    let store = root.appendingPathComponent("store", isDirectory: true)
    try manager.createDirectory(at: source, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    let executableData = Data("synthetic-public-test-executable".utf8)
    try executableData.write(to: source.appendingPathComponent("YukkuriMovieMaker.exe"))

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-c", "-k", "--norsrc", source.path, archive.path]
    try process.run()
    process.waitUntilExit()
    try expect(process.terminationStatus == 0, "could not create synthetic ZIP fixture")

    let archiveHash = try YMM4ArchiveInstaller.archiveSHA256(at: archive)
    let executableHash = SHA256.hash(data: executableData)
        .map { String(format: "%02x", $0) }.joined()
    let release = YMM4Release(
        id: "test-1.0",
        displayVersion: "test 1.0",
        archiveSha256: archiveHash,
        executableSha256: executableHash,
        executableRelativePath: "YukkuriMovieMaker.exe",
        edition: .lite,
        classification: .knownCompatible,
        runtimeProfile: RuntimeSetupPaths.currentRuntimeProfile,
        notes: "synthetic contract fixture"
    )
    let catalog = YMM4ReleaseCatalog(schema: 1, releases: [release])
    let first = try await YMM4ArchiveInstaller.install(
        archive: archive, catalog: catalog, paths: YMM4InstallationPaths(store: store)
    )
    try expect(!first.reusedExistingInstall, "first ZIP install unexpectedly reused a version")
    try expect(first.executable.resolvingSymlinksInPath().path.hasSuffix(
        "/versions/test-1.0/YukkuriMovieMaker.exe"
    ), "current YMM4 channel does not resolve to the verified version")
    let second = try await YMM4ArchiveInstaller.install(
        archive: archive, catalog: catalog, paths: YMM4InstallationPaths(store: store)
    )
    try expect(second.reusedExistingInstall, "verified YMM4 version was needlessly overwritten")

    let installedExecutable = store.appendingPathComponent(
        "versions/test-1.0/YukkuriMovieMaker.exe"
    )
    try Data("incomplete".utf8).write(to: installedExecutable)
    let repaired = try await YMM4ArchiveInstaller.install(
        archive: archive, catalog: catalog, paths: YMM4InstallationPaths(store: store)
    )
    try expect(!repaired.reusedExistingInstall,
               "invalid partial YMM4 destination was reused")
    let repairedExecutable = try Data(contentsOf: repaired.executable)
    try expect(repairedExecutable == executableData,
               "YMM4 ZIP was not copied again after partial-install recovery")
    let recovery = store.appendingPathComponent("Recovery")
    let recoveryEntries = try manager.contentsOfDirectory(atPath: recovery.path)
    try expect(recoveryEntries.contains {
        $0.hasPrefix("incomplete-test-1.0-")
    }, "partial YMM4 install was not retained in Recovery")

    let current = store.appendingPathComponent("current")
    try manager.removeItem(at: current)
    try manager.createDirectory(at: current, withIntermediateDirectories: false)
    try Data("partial channel".utf8).write(to: current.appendingPathComponent("partial"))
    _ = try await YMM4ArchiveInstaller.install(
        archive: archive, catalog: catalog, paths: YMM4InstallationPaths(store: store)
    )
    try expect(current.resolvingSymlinksInPath().path.hasSuffix("/versions/test-1.0"),
               "regular partial current path was not repaired")

    let external = root.appendingPathComponent("external", isDirectory: true)
    try manager.createDirectory(at: external, withIntermediateDirectories: false)
    try manager.removeItem(at: current)
    try manager.createSymbolicLink(at: current, withDestinationURL: external)
    do {
        _ = try await YMM4ArchiveInstaller.install(
            archive: archive, catalog: catalog, paths: YMM4InstallationPaths(store: store)
        )
        throw ContractFailure.failed("external YMM4 current channel was replaced")
    } catch RuntimeError.unavailable {}
}

func testOfficialMaintenanceCandidateAndRollback() async throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-maintenance-test-\(UUID().uuidString)", isDirectory: true)
    let initialSource = root.appendingPathComponent("initial", isDirectory: true)
    let candidateSource = root.appendingPathComponent("candidate", isDirectory: true)
    let initialArchive = root.appendingPathComponent("initial.zip")
    let candidateArchive = root.appendingPathComponent("YukkuriMovieMaker_v4.55.1.2_Lite.zip")
    let store = root.appendingPathComponent("store", isDirectory: true)
    try manager.createDirectory(at: initialSource, withIntermediateDirectories: true)
    try manager.createDirectory(at: candidateSource, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }

    let initialExecutable = Data("known-compatible-executable".utf8)
    try initialExecutable.write(to: initialSource.appendingPathComponent("YukkuriMovieMaker.exe"))
    let requiredFixtures = [
        "YukkuriMovieMaker.runtimeconfig.json", "coreclr.dll", "hostfxr.dll",
        "hostpolicy.dll", "PresentationCore.dll",
    ]
    var candidateExecutable = Data(repeating: 0, count: 512)
    candidateExecutable[0] = 0x4d
    candidateExecutable[1] = 0x5a
    candidateExecutable[0x3c] = 0x80
    candidateExecutable[0x80] = 0x50
    candidateExecutable[0x81] = 0x45
    candidateExecutable[0x84] = 0x64
    candidateExecutable[0x85] = 0x86
    candidateExecutable[0x98] = 0x0b
    candidateExecutable[0x99] = 0x02
    candidateExecutable[0xdc] = 0x02
    try candidateExecutable.write(to: candidateSource.appendingPathComponent("YukkuriMovieMaker.exe"))
    var requiredFiles: [YMM4RequiredFile] = []
    for name in requiredFixtures {
        let data = Data("stable-boundary-\(name)".utf8)
        try data.write(to: candidateSource.appendingPathComponent(name))
        requiredFiles.append(YMM4RequiredFile(
            path: name,
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        ))
    }

    func makeZIP(source: URL, destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--norsrc", source.path, destination.path]
        try process.run()
        process.waitUntilExit()
        try expect(process.terminationStatus == 0, "could not create maintenance ZIP fixture")
    }
    try makeZIP(source: initialSource, destination: initialArchive)
    try makeZIP(source: candidateSource, destination: candidateArchive)

    let initialArchiveHash = try YMM4ArchiveInstaller.archiveSHA256(at: initialArchive)
    let initialExecutableHash = SHA256.hash(data: initialExecutable)
        .map { String(format: "%02x", $0) }.joined()
    let initialRelease = YMM4Release(
        id: "known-4.55.1.1-Lite", displayVersion: "4.55.1.1 Lite",
        archiveSha256: initialArchiveHash, executableSha256: initialExecutableHash,
        executableRelativePath: "YukkuriMovieMaker.exe", edition: .lite,
        classification: .knownCompatible,
        runtimeProfile: RuntimeSetupPaths.currentRuntimeProfile, notes: "synthetic known version"
    )
    let family = YMM4MaintenanceFamily(
        id: "test-4.55.1", versionPrefix: "4.55.1", testedThroughVersion: "4.55.1.1",
        editions: [.standard, .lite], runtimeProfile: RuntimeSetupPaths.currentRuntimeProfile,
        requiredFiles: requiredFiles, notes: "synthetic maintenance family"
    )
    let catalog = YMM4ReleaseCatalog(
        schema: 2, releases: [initialRelease], maintenanceFamilies: [family]
    )
    let legacySetting = store.appendingPathComponent("lite-current/user/setting/legacy.json")
    try manager.createDirectory(
        at: legacySetting.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let legacySettingData = Data("{\"legacy\":true}".utf8)
    try legacySettingData.write(to: legacySetting)
    _ = try await YMM4ArchiveInstaller.install(
        archive: initialArchive, catalog: catalog, paths: YMM4InstallationPaths(store: store)
    )
    let migratedLegacyData = try Data(
        contentsOf: store.appendingPathComponent("current/user/setting/legacy.json")
    )
    try expect(migratedLegacyData == legacySettingData,
               "legacy Lite user settings were not copied into shared storage")
    let persistedSetting = store.appendingPathComponent("current/user/setting/test.json")
    try manager.createDirectory(
        at: persistedSetting.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    let persistedSettingData = Data("{\"persisted\":true}".utf8)
    try persistedSettingData.write(to: persistedSetting)

    let candidateHash = try YMM4ArchiveInstaller.archiveSHA256(at: candidateArchive)
    let metadata = """
    {"tag_name":"v4.55.1.2","draft":false,"prerelease":false,"assets":[{
      "name":"YukkuriMovieMaker_v4.55.1.2_Lite.zip",
      "size":\((try candidateArchive.resourceValues(forKeys: [.fileSizeKey])).fileSize!),
      "digest":"sha256:\(candidateHash)"
    }]}
    """
    let verifiedReceipt = try YMM4OfficialReleaseVerifier.verify(
        archive: candidateArchive, releaseMetadata: Data(metadata.utf8)
    )
    try expect(verifiedReceipt.edition == .lite, "official Lite asset edition was not recognized")
    try expect(family.accepts(version: "4.55.1.2", edition: .lite),
               "same maintenance train update was rejected")
    try expect(!family.accepts(version: "4.55.2.0", edition: .lite),
               "feature train update was accepted as maintenance")

    let installed = try await YMM4ArchiveInstaller.installMaintenanceCandidate(
        archive: candidateArchive,
        receipt: verifiedReceipt,
        family: family,
        paths: YMM4InstallationPaths(store: store)
    )
    try expect(installed.release.classification == .maintenanceCandidate,
               "maintenance candidate was promoted to known-compatible")
    let settingAfterUpdate = try Data(
        contentsOf: store.appendingPathComponent("current/user/setting/test.json")
    )
    try expect(settingAfterUpdate == persistedSettingData,
               "YMM4 user settings did not survive a maintenance update")
    let classified = try YMM4ArchiveInstaller.classifyInstalledMaintenanceCandidate(
        executable: installed.executable, catalog: catalog, paths: YMM4InstallationPaths(store: store)
    )
    try expect(classified?.classification == .maintenanceCandidate,
               "persisted maintenance receipt was not revalidated")

    let previousExecutable = store.appendingPathComponent("previous/YukkuriMovieMaker.exe")
    try Data("tampered".utf8).write(to: previousExecutable)
    do {
        _ = try YMM4ArchiveInstaller.rollback(
            catalog: catalog, paths: YMM4InstallationPaths(store: store)
        )
        throw ContractFailure.failed("tampered previous version was activated")
    } catch RuntimeError.unavailable {}
    let activeAfterFailedRollback = try Data(contentsOf: installed.executable)
    try expect(activeAfterFailedRollback == candidateExecutable,
               "failed rollback changed the active candidate")
    try initialExecutable.write(to: previousExecutable)
    let rolledBack = try YMM4ArchiveInstaller.rollback(
        catalog: catalog, paths: YMM4InstallationPaths(store: store)
    )
    let rolledBackData = try Data(contentsOf: rolledBack)
    try expect(rolledBackData == initialExecutable,
               "rollback did not restore the prior known-compatible executable")
}

func testConfiguredRealYMM4ArchiveWhenProvided() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard let archivePath = environment["YMM4M_ARCHIVE_TEST"],
          let catalogPath = environment["YMM4M_YMM4_CATALOG"] else { return }
    let store = FileManager.default.temporaryDirectory
        .appendingPathComponent("ymm4m-real-zip-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: store) }
    let catalog = try YMM4ReleaseCatalog.load(from: URL(fileURLWithPath: catalogPath))
    let installed = try await YMM4ArchiveInstaller.install(
        archive: URL(fileURLWithPath: archivePath),
        catalog: catalog,
        paths: YMM4InstallationPaths(store: store)
    )
    let result = try YMM4CompatibilityPolicy.classify(
        executable: installed.executable, catalog: catalog
    )
    try expect(result.classification == .knownCompatible,
               "configured real YMM4 archive did not install as a known-compatible release")
}

func testConfiguredTextInputBridgeWhenRequested() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["YMM4M_TEXT_BRIDGE_TEST"] == "1" else { return }
    guard let helperPath = environment["YMM4M_TEXT_COMMIT_HELPER"] else {
        throw ContractFailure.failed("configured text input helper was not found")
    }
    let testDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ymm4m-text-bridge-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: testDirectory,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: testDirectory) }
    let bridge = YMM4TextInputBridge(
        helperURL: URL(fileURLWithPath: helperPath),
        temporaryDirectory: testDirectory
    )
    try await bridge.commit("日本語")
    let remainingFiles = try FileManager.default.contentsOfDirectory(atPath: testDirectory.path)
    try expect(remainingFiles.isEmpty, "text input temporary file was not removed")
}

// MARK: - Runtime launch environment defaults (B5)

func testWineLaunchEnvironmentDefaultsToQuietWinedebug() throws {
    let base: [String: String] = ["HOME": "/Users/alice"]
    let quiet = RosettaWineBackend.launchEnvironment(inherited: base)
    try expect(quiet["WINEDEBUG"] == "-all",
               "verbose Wine tracing is still forced on by default")

    let optIn = RosettaWineBackend.launchEnvironment(
        inherited: base.merging(["YMM4M_WINEDEBUG": "+seh,+tid"]) { _, new in new }
    )
    try expect(optIn["WINEDEBUG"] == "+seh,+tid",
               "YMM4M_WINEDEBUG opt-in was not honored")

    let explicit = RosettaWineBackend.launchEnvironment(
        inherited: base.merging(["WINEDEBUG": "+relay"]) { _, new in new }
    )
    try expect(explicit["WINEDEBUG"] == "+relay",
               "an explicitly set WINEDEBUG was overridden")
}

// MARK: - Clean runtime schema 2 provenance / fixture gate (A1 / A2 / §4.1 案3)

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// A minimal but structurally valid x86_64 Mach-O with a zeroed LC_UUID and a
/// `__LINKEDIT` segment at file offset 128, so `machOLoadableSHA256` resolves to
/// `SHA-256(first 128 bytes)`.
private func syntheticWinemacSO() -> Data {
    var d = Data()
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    func u64(_ v: UInt64) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    u32(0xfeedfacf); u32(0x01000007); u32(0x00000003); u32(0x00000006)
    u32(2); u32(24 + 72); u32(0); u32(0)
    u32(0x1b); u32(24); d.append(Data(repeating: 0, count: 16))
    u32(0x19); u32(72)
    var segname = Data("__LINKEDIT".utf8)
    segname.append(Data(repeating: 0, count: 16 - segname.count))
    d.append(segname)
    u64(0); u64(8); u64(128); u64(8)
    u32(1); u32(1); u32(0); u32(0)
    d.append(Data("linkedit".utf8))
    return d
}

private let cleanRuntimeFileKeys = [
    "bin/wine",
    "lib/wine/x86_64-unix/winemetal.so",
    "lib/wine/x86_64-windows/d3d10core.dll",
    "lib/wine/x86_64-windows/d3d11.dll",
    "lib/wine/x86_64-windows/dxgi.dll",
    "lib/wine/x86_64-windows/winemetal.dll",
    "lib/wine/x86_64-windows/d2d1.dll",
    "lib/wine/x86_64-windows/dwrite.dll",
]

func testCleanRuntimeSchema2ProvenanceGate() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-schema2-runtime-\(UUID().uuidString)", isDirectory: true)
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }

    var files: [String: String] = [:]
    for (index, key) in cleanRuntimeFileKeys.enumerated() {
        let url = root.appendingPathComponent(key)
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let payload = Data("synthetic-runtime-file-\(index)".utf8)
        try payload.write(to: url)
        files[key] = sha256Hex(payload)
    }
    let winemacRelative = "lib/wine/x86_64-unix/winemac.so"
    let winemacData = syntheticWinemacSO()
    try winemacData.write(to: root.appendingPathComponent(winemacRelative))
    files[winemacRelative] = sha256Hex(winemacData)
    let loadableHash = sha256Hex(winemacData.prefix(128))

    func manifest(_ overrides: (inout [String: Any]) -> Void = { _ in }) -> [String: Any] {
        let gate: [String: Any] = [
            "producedAt": "2026-09-07T00:00:00Z",
            "runtimeFiles": files,
            "winemacLoadableSha256": loadableHash,
            "fixtures": RosettaWineBackend.pinnedGateFixtureHashes,
            "results": ["fixtures": "pass", "compute100": "pass"],
        ]
        let provenance: [String: Any] = [
            "sources": RosettaWineBackend.pinnedSourceHashes,
            "patches": RosettaWineBackend.pinnedPatchHashes,
            "toolchain": ["mingw": "16.2.0", "llvm": "15.0.7"],
            "gate": gate,
        ]
        var m: [String: Any] = [
            "schema": 2,
            "kind": "ymm4m-clean-wine-dxmt",
            "wineVersion": "11.0",
            "architecture": "x86_64",
            "files": files,
            "provenance": provenance,
        ]
        overrides(&m)
        return m
    }

    func write(_ m: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: m)
        try data.write(to: root.appendingPathComponent("ymm4m-runtime.json"))
    }

    // Happy path: correct provenance + a recorded passing gate is accepted.
    try write(manifest())
    try RosettaWineBackend.validateCleanRuntime(at: root)

    // A tampered patch hash is rejected.
    try write(manifest { m in
        var p = m["provenance"] as! [String: Any]
        var patches = p["patches"] as! [String: String]
        patches["0001-dxmt-yymm4-compat.patch"] = String(repeating: "0", count: 64)
        p["patches"] = patches
        m["provenance"] = p
    })
    try expectThrows("tampered patch hash was accepted") {
        try RosettaWineBackend.validateCleanRuntime(at: root)
    }

    // A missing fixture in the gate is rejected.
    try write(manifest { m in
        var p = m["provenance"] as! [String: Any]
        var g = p["gate"] as! [String: Any]
        var fx = g["fixtures"] as! [String: String]
        fx.removeValue(forKey: "tests/fixtures/d2d-device6-reproducer.cpp")
        g["fixtures"] = fx
        p["gate"] = g
        m["provenance"] = p
    })
    try expectThrows("incomplete fixture gate was accepted") {
        try RosettaWineBackend.validateCleanRuntime(at: root)
    }

    // A non-pass gate result is rejected.
    try write(manifest { m in
        var p = m["provenance"] as! [String: Any]
        var g = p["gate"] as! [String: Any]
        g["results"] = ["fixtures": "pass", "compute100": "fail"]
        p["gate"] = g
        m["provenance"] = p
    })
    try expectThrows("a failing compute100 gate result was accepted") {
        try RosettaWineBackend.validateCleanRuntime(at: root)
    }

    // A gate run against different binaries than the manifest lists is rejected.
    try write(manifest { m in
        var p = m["provenance"] as! [String: Any]
        var g = p["gate"] as! [String: Any]
        var rf = g["runtimeFiles"] as! [String: String]
        rf["bin/wine"] = String(repeating: "1", count: 64)
        g["runtimeFiles"] = rf
        p["gate"] = g
        m["provenance"] = p
    })
    try expectThrows("a gate receipt for other binaries was accepted") {
        try RosettaWineBackend.validateCleanRuntime(at: root)
    }

    // schema 2 without provenance is rejected.
    try write(manifest { m in m.removeValue(forKey: "provenance") })
    try expectThrows("schema 2 without provenance was accepted") {
        try RosettaWineBackend.validateCleanRuntime(at: root)
    }

    // An on-disk file that no longer matches its manifest hash is rejected even
    // when the provenance block is otherwise perfect.
    try write(manifest())
    try Data("mutated".utf8).write(to: root.appendingPathComponent("bin/wine"))
    try expectThrows("a mutated runtime file was accepted") {
        try RosettaWineBackend.validateCleanRuntime(at: root)
    }
}

func expectThrows(_ message: String, _ body: () throws -> Void) throws {
    do {
        try body()
        throw ContractFailure.failed(message)
    } catch let failure as ContractFailure {
        throw failure
    } catch {
        // expected
    }
}

// MARK: - v1.0.1: bilingual core diagnostics (F2)

private func expectBilingualPair(_ japanese: String, _ english: String, _ label: String) throws {
    try expect(!japanese.isEmpty && !english.isEmpty, "\(label) has an empty rendering")
    try expect(japanese != english, "\(label) is not actually translated")
}

func testCoreErrorsAreBilingual() throws {
    let runtimeErrors: [RuntimeError] = [
        .invalidExecutable(URL(fileURLWithPath: "/tmp/YukkuriMovieMaker.exe")),
        .processFailed(3),
        .processTimedOut,
    ]
    for error in runtimeErrors {
        try expectBilingualPair(
            error.message(for: .japanese), error.message(for: .english), "\(error)"
        )
        try expect(
            error.errorDescription == error.message(for: CoreLanguage.current),
            "errorDescription bypassed the bilingual renderer for \(error)"
        )
    }
    // .unavailable carries text localized at the throw site; the contract is
    // verbatim passthrough, never a second translation pass.
    let stored = CoreMessages.setupFailed(language: .japanese)
    try expect(
        RuntimeError.unavailable(stored).message(for: .english) == stored,
        ".unavailable altered already-localized text"
    )

    let mappingErrors: [PathMappingError] = [.notAFileURL, .outsideMediaRoot, .unrepresentablePath]
    for error in mappingErrors {
        try expectBilingualPair(
            error.message(for: .japanese), error.message(for: .english), "\(error)"
        )
    }
    let driveErrors: [WineMediaDriveError] = [
        .missingPrefix, .missingMediaRoot, .missingDosDevices,
        .conflictingMapping("/tmp/other-media"),
    ]
    for error in driveErrors {
        let japanese = error.message(for: .japanese)
        let english = error.message(for: .english)
        try expectBilingualPair(japanese, english, "\(error)")
    }
    let conflict = WineMediaDriveError.conflictingMapping("/tmp/other-media")
    try expect(
        conflict.message(for: .japanese).contains("/tmp/other-media")
            && conflict.message(for: .english).contains("/tmp/other-media"),
        "conflictingMapping dropped the destination path"
    )

    let inputErrors: [YMM4TextInputError] = [
        .emptyText, .textTooLarge, .invalidHostPath, .temporaryFileCreationFailed,
    ]
    for error in inputErrors {
        try expectBilingualPair(
            error.message(for: .japanese), error.message(for: .english), "\(error)"
        )
    }
}

func testCoreMessagesAreBilingual() throws {
    // Every nullary message: non-empty and actually translated.
    let nullary: [(String, (CoreLanguage) -> String)] = [
        ("runtimeManifestMismatch", CoreMessages.runtimeManifestMismatch),
        ("winemacLoadableMismatch", CoreMessages.winemacLoadableMismatch),
        ("schema2ProvenanceMissing", CoreMessages.schema2ProvenanceMissing),
        ("provenanceSourcesMismatch", CoreMessages.provenanceSourcesMismatch),
        ("provenancePatchesMismatch", CoreMessages.provenancePatchesMismatch),
        ("provenanceToolchainTooOld", CoreMessages.provenanceToolchainTooOld),
        ("gateRuntimeMismatch", CoreMessages.gateRuntimeMismatch),
        ("gateLoadableMismatch", CoreMessages.gateLoadableMismatch),
        ("gateFixturesMismatch", CoreMessages.gateFixturesMismatch),
        ("gateResultsNotPass", CoreMessages.gateResultsNotPass),
        ("winemacMachOStructureInvalid", CoreMessages.winemacMachOStructureInvalid),
        ("winemacNotX86_64MachO", CoreMessages.winemacNotX86_64MachO),
        ("winemacLoadCommandInvalid", CoreMessages.winemacLoadCommandInvalid),
        ("winemacUUIDInvalid", CoreMessages.winemacUUIDInvalid),
        ("winemacLinkEditMissing", CoreMessages.winemacLinkEditMissing),
        ("wineNotConfigured", CoreMessages.wineNotConfigured),
        ("rosettaUnavailable", CoreMessages.rosettaUnavailable),
        ("cleanRuntimeUnidentifiable", CoreMessages.cleanRuntimeUnidentifiable),
        ("cleanRuntimeVerified", CoreMessages.cleanRuntimeVerified),
        ("archBridgeMissing", CoreMessages.archBridgeMissing),
        ("prefixEnvNotAbsolute", CoreMessages.prefixEnvNotAbsolute),
        ("dedicatedPrefixMissing", CoreMessages.dedicatedPrefixMissing),
        ("prefixMissingWPFProfile", CoreMessages.prefixMissingWPFProfile),
        ("invalidChannelName", CoreMessages.invalidChannelName),
        ("versionTargetVerificationFailed", CoreMessages.versionTargetVerificationFailed),
        ("existingChannelNotSymlink", CoreMessages.existingChannelNotSymlink),
        ("existingChannelOutsideStore", CoreMessages.existingChannelOutsideStore),
        ("setupMigratedLegacyPair", CoreMessages.setupMigratedLegacyPair),
        ("setupReusesVerifiedPair", CoreMessages.setupReusesVerifiedPair),
        ("setupStarted", CoreMessages.setupStarted),
        ("setupReusedVersionedPair", CoreMessages.setupReusedVersionedPair),
        ("setupCompleted", CoreMessages.setupCompleted),
        ("setupActivatedSuffix", CoreMessages.setupActivatedSuffix),
        ("setupPrefixReadinessFailed", CoreMessages.setupPrefixReadinessFailed),
        ("activePairNotReady", CoreMessages.activePairNotReady),
        ("activePairMismatch", CoreMessages.activePairMismatch),
        ("managedPathOutsideStore", CoreMessages.managedPathOutsideStore),
        ("recoveryNotDirectory", CoreMessages.recoveryNotDirectory),
        ("recoveryOutsideStore", CoreMessages.recoveryOutsideStore),
        ("setupResourcesMissing", CoreMessages.setupResourcesMissing),
        ("setupFailed", CoreMessages.setupFailed),
        ("catalogUnsupportedFormat", CoreMessages.catalogUnsupportedFormat),
        ("catalogInvalidEntries", CoreMessages.catalogInvalidEntries),
        ("catalogMissingMaintenancePolicy", CoreMessages.catalogMissingMaintenancePolicy),
        ("maintenancePolicyInvalid", CoreMessages.maintenancePolicyInvalid),
        ("archiveNotOfficialZIP", CoreMessages.archiveNotOfficialZIP),
        ("archiveExceedsSizeLimit", CoreMessages.archiveExceedsSizeLimit),
        ("noPreviousYMM4", CoreMessages.noPreviousYMM4),
        ("previousYMM4FailsCatalog", CoreMessages.previousYMM4FailsCatalog),
        ("rolledBackExecutableUnverifiable", CoreMessages.rolledBackExecutableUnverifiable),
        ("archiveLaunchForbidden", CoreMessages.archiveLaunchForbidden),
        ("maintenanceReceiptMismatch", CoreMessages.maintenanceReceiptMismatch),
        ("maintenanceCompletionFailed", CoreMessages.maintenanceCompletionFailed),
        ("ymm4ChannelOutsideStore", CoreMessages.ymm4ChannelOutsideStore),
        ("ymm4RecoveryNotDirectory", CoreMessages.ymm4RecoveryNotDirectory),
        ("ymm4RecoveryOutsideStore", CoreMessages.ymm4RecoveryOutsideStore),
        ("candidateNotValidPE", CoreMessages.candidateNotValidPE),
        ("candidateNotAMD64GUI", CoreMessages.candidateNotAMD64GUI),
        ("userDataLinkElsewhere", CoreMessages.userDataLinkElsewhere),
        ("userDataDuplicated", CoreMessages.userDataDuplicated),
        ("userPathNotDirectory", CoreMessages.userPathNotDirectory),
        ("extractedExecutableHashFailed", CoreMessages.extractedExecutableHashFailed),
        ("archiveExtractionUninspectable", CoreMessages.archiveExtractionUninspectable),
        ("archiveFileCountExceeded", CoreMessages.archiveFileCountExceeded),
        ("archiveForbiddenFileType", CoreMessages.archiveForbiddenFileType),
        ("archiveStructureInvalid", CoreMessages.archiveStructureInvalid),
        ("archiveExtractionFailed", CoreMessages.archiveExtractionFailed),
        ("archiveExpandedSizeExceeded", CoreMessages.archiveExpandedSizeExceeded),
        ("officialReleaseUnverifiable", CoreMessages.officialReleaseUnverifiable),
        ("archiveNotStableAsset", CoreMessages.archiveNotStableAsset),
        ("officialDigestMalformed", CoreMessages.officialDigestMalformed),
        ("archiveSizeMismatch", CoreMessages.archiveSizeMismatch),
        ("archiveDigestMismatch", CoreMessages.archiveDigestMismatch),
        ("archiveFileNameChanged", CoreMessages.archiveFileNameChanged),
        ("researchBackendDisabled", CoreMessages.researchBackendDisabled),
    ]
    for (label, render) in nullary {
        try expectBilingualPair(render(.japanese), render(.english), label)
    }
    try expect(
        CoreMessages.rosettaUnavailable(language: .japanese).contains("softwareupdate")
            && CoreMessages.rosettaUnavailable(language: .english).contains("softwareupdate"),
        "rosettaUnavailable dropped the remediation command"
    )

    // Interpolated values must survive in both languages.
    try expect(
        CoreMessages.runtimeFileMissing("lib/wine/x86_64-windows/dwrite.dll", language: .japanese)
            .contains("dwrite.dll")
            && CoreMessages.runtimeFileMissing("lib/wine/x86_64-windows/dwrite.dll", language: .english)
            .contains("dwrite.dll"),
        "runtimeFileMissing dropped the relative path"
    )
    try expect(
        CoreMessages.unsupportedManifestSchema(9, language: .japanese).contains("9")
            && CoreMessages.unsupportedManifestSchema(9, language: .english).contains("9"),
        "unsupportedManifestSchema dropped the schema number"
    )
    try expect(
        CoreMessages.channelAtomicSwitchFailed(13, language: .japanese).contains("13")
            && CoreMessages.channelAtomicSwitchFailed(13, language: .english).contains("13"),
        "channelAtomicSwitchFailed dropped errno"
    )
    let sampleHash = String(repeating: "a", count: 64)
    let unverifiedJA = CoreMessages.archiveUnverified(sampleHash, language: .japanese)
    let unverifiedEN = CoreMessages.archiveUnverified(sampleHash, language: .english)
    try expectBilingualPair(unverifiedJA, unverifiedEN, "archiveUnverified")
    try expect(unverifiedJA.contains(sampleHash) && unverifiedEN.contains(sampleHash),
               "archiveUnverified dropped the archive hash")
    try expectBilingualPair(
        CoreMessages.recoveredIncompleteChannel("current", "/tmp/recovery/x", language: .japanese),
        CoreMessages.recoveredIncompleteChannel("current", "/tmp/recovery/x", language: .english),
        "recoveredIncompleteChannel"
    )
}

// MARK: - v1.0.1: Rosetta fallback and arch preflight (F3)

func testRosettaAvailabilityDecision() throws {
    var probed = false
    try expect(
        RosettaWineBackend.rosettaAvailable(oahdExists: true, archProbe: {
            probed = true
            return true
        }),
        "present Rosetta marker was reported unavailable"
    )
    try expect(!probed, "arch probe ran even though the Rosetta marker exists")
    try expect(
        RosettaWineBackend.rosettaAvailable(oahdExists: false, archProbe: { true }),
        "working arch probe was reported unavailable"
    )
    try expect(
        !RosettaWineBackend.rosettaAvailable(oahdExists: false, archProbe: { false }),
        "missing Rosetta was reported available"
    )
}

func testArchBridgeAndLiveRosettaProbe() throws {
    // /usr/bin/arch ships with macOS itself; its absence (a bare-bones host)
    // must be detected, never assumed.
    try expect(
        RosettaWineBackend.archExecutableURL() != nil,
        "/usr/bin/arch was not found on this Mac"
    )
    // The live execution probe must agree with the marker in the direction
    // that matters: a present marker implies working x86_64 execution.
    // (On a host without Rosetta both are false; that is the fail-closed path.)
    let oahdExists = FileManager.default.fileExists(atPath: "/usr/libexec/rosetta/oahd")
    if oahdExists {
        try expect(
            RosettaWineBackend.runArchX86_64Probe(),
            "Rosetta marker exists but x86_64 execution probe failed"
        )
    }
}

// MARK: - v1.0.1: untested-host notice (F4)

func testHostCompatibilityNotice() throws {
    let validated = OperatingSystemVersion(majorVersion: 26, minorVersion: 5, patchVersion: 0)
    try expect(
        HostCompatibility.untestedOSNotice(osVersion: validated, language: .japanese) == nil
            && HostCompatibility.untestedOSNotice(osVersion: validated, language: .english) == nil,
        "validated macOS 26 host received an untested-OS notice"
    )
    let future = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
    let futureJA = HostCompatibility.untestedOSNotice(osVersion: future, language: .japanese)
    let futureEN = HostCompatibility.untestedOSNotice(osVersion: future, language: .english)
    guard let futureJA, let futureEN else {
        throw ContractFailure.failed("future macOS received no untested-OS notice")
    }
    try expectBilingualPair(futureJA, futureEN, "untestedOSNotice")
    try expect(futureJA.contains("27") && futureEN.contains("27"),
               "untested-OS notice dropped the OS version")
    let legacy = OperatingSystemVersion(majorVersion: 25, minorVersion: 0, patchVersion: 0)
    try expect(
        HostCompatibility.untestedOSNotice(osVersion: legacy, language: .english) != nil,
        "pre-26 macOS received no untested-OS notice"
    )
}

// MARK: - v1.0.2: whitespace-free compile cache (setup hardening)

func testCompileCacheRootAvoidsWhitespace() throws {
    let manager = FileManager.default
    let temporary = manager.temporaryDirectory
        .appendingPathComponent("ymm4m-compile-cache-test-\(UUID().uuidString)", isDirectory: true)

    // A normal home keeps the usual per-user cache.
    let clean = RuntimeBootstrapper.compileCacheRoot(
        home: URL(fileURLWithPath: "/Users/example"), temporaryDirectory: temporary
    )
    try expect(
        clean.path == "/Users/example/Library/Caches/YMM4M",
        "clean home did not keep the per-user compile cache"
    )

    // A home containing a space or tab (possible on any Mac) must not reach
    // the Wine build's whitespace-intolerant make variables.
    for home in ["/Users/has space", "/Users/has\ttab"] {
        let fallback = RuntimeBootstrapper.compileCacheRoot(
            home: URL(fileURLWithPath: home), temporaryDirectory: temporary
        )
        try expect(
            fallback.path == temporary.appendingPathComponent("YMM4M-Build").path,
            "whitespace home did not fall back to the temporary build root"
        )
        try expect(
            !fallback.path.contains(" ") && !fallback.path.contains("\t"),
            "compile-cache fallback still contains whitespace"
        )
    }
}

@main
struct ContractTests {
    static func main() async throws {
        try testProtocolRoundTrip()
        testRejectsOversizedMessage()
        try testMapsOnlyInsideMediaRoot()
        try testConfiguresMediaDriveWithoutOverwriting()
        try testUnknownYMM4ExecutableIsClassifiedByHash()
        try testRedactsSensitiveValues()
        try testWineLaunchEnvironmentUsesAllowList()
        try testWineLaunchEnvironmentDefaultsToQuietWinedebug()
        try testCoreErrorsAreBilingual()
        try testCoreMessagesAreBilingual()
        try testRosettaAvailabilityDecision()
        try testArchBridgeAndLiveRosettaProbe()
        try testHostCompatibilityNotice()
        try testCompileCacheRootAvoidsWhitespace()
        try testCleanRuntimeSchema2ProvenanceGate()
        try testTextInputBridgePathAndLimits()
        try testAutomaticSetupUsesDedicatedDefaultPaths()
        try testAutomaticSetupRecoversIncompleteManagedState()
        try testAutomaticSetupPopulatesDeveloperSelectedStoreRoots()
        try await testAutomaticSetupStreamsProgressAndWritesFailureLog()
        try await testConfiguredAutomaticSetupActivationWhenRequested()
        try await testConfiguredIncompleteCompleteSetupRecoveryWhenRequested()
        try testStoredSettingsPersistAndMigrateManagedPaths()
        try await testVersionedChannelAndYMM4ZIPInstall()
        try await testOfficialMaintenanceCandidateAndRollback()
        try await testConfiguredRealYMM4ArchiveWhenProvided()
        try await testConfiguredCleanRuntimeWhenProvided()
        try await testConfiguredTextInputBridgeWhenRequested()
        try await testUnavailableWineIsReportedWithoutLaunching()
        print("YMM4M contract tests passed")
    }
}
