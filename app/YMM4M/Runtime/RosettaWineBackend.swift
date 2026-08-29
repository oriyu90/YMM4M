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
        environment["WINEDEBUG"] = environment["WINEDEBUG"] ?? "+timestamp,+pid,+tid,+seh,+loaddll"
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

    private nonisolated static let verifiedRuntimeHashes: [String: String] = [
        "bin/wine": "bad3b6126b6612680e26302c0e0b7e56d6c7036eac9bf6313878bdd9039b003f",
        "lib/wine/x86_64-unix/winemetal.so": "62777419bdbec505e72d257279976e8bcd71bbf8a895239d729dcec9d56a3ebc",
        "lib/wine/x86_64-windows/d3d10core.dll": "da8e44c09306aae35bb39958b1e1857089580939c4f38ea2022d3b1e0afcfb33",
        "lib/wine/x86_64-windows/d3d11.dll": "477fbdb9adae141521351b012fa8f7d818a5a1ea292a6d59bada4aa1905aa62a",
        "lib/wine/x86_64-windows/dxgi.dll": "3c0b3efbcab0079e892eee61680ec5863adcc17541fd54942daf94b41784c973",
        "lib/wine/x86_64-windows/winemetal.dll": "6e44b61fc81f1938cdcab4918dbf0ef7feb376eb228a3699226e948a664707a3",
        "lib/wine/x86_64-windows/d2d1.dll": "bfd7d57f6cb286639adaa575ace42cc3a9e75574d2f93398d159cd356218e77d",
        "lib/wine/x86_64-windows/dwrite.dll": "83411068ee8b7e3c009a4fd54900a2f1d696e525fee622a2105c5ea6d52e665c",
    ]

    private nonisolated static let winemacPath = "lib/wine/x86_64-unix/winemac.so"
    private nonisolated static let verifiedWinemacLoadableHash =
        "feec5cee6ad6f16368166a599ded5b4d9de7cb3a9653a7e3565c7f7c185b6508"

    private struct RuntimeManifest: Decodable {
        let schema: Int
        let kind: String
        let wineVersion: String
        let architecture: String
        let files: [String: String]
    }

    public nonisolated static func validateCleanRuntime(at root: URL) throws {
        let manifestURL = root.appendingPathComponent("ymm4m-runtime.json")
        let manifest = try JSONDecoder().decode(RuntimeManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.schema == 1,
              manifest.kind == "ymm4m-clean-wine-dxmt",
              manifest.wineVersion == "11.0",
              manifest.architecture == "x86_64",
              Set(manifest.files.keys) == Set(verifiedRuntimeHashes.keys).union([winemacPath]),
              verifiedRuntimeHashes.allSatisfy({ manifest.files[$0.key] == $0.value }),
              manifest.files[winemacPath]?.range(
                of: "^[0-9a-f]{64}$", options: .regularExpression
              ) != nil else {
            throw RuntimeError.unavailable("ランタイムマニフェストが検証済み構成と一致しません。")
        }
        for relativePath in manifest.files.keys.sorted() {
            let expectedHash = manifest.files[relativePath]!
            let fileURL = root.appendingPathComponent(relativePath)
            guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
                throw RuntimeError.unavailable("ランタイムファイルがありません: \(relativePath)")
            }
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            let actualHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard actualHash == expectedHash.lowercased() else {
                throw RuntimeError.unavailable("ランタイムファイルのハッシュが一致しません: \(relativePath)")
            }
        }
        let winemacURL = root.appendingPathComponent(winemacPath)
        guard try machOLoadableSHA256(at: winemacURL) == verifiedWinemacLoadableHash else {
            throw RuntimeError.unavailable("winemac.soのloadable image hashが検証済み構成と一致しません。")
        }
    }

    public nonisolated static func machOLoadableSHA256(at url: URL) throws -> String {
        var data = try Data(contentsOf: url)
        func uint32(_ offset: Int) throws -> UInt32 {
            guard offset >= 0, offset + 4 <= data.count else {
                throw RuntimeError.unavailable("winemac.soのMach-O構造が不正です。")
            }
            return data.withUnsafeBytes {
                UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
            }
        }
        func uint64(_ offset: Int) throws -> UInt64 {
            guard offset >= 0, offset + 8 <= data.count else {
                throw RuntimeError.unavailable("winemac.soのMach-O構造が不正です。")
            }
            return data.withUnsafeBytes {
                UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
            }
        }

        guard try uint32(0) == 0xfeedfacf, try uint32(4) == 0x01000007 else {
            throw RuntimeError.unavailable("winemac.soはx86_64 Mach-Oではありません。")
        }
        let commandCount = Int(try uint32(16))
        var commandOffset = 32
        var linkEditOffset: Int?
        for _ in 0..<commandCount {
            let command = try uint32(commandOffset)
            let commandSize = Int(try uint32(commandOffset + 4))
            guard commandSize >= 8, commandOffset + commandSize <= data.count else {
                throw RuntimeError.unavailable("winemac.soのload commandが不正です。")
            }
            if command == 0x1b {
                guard commandSize >= 24 else {
                    throw RuntimeError.unavailable("winemac.soのLC_UUIDが不正です。")
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
            throw RuntimeError.unavailable("winemac.soに有効な__LINKEDITがありません。")
        }
        return SHA256.hash(data: data.prefix(linkEditOffset))
            .map { String(format: "%02x", $0) }.joined()
    }

    public func probe() async throws -> RuntimeProbeResult {
        guard let wineURL else {
            return RuntimeProbeResult(available: false, architecture: "x86_64", runtimePath: nil,
                                      reason: "Wine runtime is not configured. Set YMM4M_WINE to a validated x86_64 Wine executable.")
        }
        guard FileManager.default.fileExists(atPath: "/usr/libexec/rosetta/oahd") else {
            return RuntimeProbeResult(available: false, architecture: "x86_64", runtimePath: wineURL.path,
                                      reason: "Rosetta is unavailable on this Mac.")
        }
        guard let runtimeRootURL else {
            return RuntimeProbeResult(available: false, architecture: "x86_64", runtimePath: wineURL.path,
                                      reason: "YMM4Mのクリーンランタイム構成を特定できません。")
        }
        do {
            try Self.validateCleanRuntime(at: runtimeRootURL)
        } catch {
            return RuntimeProbeResult(available: false, architecture: "x86_64", runtimePath: wineURL.path,
                                      reason: error.localizedDescription)
        }
        return RuntimeProbeResult(available: true, architecture: "x86_64", runtimePath: wineURL.path,
                                  reason: "ハッシュ検証済みWine 11.0/DXMTランタイムとRosettaを確認しました。")
    }

    public func prepare() async throws {
        let result = try await probe()
        guard result.available else { throw RuntimeError.unavailable(result.reason) }
    }

    public func launch(executable: URL, arguments: [String]) async throws -> RuntimeProcessHandle {
        let (wineURL, environment) = try await validatedLaunchConfiguration(for: executable)

        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
        child.arguments = ["-x86_64", wineURL.path, executable.path] + arguments
        child.environment = environment
        try child.run()
        process = child
        return RuntimeProcessHandle(processIdentifier: child.processIdentifier)
    }

    public func runAuxiliary(executable: URL, arguments: [String]) async throws {
        let (wineURL, environment) = try await validatedLaunchConfiguration(for: executable)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
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

    private func validatedLaunchConfiguration(for executable: URL) async throws -> (URL, [String: String]) {
        try await prepare()
        guard executable.isFileURL, FileManager.default.isReadableFile(atPath: executable.path) else {
            throw RuntimeError.invalidExecutable(executable)
        }
        guard let wineURL else { throw RuntimeError.unavailable("Wine runtime is not configured.") }

        let environment = Self.launchEnvironment(runtimeRoot: runtimeRootURL, prefixURL: prefixURL)
        guard let prefix = environment["WINEPREFIX"],
              Self.isSafePrefixPath(prefix, home: environment["HOME"]) else {
            throw RuntimeError.unavailable("YMM4M_PREFIXに専用の絶対パスを指定してください。")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: prefix, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw RuntimeError.unavailable("専用Wineプレフィックスがありません。先に安全な初期化を実行してください。")
        }
        guard Self.hasRequiredWPFSoftwareProfile(at: URL(fileURLWithPath: prefix)) else {
            throw RuntimeError.unavailable("専用WineプレフィックスにWPF software profileが適用されていません。")
        }
        return (wineURL, environment)
    }

    public func terminate() async throws {
        process?.terminate()
        process = nil
    }

    public func collectDiagnostics() async throws -> RuntimeDiagnostics {
        RuntimeDiagnostics(backend: identifier, probe: try await probe(), collectedAt: Date())
    }
}
