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

    let external = root.appendingPathComponent("external", isDirectory: true)
    try manager.createDirectory(at: external, withIntermediateDirectories: false)
    let current = store.appendingPathComponent("current")
    try manager.removeItem(at: current)
    try manager.createSymbolicLink(at: current, withDestinationURL: external)
    do {
        _ = try await YMM4ArchiveInstaller.install(
            archive: archive, catalog: catalog, paths: YMM4InstallationPaths(store: store)
        )
        throw ContractFailure.failed("external YMM4 current channel was replaced")
    } catch RuntimeError.unavailable {}
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
        try testTextInputBridgePathAndLimits()
        try testAutomaticSetupUsesDedicatedDefaultPaths()
        try await testVersionedChannelAndYMM4ZIPInstall()
        try await testConfiguredRealYMM4ArchiveWhenProvided()
        try await testConfiguredCleanRuntimeWhenProvided()
        try await testConfiguredTextInputBridgeWhenRequested()
        try await testUnavailableWineIsReportedWithoutLaunching()
        print("YMM4M contract tests passed")
    }
}
