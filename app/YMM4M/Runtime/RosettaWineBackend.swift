import Foundation
import CryptoKit

public actor RosettaWineBackend: RuntimeBackend {
    public nonisolated let identifier = "rosetta-wine"
    public nonisolated let supportLevel: RuntimeSupportLevel = .productionCandidate

    private let wineURL: URL?
    private let runtimeRootURL: URL?
    private let prefixURL: URL?
    private var process: Process?

    public init(
        wineURL: URL? = RosettaWineBackend.findWine(),
        runtimeRootURL: URL? = nil,
        prefixURL: URL? = nil
    ) {
        self.wineURL = wineURL
        self.runtimeRootURL = runtimeRootURL ?? wineURL.flatMap(Self.runtimeRoot(for:))
        self.prefixURL = prefixURL
    }

    public nonisolated static func findWine(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        if let runtime = environment["YMM4M_RUNTIME"] {
            let candidate = URL(fileURLWithPath: runtime).appendingPathComponent("bin/wine")
            if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        if let configured = environment["YMM4M_WINE"], FileManager.default.isExecutableFile(atPath: configured) {
            return URL(fileURLWithPath: configured)
        }
        return nil
    }

    public nonisolated static func runtimeRoot(for wineURL: URL) -> URL? {
        let standardized = wineURL.standardizedFileURL
        guard standardized.lastPathComponent == "wine",
              standardized.deletingLastPathComponent().lastPathComponent == "bin" else { return nil }
        return standardized.deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Pure Rosetta-availability decision so it stays unit-testable.
    ///
    /// The primary signal is the Rosetta runtime marker, which exists on all
    /// supported macOS 26 releases. The `arch -x86_64` execution probe is only
    /// a fallback for configurations where the marker path moved (for example
    /// a future macOS that relocates Intel translation); it is never run when
    /// the marker is present, so probing adds no latency to normal launches.
    public nonisolated static func rosettaAvailable(
        oahdExists: Bool,
        archProbe: () -> Bool
    ) -> Bool {
        oahdExists || archProbe()
    }

    /// Returns true when this Mac can execute x86_64 binaries through Rosetta.
    /// Runs `/usr/bin/arch -x86_64 /usr/bin/true`: no Wine, prefix, or network
    /// involved, and no state is changed.
    public nonisolated static func runArchX86_64Probe() -> Bool {
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
        probe.arguments = ["-x86_64", "/usr/bin/true"]
        probe.standardOutput = FileHandle.nullDevice
        probe.standardError = FileHandle.nullDevice
        guard (try? probe.run()) != nil else { return false }
        probe.waitUntilExit()
        return probe.terminationReason == .exit && probe.terminationStatus == 0
    }

    /// The `arch` bridge used to run the validated x86_64 Wine executable, or
    /// nil when the host tool is missing (for example a bare CLT install
    /// without `/usr/bin/arch`). Callers fail closed with a localized message
    /// instead of surfacing a raw spawn error.
    public nonisolated static func archExecutableURL(
        fileManager: FileManager = .default
    ) -> URL? {
        let url = URL(fileURLWithPath: "/usr/bin/arch")
        return fileManager.isExecutableFile(atPath: url.path) ? url : nil
    }

    public nonisolated static func launchEnvironment(
        inherited: [String: String] = ProcessInfo.processInfo.environment,
        runtimeRoot: URL? = nil,
        prefixURL: URL? = nil
    ) -> [String: String] {
        let allowedKeys = [
            "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE",
            "WINEDEBUG", "WINEDLLOVERRIDES", "WINEESYNC", "WINEFSYNC",
        ]
        var environment = Dictionary(uniqueKeysWithValues: allowedKeys.compactMap { key in
            inherited[key].map { (key, $0) }
        })
        if let prefixURL {
            environment["WINEPREFIX"] = prefixURL.standardizedFileURL.path
        } else if let configuredPrefix = inherited["YMM4M_PREFIX"] {
            environment["WINEPREFIX"] = configuredPrefix
        }
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        // Default to Wine's quietest channel set. Verbose tracing
        // (+timestamp,+pid,+tid,+seh,+loaddll) slows YMM4, floods the setup log,
        // and fills the disk in real use. A developer can still opt in per run by
        // exporting YMM4M_WINEDEBUG, or by setting WINEDEBUG directly.
        environment["WINEDEBUG"] = inherited["YMM4M_WINEDEBUG"]
            ?? environment["WINEDEBUG"]
            ?? "-all"
        if let runtimeRoot {
            environment["WINEDLLPATH"] = [
                runtimeRoot.appendingPathComponent("lib/wine").path,
                runtimeRoot.appendingPathComponent("lib/dxmt").path,
            ].joined(separator: ":")
            environment["WINEDLLOVERRIDES"] = "d3d10core,d3d11,dxgi,winemetal,d2d1,dwrite=b"
        }
        return environment
    }

    public nonisolated static func isSafePrefixPath(_ path: String, home: String?) -> Bool {
        guard path.hasPrefix("/") else { return false }
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        if standardized == "/" || standardized.isEmpty { return false }
        if let home,
           standardized == URL(fileURLWithPath: home).standardizedFileURL.resolvingSymlinksInPath().path {
            return false
        }
        return true
    }

    public nonisolated static func registryContainsRequiredWPFSoftwareProfile(_ registry: String) -> Bool {
        var inAvalonGraphics = false
        for rawLine in registry.split(whereSeparator: \Character.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("[") {
                inAvalonGraphics = line.lowercased().hasPrefix("[software\\\\microsoft\\\\avalon.graphics]")
            } else if inAvalonGraphics,
                      line.lowercased() == "\"disablehwacceleration\"=dword:00000001" {
                return true
            }
        }
        return false
    }

    public nonisolated static func hasRequiredWPFSoftwareProfile(at prefix: URL) -> Bool {
        let registryURL = prefix.appendingPathComponent("user.reg")
        guard let registry = try? String(contentsOf: registryURL, encoding: .utf8) else { return false }
        return registryContainsRequiredWPFSoftwareProfile(registry)
    }

    private struct VerifiedRuntimeVariant: Sendable {
        let hashes: [String: String]
        let winemacLoadableHash: String
    }

    // Homebrew's MinGW compiler is not ABI-output-stable across major releases.
    // Retain the previously audited build and the independently reproduced GCC
    // 16.2 build as explicit whole-file variants; do not accept arbitrary local
    // manifests or partial hash matches.
    private nonisolated static let verifiedRuntimeVariants: [VerifiedRuntimeVariant] = [
        VerifiedRuntimeVariant(
            hashes: [
                "bin/wine": "bad3b6126b6612680e26302c0e0b7e56d6c7036eac9bf6313878bdd9039b003f",
                "lib/wine/x86_64-unix/winemetal.so": "62777419bdbec505e72d257279976e8bcd71bbf8a895239d729dcec9d56a3ebc",
                "lib/wine/x86_64-windows/d3d10core.dll": "da8e44c09306aae35bb39958b1e1857089580939c4f38ea2022d3b1e0afcfb33",
                "lib/wine/x86_64-windows/d3d11.dll": "477fbdb9adae141521351b012fa8f7d818a5a1ea292a6d59bada4aa1905aa62a",
                "lib/wine/x86_64-windows/dxgi.dll": "3c0b3efbcab0079e892eee61680ec5863adcc17541fd54942daf94b41784c973",
                "lib/wine/x86_64-windows/winemetal.dll": "6e44b61fc81f1938cdcab4918dbf0ef7feb376eb228a3699226e948a664707a3",
                "lib/wine/x86_64-windows/d2d1.dll": "bfd7d57f6cb286639adaa575ace42cc3a9e75574d2f93398d159cd356218e77d",
                "lib/wine/x86_64-windows/dwrite.dll": "83411068ee8b7e3c009a4fd54900a2f1d696e525fee622a2105c5ea6d52e665c",
            ],
            winemacLoadableHash: "feec5cee6ad6f16368166a599ded5b4d9de7cb3a9653a7e3565c7f7c185b6508"
        ),
        VerifiedRuntimeVariant(
            hashes: [
                "bin/wine": "bad3b6126b6612680e26302c0e0b7e56d6c7036eac9bf6313878bdd9039b003f",
                "lib/wine/x86_64-unix/winemetal.so": "08fd89bacb2951645399b650e6b53898118380a990e3327d8fda2d0d514cd984",
                "lib/wine/x86_64-windows/d3d10core.dll": "edb0e8e6bff32ac4d524e351109d04dd5734f4e421bd5799cade2cd8eb89aaa1",
                "lib/wine/x86_64-windows/d3d11.dll": "8a385478e6b8411b9e2757ab434aa65cfe990572629fa06a2d17382842f707f2",
                "lib/wine/x86_64-windows/dxgi.dll": "8a84c2d668e9348c7fd1da08d3f41e415532e5b9b64268a24de238cdc029b00a",
                "lib/wine/x86_64-windows/winemetal.dll": "78eace9661e6f3aa9f8d3564d502fcddaa29b8e5463fe2615d7e7ccf439b38dc",
                "lib/wine/x86_64-windows/d2d1.dll": "bd413f453831ac391279a98e0dea24ddeed68c2f599341ce24081981faa51876",
                "lib/wine/x86_64-windows/dwrite.dll": "c7a492303b042799c70ebed354a03de074cead2af3dbfb6360d6e93dea30f959",
            ],
            winemacLoadableHash: "265c7ec2b4979f62a4afc0780ac66401174ddc6a1ce2baa7a72854beb649e6f6"
        ),
    ]

    private nonisolated static let winemacPath = "lib/wine/x86_64-unix/winemac.so"

    /// SHA-256 of the pinned bootstrap source archives, copied verbatim from
    /// `runtime/bootstrap.lock.json`. A schema-2 runtime manifest must attest
    /// that it was built from exactly these inputs.
    public nonisolated static let pinnedSourceHashes: [String: String] = [
        "wineSource": "f09e8153aa46a581d2b56a5b1363b04832070b9409d9244a68cf482b243ff14a",
        "wineMacBase": "b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388",
        "freetypeSource": "36bc4f1cc413335368ee656c42afca65c5a3987e8768cc28cf11ba775e785a5f",
        "dxmt": "bc8015eb558ccbc3af8ffb391583ff7362ddac87980a87a65db481b9f360efa3",
        "nvapi": "436936c965f711f743c8606cb7c2621736cecf41e0fd6557555b2f1903b0350f",
        "directxHeaders": "9c1b8bbfd2d6c758fac4d93c2808a46bc1eee429fe656b4f21b29e02615aa8aa",
    ]

    /// SHA-256 of the four evidence-based patches applied during the build.
    public nonisolated static let pinnedPatchHashes: [String: String] = [
        "0001-dxmt-yymm4-compat.patch": "87946d1765cec7cd973fbc7f8c27da77c8ca4fa347ee00699b697892ee5412ef",
        "0002-wine-d2d1-yymm4-compat.patch": "512486ee10341266122ece1af860a0f551eec0ac04bd42654534b6978d2450ef",
        "0003-wine-dwrite-locale-fallback.patch": "2d136e978774a0b07e33f01268a2f763b8fe391b1ec5fa0ae2d910ba1aed33f1",
        "0004-wine-macdrv-metal-view-bridge.patch": "e5e0a5dc835f686978fecc9e16625da11a04192e41fcd0ced85a8a3605406d44",
    ]

    /// SHA-256 of the eight compatibility fixture sources whose pass, plus a
    /// 100-iteration compute run, is the schema-2 acceptance gate.
    public nonisolated static let pinnedGateFixtureHashes: [String: String] = [
        "tests/fixtures/d3d11-compute-pipeline-reproducer.cpp": "434375c5614742605486e2a0c3a76cf931f1812de86e578add649f53df72cfba",
        "tests/fixtures/d3d11-context-state-reproducer.cpp": "1365cf534b9b86f87dfde5eba843bf5e5df88c8e4441a531b86c82101f205656",
        "tests/fixtures/dxgi-surface2-reproducer.cpp": "424019bbd50c66a761bf18f5aeb4ab8f202682e3f6346f53a6c114e0a942a575",
        "tests/fixtures/d2d-device6-reproducer.cpp": "e8a64f9b4140916135c4fe3d4e5f159e6af3aa46df74ed798d7e0383b610649b",
        "tests/fixtures/d2d-null-effect-input-reproducer.cpp": "e10cc92062876d3f0956ab8602f8a7d613a98583655fbb1bc83be38188eb7637",
        "tests/fixtures/d2d-3d-transform-reproducer.cpp": "adf5ad4d57309793fb67ffbc9e8bffbed4ae9473a53be0cbb7e262c1c918a4f6",
        "tests/fixtures/d2d-japanese-text-reproducer.cpp": "160f18a80bdeaa48d706c1bd39fb0d84544a4bf9eec1ea40db109ff08293fc27",
        "tests/fixtures/dwrite-font-fallback-reproducer.cpp": "bd476ecaef97deb57ad5e4db525b8dfcb16e5e49350e3bb63b0a9c2635edc928",
    ]

    private struct RuntimeManifest: Decodable {
        struct GateReceipt: Decodable {
            let producedAt: String
            let runtimeFiles: [String: String]
            let winemacLoadableSha256: String
            let fixtures: [String: String]
            let results: [String: String]
        }
        struct Provenance: Decodable {
            let sources: [String: String]
            let patches: [String: String]
            let toolchain: [String: String]
            let gate: GateReceipt
        }
        let schema: Int
        let kind: String
        let wineVersion: String
        let architecture: String
        let files: [String: String]
        let provenance: Provenance?
    }

    /// Accepts a locally built clean Wine 11.0 / source-patched DXMT runtime.
    ///
    /// Schema 1 (unchanged): the manifest must match one of the audited
    /// whole-file PE hash variants exactly, plus the corresponding `winemac.so`
    /// loadable-image hash.
    ///
    /// Schema 2 (added, §4.1 案3): whole-file PE hashes are no longer pinned to a
    /// small set of audited toolchain outputs. Instead the manifest must attest,
    /// and this function re-checks, that:
    ///   * every listed runtime file exists and matches its recorded SHA-256,
    ///   * the build used exactly the pinned bootstrap source archives and the
    ///     four evidence-based patches (`pinnedSourceHashes` / `pinnedPatchHashes`),
    ///   * a compatibility-fixture gate (the eight `pinnedGateFixtureHashes`
    ///     sources plus a 100-iteration compute run) passed against *these* exact
    ///     binaries, and
    ///   * the recorded `winemac.so` loadable-image hash matches the file on disk.
    /// This lets any reasonably current cross toolchain produce a runtime that
    /// still boots on a third machine, while keeping input integrity, patch
    /// integrity, and a behavioural gate as the trust anchors.
    public nonisolated static func validateCleanRuntime(at root: URL) throws {
        let manifestURL = root.appendingPathComponent("ymm4m-runtime.json")
        let manifest = try JSONDecoder().decode(RuntimeManifest.self, from: Data(contentsOf: manifestURL))
        let expectedKeys = Set(verifiedRuntimeVariants[0].hashes.keys).union([winemacPath])
        guard manifest.kind == "ymm4m-clean-wine-dxmt",
              manifest.wineVersion == "11.0",
              manifest.architecture == "x86_64",
              Set(manifest.files.keys) == expectedKeys,
              isHex64(manifest.files[winemacPath]) else {
            throw RuntimeError.unavailable(CoreMessages.runtimeManifestMismatch())
        }

        // Every listed file must exist and match the manifest's own hash. This is
        // required for both schemas before any schema-specific trust check.
        for relativePath in manifest.files.keys.sorted() {
            let expectedHash = manifest.files[relativePath]!.lowercased()
            guard isHex64(expectedHash) else {
                throw RuntimeError.unavailable(CoreMessages.runtimeFileHashMalformed(relativePath))
            }
            let fileURL = root.appendingPathComponent(relativePath)
            guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
                throw RuntimeError.unavailable(CoreMessages.runtimeFileMissing(relativePath))
            }
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            let actualHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard actualHash == expectedHash else {
                throw RuntimeError.unavailable(CoreMessages.runtimeFileHashMismatch(relativePath))
            }
        }

        let winemacURL = root.appendingPathComponent(winemacPath)
        let loadableHash = try machOLoadableSHA256(at: winemacURL)

        switch manifest.schema {
        case 1:
            guard let verifiedVariant = verifiedRuntimeVariants.first(where: { variant in
                variant.hashes.allSatisfy { manifest.files[$0.key] == $0.value }
            }) else {
                throw RuntimeError.unavailable(CoreMessages.runtimeManifestMismatch())
            }
            guard loadableHash == verifiedVariant.winemacLoadableHash else {
                throw RuntimeError.unavailable(CoreMessages.winemacLoadableMismatch())
            }
        case 2:
            guard let provenance = manifest.provenance else {
                throw RuntimeError.unavailable(CoreMessages.schema2ProvenanceMissing())
            }
            try validateSchema2Provenance(
                provenance,
                manifestFiles: manifest.files,
                actualLoadableHash: loadableHash
            )
        default:
            throw RuntimeError.unavailable(CoreMessages.unsupportedManifestSchema(manifest.schema))
        }
    }

    private nonisolated static func isHex64(_ value: String?) -> Bool {
        guard let value else { return false }
        return value.count == 64 && value.allSatisfy { $0.isHexDigit && ($0.isNumber || $0.isLowercase) }
    }

    private nonisolated static func validateSchema2Provenance(
        _ provenance: RuntimeManifest.Provenance,
        manifestFiles: [String: String],
        actualLoadableHash: String
    ) throws {
        // Pinned inputs: exactly the recorded source archives and patches, no
        // more and no fewer.
        guard Set(provenance.sources.keys) == Set(pinnedSourceHashes.keys),
              pinnedSourceHashes.allSatisfy({ provenance.sources[$0.key]?.lowercased() == $0.value }) else {
            throw RuntimeError.unavailable(CoreMessages.provenanceSourcesMismatch())
        }
        guard Set(provenance.patches.keys) == Set(pinnedPatchHashes.keys),
              pinnedPatchHashes.allSatisfy({ provenance.patches[$0.key]?.lowercased() == $0.value }) else {
            throw RuntimeError.unavailable(CoreMessages.provenancePatchesMismatch())
        }

        // Toolchain range: informational, but a nonsensically old cross compiler
        // could not have produced a passing runtime.
        if let mingw = provenance.toolchain["mingw"],
           let major = Int(mingw.split(separator: ".").first.map(String.init) ?? ""),
           major < 13 {
            throw RuntimeError.unavailable(CoreMessages.provenanceToolchainTooOld())
        }

        // The behavioural gate must have run against exactly these binaries.
        let normalizedManifest = manifestFiles.mapValues { $0.lowercased() }
        guard provenance.gate.runtimeFiles.mapValues({ $0.lowercased() }) == normalizedManifest else {
            throw RuntimeError.unavailable(CoreMessages.gateRuntimeMismatch())
        }
        guard provenance.gate.winemacLoadableSha256.lowercased() == actualLoadableHash else {
            throw RuntimeError.unavailable(CoreMessages.gateLoadableMismatch())
        }
        guard Set(provenance.gate.fixtures.keys) == Set(pinnedGateFixtureHashes.keys),
              pinnedGateFixtureHashes.allSatisfy({ provenance.gate.fixtures[$0.key]?.lowercased() == $0.value }) else {
            throw RuntimeError.unavailable(CoreMessages.gateFixturesMismatch())
        }
        guard provenance.gate.results["fixtures"] == "pass",
              provenance.gate.results["compute100"] == "pass" else {
            throw RuntimeError.unavailable(CoreMessages.gateResultsNotPass())
        }
    }

    public nonisolated static func machOLoadableSHA256(at url: URL) throws -> String {
        var data = try Data(contentsOf: url)
        func uint32(_ offset: Int) throws -> UInt32 {
            guard offset >= 0, offset + 4 <= data.count else {
                throw RuntimeError.unavailable(CoreMessages.winemacMachOStructureInvalid())
            }
            return data.withUnsafeBytes {
                UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
            }
        }
        func uint64(_ offset: Int) throws -> UInt64 {
            guard offset >= 0, offset + 8 <= data.count else {
                throw RuntimeError.unavailable(CoreMessages.winemacMachOStructureInvalid())
            }
            return data.withUnsafeBytes {
                UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
            }
        }

        guard try uint32(0) == 0xfeedfacf, try uint32(4) == 0x01000007 else {
            throw RuntimeError.unavailable(CoreMessages.winemacNotX86_64MachO())
        }
        let commandCount = Int(try uint32(16))
        var commandOffset = 32
        var linkEditOffset: Int?
        for _ in 0..<commandCount {
            let command = try uint32(commandOffset)
            let commandSize = Int(try uint32(commandOffset + 4))
            guard commandSize >= 8, commandOffset + commandSize <= data.count else {
                throw RuntimeError.unavailable(CoreMessages.winemacLoadCommandInvalid())
            }
            if command == 0x1b {
                guard commandSize >= 24 else {
                    throw RuntimeError.unavailable(CoreMessages.winemacUUIDInvalid())
                }
                data.replaceSubrange((commandOffset + 8)..<(commandOffset + 24), with: repeatElement(0, count: 16))
            } else if command == 0x19, commandSize >= 72 {
                let nameData = data[(commandOffset + 8)..<(commandOffset + 24)]
                let name = String(decoding: nameData.prefix { $0 != 0 }, as: UTF8.self)
                if name == "__LINKEDIT" {
                    linkEditOffset = Int(try uint64(commandOffset + 40))
                }
            }
            commandOffset += commandSize
        }
        guard let linkEditOffset, linkEditOffset >= commandOffset, linkEditOffset <= data.count else {
            throw RuntimeError.unavailable(CoreMessages.winemacLinkEditMissing())
        }
        return SHA256.hash(data: data.prefix(linkEditOffset))
            .map { String(format: "%02x", $0) }.joined()
    }

    public func probe() async throws -> RuntimeProbeResult {
        guard let wineURL else {
            return RuntimeProbeResult(available: false, architecture: "x86_64", runtimePath: nil,
                                       reason: CoreMessages.wineNotConfigured())
        }
        let oahdExists = FileManager.default.fileExists(atPath: "/usr/libexec/rosetta/oahd")
        guard Self.rosettaAvailable(oahdExists: oahdExists, archProbe: Self.runArchX86_64Probe) else {
            return RuntimeProbeResult(available: false, architecture: "x86_64", runtimePath: wineURL.path,
                                      reason: CoreMessages.rosettaUnavailable())
        }
        guard let runtimeRootURL else {
            return RuntimeProbeResult(available: false, architecture: "x86_64", runtimePath: wineURL.path,
                                       reason: CoreMessages.cleanRuntimeUnidentifiable())
        }
        do {
            try Self.validateCleanRuntime(at: runtimeRootURL)
        } catch {
            return RuntimeProbeResult(available: false, architecture: "x86_64", runtimePath: wineURL.path,
                                      reason: error.localizedDescription)
        }
        return RuntimeProbeResult(available: true, architecture: "x86_64", runtimePath: wineURL.path,
                                   reason: CoreMessages.cleanRuntimeVerified())
    }

    public func prepare() async throws {
        let result = try await probe()
        guard result.available else { throw RuntimeError.unavailable(result.reason) }
    }

    public func launch(executable: URL, arguments: [String]) async throws -> RuntimeProcessHandle {
        let (wineURL, archURL, environment) = try await validatedLaunchConfiguration(for: executable)

        let child = Process()
        child.executableURL = archURL
        child.arguments = ["-x86_64", wineURL.path, executable.path] + arguments
        child.environment = environment
        try child.run()
        process = child
        return RuntimeProcessHandle(processIdentifier: child.processIdentifier)
    }

    public func runAuxiliary(executable: URL, arguments: [String]) async throws {
        let (wineURL, archURL, environment) = try await validatedLaunchConfiguration(for: executable)
        let child = Process()
        child.executableURL = archURL
        child.arguments = ["-x86_64", wineURL.path, executable.path] + arguments
        child.environment = environment
        try child.run()
        let deadline = ContinuousClock.now + .seconds(10)
        while child.isRunning, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        if child.isRunning {
            child.terminate()
            child.waitUntilExit()
            throw RuntimeError.processTimedOut
        }
        guard child.terminationReason == .exit, child.terminationStatus == 0 else {
            throw RuntimeError.processFailed(child.terminationStatus)
        }
    }

    private func validatedLaunchConfiguration(for executable: URL) async throws -> (URL, URL, [String: String]) {
        try await prepare()
        guard executable.isFileURL, FileManager.default.isReadableFile(atPath: executable.path) else {
            throw RuntimeError.invalidExecutable(executable)
        }
        guard let wineURL else { throw RuntimeError.unavailable(CoreMessages.wineNotConfigured()) }
        guard let archURL = Self.archExecutableURL() else {
            throw RuntimeError.unavailable(CoreMessages.archBridgeMissing())
        }

        let environment = Self.launchEnvironment(runtimeRoot: runtimeRootURL, prefixURL: prefixURL)
        guard let prefix = environment["WINEPREFIX"],
              Self.isSafePrefixPath(prefix, home: environment["HOME"]) else {
            throw RuntimeError.unavailable(CoreMessages.prefixEnvNotAbsolute())
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: prefix, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw RuntimeError.unavailable(CoreMessages.dedicatedPrefixMissing())
        }
        guard Self.hasRequiredWPFSoftwareProfile(at: URL(fileURLWithPath: prefix)) else {
            throw RuntimeError.unavailable(CoreMessages.prefixMissingWPFProfile())
        }
        return (wineURL, archURL, environment)
    }

    public func terminate() async throws {
        process?.terminate()
        process = nil
    }

    public func collectDiagnostics() async throws -> RuntimeDiagnostics {
        RuntimeDiagnostics(backend: identifier, probe: try await probe(), collectedAt: Date())
    }
}
