import Foundation

public struct RuntimeSetupPaths: Sendable, Equatable {
    public let runtimeRoot: URL
    public let prefix: URL

    public init(runtimeRoot: URL, prefix: URL) {
        self.runtimeRoot = runtimeRoot
        self.prefix = prefix
    }

    public static func defaults(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Self {
        let support = home.appendingPathComponent("Library/Application Support/YMM4M", isDirectory: true)
        return Self(
            runtimeRoot: support.appendingPathComponent("Runtimes/ymm4m-wine-11.0-dxmt", isDirectory: true),
            prefix: support.appendingPathComponent("Prefixes/YMM4", isDirectory: true)
        )
    }
}

public enum RuntimeBootstrapper {
    public static func install(
        paths: RuntimeSetupPaths = .defaults(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let runtimeReady = fileManager.fileExists(
                atPath: paths.runtimeRoot.appendingPathComponent("ymm4m-runtime.json").path
            )
            let prefixReady = RosettaWineBackend.hasRequiredWPFSoftwareProfile(at: paths.prefix)
                && fileManager.fileExists(
                    atPath: paths.prefix.appendingPathComponent(
                        "drive_c/windows/Fonts/NotoSansCJKjp-Regular.otf"
                    ).path
                )
            if runtimeReady && prefixReady {
                try RosettaWineBackend.validateCleanRuntime(at: paths.runtimeRoot)
                return "既存の検証済みランタイムと専用prefixを使用します。"
            }

            let resources = try resources(environment: environment)
            if runtimeReady {
                try RosettaWineBackend.validateCleanRuntime(at: paths.runtimeRoot)
                return try run(
                    executable: resources.setupPrefix,
                    arguments: [],
                    environment: bootstrapEnvironment(inherited: environment).merging([
                        "YMM4M_WINE": paths.runtimeRoot.appendingPathComponent("bin/wine").path,
                        "YMM4M_PREFIX": paths.prefix.path,
                        "YMM4M_BOOTSTRAP_LOCK": resources.lock.path,
                    ]) { _, new in new }
                )
            }

            return try run(
                executable: resources.bootstrap,
                arguments: [
                    "--accept-third-party",
                    "--runtime", paths.runtimeRoot.path,
                    "--prefix", paths.prefix.path,
                ],
                environment: bootstrapEnvironment(inherited: environment).merging([
                    "YMM4M_BOOTSTRAP_LOCK": resources.lock.path,
                    "YMM4M_PROJECT_RESOURCES": resources.projectResources.path,
                ]) { _, new in new }
            )
        }.value
    }

    public static func bootstrapEnvironment(
        inherited: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        let allowedKeys = [
            "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE",
            "DEVELOPER_DIR", "YMM4M_SUPPORT_ROOT", "YMM4M_DOWNLOAD_CACHE",
            "YMM4M_SOURCE_ROOT", "YMM4M_BUILD_ROOT", "YMM4M_LLVM15_ROOT",
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
            throw RuntimeError.unavailable("自動セットアップ用ファイルがアプリ内にありません。")
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
        environment: [String: String]
    ) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw RuntimeError.unavailable("セットアップ用ファイルを実行できません: \(executable.lastPathComponent)")
        }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            throw RuntimeError.unavailable(output.isEmpty ? "自動セットアップに失敗しました。" : output)
        }
        return output
    }
}
