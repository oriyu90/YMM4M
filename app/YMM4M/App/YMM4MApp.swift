import AppKit
import SwiftUI
import UniformTypeIdentifiers
import YMM4MCore

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }
}

@main
struct YMM4MApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("YMM4M") { ContentView() }
            .defaultSize(width: 860, height: 760)
            .windowResizability(.contentMinSize)
    }
}

private struct ContentView: View {
    @State private var status = "互換環境を自動セットアップし、YMM4本体を選択してください。"
    @State private var isWorking = false
    @State private var lastCheckSucceeded = false
    @State private var assistedText = ""
    @State private var isCommittingText = false
    @State private var acceptsThirdPartySetup = false

    @AppStorage(StoredSetupSettings.Key.runtimeRootPath) private var runtimeRootPath = ""
    @AppStorage(StoredSetupSettings.Key.winePrefixPath) private var winePrefixPath = ""
    @AppStorage(StoredSetupSettings.Key.ymm4ExecutablePath) private var ymm4ExecutablePath = ""
    @AppStorage(StoredSetupSettings.Key.ymm4ArchivePath) private var ymm4ArchivePath = ""
    @AppStorage(StoredSetupSettings.Key.mediaRootPath) private var mediaRootPath = ""

    private var environment: [String: String] { ProcessInfo.processInfo.environment }

    private var effectiveRuntimeRootPath: String {
        if let path = environment["YMM4M_RUNTIME"], !path.isEmpty { return path }
        if let wine = environment["YMM4M_WINE"], !wine.isEmpty {
            return URL(fileURLWithPath: wine)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
        }
        return runtimeRootPath
    }

    private var effectivePrefixPath: String {
        environment["YMM4M_PREFIX"].flatMap { $0.isEmpty ? nil : $0 } ?? winePrefixPath
    }

    private var effectiveExecutablePath: String {
        environment["YMM4M_EXE"].flatMap { $0.isEmpty ? nil : $0 } ?? ymm4ExecutablePath
    }

    private var effectiveMediaRootPath: String {
        environment["YMM4M_MEDIA_ROOT"].flatMap { $0.isEmpty ? nil : $0 } ?? mediaRootPath
    }

    private var configuredRequiredCount: Int {
        [effectiveRuntimeRootPath, effectivePrefixPath, effectiveExecutablePath]
            .filter { !$0.isEmpty }.count
    }

    private var hasRequiredSettings: Bool { configuredRequiredCount == 3 }
    private var hasProjectSettings: Bool {
        hasRequiredSettings && !effectiveMediaRootPath.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                developmentWarning
                automaticSetupPanel
                setupProgress
                DisclosureGroup("詳細設定・保存場所を変更") {
                    setupSteps.padding(.top, 10)
                }
                actionPanel
                usageHelp
                japaneseInputPanel
                statusPanel
            }
            .padding(28)
            .frame(maxWidth: 900)
        }
        .frame(minWidth: 760, minHeight: 700)
        .onAppear(perform: migrateStoredSettings)
        .onOpenURL { openFromFinder($0) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 38))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("YMM4M セットアップ")
                    .font(.largeTitle.bold())
                Text("YukkuriMovieMaker4をMacで開くための開発中の互換環境")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("v0.1.0 DEVELOPMENT")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.orange.opacity(0.16), in: Capsule())
                .foregroundStyle(.orange)
        }
    }

    private var developmentWarning: some View {
        Label {
            Text("YMM4本体は同梱・自動取得しません。Wine/DXMTは同意後に固定URLから取得してhash検証し、このMac上でビルドします。Developer ID署名・公証はありません。")
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.callout)
        .foregroundStyle(.orange)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    private var automaticSetupPanel: some View {
        GroupBox("最初に1回だけ：互換環境を自動セットアップ") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wine/DXMTのソースと日本語fallback fontを取得・SHA-256検証し、Wine/DXMTをビルド・配置して、YMM4専用prefixへWPF／日本語表示設定を適用します。完了まで時間と約3 GB以上の空き容量が必要です。")
                    .font(.callout)
                Toggle("第三者ライセンスのソフトウェアをネットから取得し、このMacでビルドすることに同意します", isOn: $acceptsThirdPartySetup)
                HStack {
                    Button("互換環境を自動セットアップ") { runAutomaticSetup() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!acceptsThirdPartySetup || isWorking)
                    if isWorking { ProgressView().controlSize(.small) }
                }
                Text("取得しないもの：YMM4本体、Microsoftランタイム／フォント、CrossOver、ユーザーのプロジェクト。Noto Sans CJK JPはWine prefix内だけに置きます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private var setupProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("基本設定 \(configuredRequiredCount) / 3")
                    .font(.headline)
                Spacer()
                Text(hasRequiredSettings ? "起動準備を確認できます" : "未設定があります")
                    .font(.callout)
                    .foregroundStyle(hasRequiredSettings ? .green : .secondary)
            }
            ProgressView(value: Double(configuredRequiredCount), total: 3)
        }
    }

    private var setupSteps: some View {
        VStack(spacing: 12) {
            SetupStepView(
                number: 1,
                title: "互換ランタイム",
                detail: "ymm4m-runtime.json と bin/wine が入った、検証済みWine/DXMTフォルダです。DMGには含まれません。",
                path: effectiveRuntimeRootPath,
                completed: !effectiveRuntimeRootPath.isEmpty,
                actionTitle: "フォルダを選択",
                sourceIsEnvironment: environment["YMM4M_RUNTIME"] != nil || environment["YMM4M_WINE"] != nil,
                action: chooseRuntimeRoot
            )
            SetupStepView(
                number: 2,
                title: "専用Wine prefix",
                detail: "YMM4専用のWindows環境フォルダです。WPF software profile適用済みのprefixだけを使用します。",
                path: effectivePrefixPath,
                completed: !effectivePrefixPath.isEmpty,
                actionTitle: "フォルダを選択",
                sourceIsEnvironment: environment["YMM4M_PREFIX"] != nil,
                action: choosePrefix
            )
            SetupStepView(
                number: 3,
                title: "公式YMM4 ZIP（通常版／Lite）",
                detail: "先にZIPをダウンロードフォルダなど自動削除されない場所へ保存してください。YMM4Mは選んだZIPを移動・削除せず、hash・構造検証後にversion別専用領域へ展開します。",
                path: ymm4ArchivePath.isEmpty ? effectiveExecutablePath : ymm4ArchivePath,
                completed: !effectiveExecutablePath.isEmpty,
                actionTitle: "ZIPを選んで準備",
                sourceIsEnvironment: environment["YMM4M_EXE"] != nil,
                action: chooseAndInstallYMM4Archive
            )
            if environment["YMM4M_EXE"] == nil {
                HStack {
                    Spacer()
                    Button("展開済みEXEを選ぶ（開発者向け）", action: chooseYMM4Executable)
                        .buttonStyle(.link)
                }
            }
            SetupStepView(
                number: 4,
                title: "プロジェクト用フォルダ（プロジェクトを開く場合）",
                detail: ".ymmp と素材を置く専用フォルダです。Wine側では安全な M: ドライブとして見えます。",
                path: effectiveMediaRootPath,
                completed: !effectiveMediaRootPath.isEmpty,
                actionTitle: "フォルダを選択",
                sourceIsEnvironment: environment["YMM4M_MEDIA_ROOT"] != nil,
                action: chooseMediaRoot
            )
        }
    }

    private var actionPanel: some View {
        GroupBox("起動") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button("1. 設定を確認") { checkSetup() }
                        .disabled(!hasRequiredSettings || isWorking)
                    Button("2. YMM4をMacで開く") { launchYMM4() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasRequiredSettings || isWorking)
                    Button("プロジェクトを選んで開く") { chooseProject() }
                        .disabled(!hasProjectSettings || isWorking)
                    if isWorking { ProgressView().controlSize(.small) }
                }
                HStack {
                    Label(
                        lastCheckSucceeded ? "直近の設定確認は成功しました" : "起動前に設定確認を実行してください",
                        systemImage: lastCheckSucceeded ? "checkmark.seal.fill" : "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(lastCheckSucceeded ? .green : .secondary)
                    Spacer()
                    Button("前のYMM4へ戻す") { rollbackYMM4() }
                        .buttonStyle(.link)
                        .disabled(isWorking)
                    Button("保存した設定をクリア", role: .destructive) { clearStoredSettings() }
                        .buttonStyle(.link)
                }
            }
            .padding(8)
        }
    }

    private var usageHelp: some View {
        DisclosureGroup("MacでYMM4を開く手順") {
            VStack(alignment: .leading, spacing: 8) {
                Text("1. 同意項目を確認し、互換環境を自動セットアップします。")
                Text("2. 公式の通常版またはLiteのZIPを自動削除されない場所へ保存し、ZIPを選んで検証・展開を完了します。")
                Text("3. 「設定を確認」でruntimeのhash、Rosetta、prefixのWPF設定、YMM4の対応versionを確認します。")
                Text("4. 「YMM4をMacで開く」を押すと、Wine上のYMM4がmacOSのウィンドウとして開きます。")
                Text("初回起動時にmacOSが拒否する場合があります。この開発版はDeveloper ID署名・公証がないためで、通常配布版としての起動は保証していません。Gatekeeperを全体無効化しないでください。")
                    .foregroundStyle(.orange)
            }
            .font(.callout)
            .padding(.top, 10)
        }
    }

    private var japaneseInputPanel: some View {
        GroupBox("日本語入力補助（YMM4 Lite 4.55.1.1限定）") {
            VStack(alignment: .leading, spacing: 10) {
                Text("YMM4内で直接日本語変換できない場合に、ここで変換・確定してから台詞欄へ転送します。YMM4を先に起動してください。「追加」は自動操作しません。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("ここで日本語を変換・確定", text: $assistedText, axis: .vertical)
                    .lineLimit(2...4)
                HStack {
                    Button("確定した文字をYMM4の台詞欄へ送る") { commitAssistedText() }
                        .disabled(assistedText.isEmpty || isCommittingText)
                    if isCommittingText { ProgressView().controlSize(.small) }
                }
            }
            .padding(8)
        }
    }

    private var statusPanel: some View {
        GroupBox("現在の状態") {
            Label(status, systemImage: lastCheckSucceeded ? "checkmark.circle" : "text.bubble")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .textSelection(.enabled)
        }
    }

    private func chooseRuntimeRoot() {
        chooseDirectory(message: "ymm4m-runtime.json と bin/wine が入った検証済みランタイムを選択してください") {
            runtimeRootPath = $0.path
            settingsChanged("互換ランタイムを設定しました。")
        }
    }

    private func runAutomaticSetup() {
        isWorking = true
        lastCheckSucceeded = false
        status = "Wine/DXMTを取得・検証・ビルドしています。アプリを終了しないでください…"
        let paths = RuntimeSetupPaths.defaults()
        Task {
            defer { isWorking = false }
            do {
                let output = try await RuntimeBootstrapper.install(paths: paths)
                runtimeRootPath = paths.runtimeRoot.path
                winePrefixPath = paths.prefix.path
                acceptsThirdPartySetup = false
                status = "互換環境の準備が完了しました。次に公式YMM4 ZIPを選んでください。\n\(output)"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func choosePrefix() {
        chooseDirectory(message: "YMM4専用Wine prefixを選択してください") {
            winePrefixPath = $0.path
            settingsChanged("専用Wine prefixを設定しました。")
        }
    }

    private func chooseYMM4Executable() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "公式配布物内のYukkuriMovieMaker.exeを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            guard url.lastPathComponent.caseInsensitiveCompare("YukkuriMovieMaker.exe") == .orderedSame else {
                status = "YukkuriMovieMaker.exeを選択してください。別のファイルは保存しませんでした。"
                return
            }
            ymm4ExecutablePath = url.standardizedFileURL.path
            ymm4ArchivePath = ""
            settingsChanged("YMM4本体を設定しました。")
        }
    }

    private func chooseAndInstallYMM4Archive() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.message = "自動削除されない場所に保存した公式YMM4 ZIP（通常版／Lite）を選択してください。元のZIPは移動・削除しません。"
        guard panel.runModal() == .OK, let archive = panel.url else { return }

        isWorking = true
        lastCheckSucceeded = false
        status = "YMM4 ZIPのhashと構造を検証し、専用領域へ準備しています…"
        Task {
            defer { isWorking = false }
            do {
                let catalog = try loadYMM4Catalog()
                let selectedArchive = archive.standardizedFileURL
                let archiveHash = try await Task.detached(priority: .userInitiated) {
                    try YMM4ArchiveInstaller.archiveSHA256(at: selectedArchive)
                }.value
                let installed: YMM4InstalledRelease
                if catalog.release(archiveSHA256: archiveHash) != nil {
                    installed = try await YMM4ArchiveInstaller.install(
                        archive: selectedArchive, catalog: catalog
                    )
                } else {
                    status = "未登録ZIPの公式Release情報と保守更新境界を確認しています…"
                    let receipt = try await YMM4OfficialReleaseVerifier.verify(archive: selectedArchive)
                    guard let family = catalog.maintenanceFamily(
                        version: receipt.version, edition: receipt.edition
                    ) else {
                        throw RuntimeError.unavailable(
                            "公式YMM4であることは確認できましたが、検証済み保守系列の外です。大型更新として扱い、YMM4Mの互換性確認が完了するまで導入しません。"
                        )
                    }
                    guard confirmMaintenanceCandidate(receipt: receipt, family: family) else {
                        status = "保守更新候補の導入を中止しました。現在のYMM4は変更していません。"
                        return
                    }
                    installed = try await YMM4ArchiveInstaller.installMaintenanceCandidate(
                        archive: selectedArchive, receipt: receipt, family: family
                    )
                }
                ymm4ArchivePath = archive.standardizedFileURL.path
                ymm4ExecutablePath = installed.executable.path
                if installed.release.classification == .maintenanceCandidate {
                    status = "公式の保守更新候補YMM4 \(installed.release.displayVersion)へ切り替えました。以前の版は保持されています。「設定を確認」後、問題があれば「前のYMM4へ戻す」を使用してください。"
                } else {
                    status = installed.reusedExistingInstall
                        ? "検証済みYMM4 \(installed.release.displayVersion) を再利用します。「設定を確認」へ進んでください。"
                        : "YMM4 \(installed.release.displayVersion) の準備が完了しました。「設定を確認」へ進んでください。"
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func loadYMM4Catalog() throws -> YMM4ReleaseCatalog {
        if let override = environment["YMM4M_YMM4_CATALOG"], !override.isEmpty {
            return try YMM4ReleaseCatalog.load(from: URL(fileURLWithPath: override))
        }
        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("YMM4/ymm4-releases.json"),
           FileManager.default.isReadableFile(atPath: bundled.path) {
            return try YMM4ReleaseCatalog.load(from: bundled)
        }
        let development = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("compatibility/ymm4-releases.json")
        guard FileManager.default.isReadableFile(atPath: development.path) else {
            throw RuntimeError.unavailable("YMM4互換カタログがアプリ内にありません。")
        }
        return try YMM4ReleaseCatalog.load(from: development)
    }

    private func chooseMediaRoot() {
        chooseDirectory(message: ".ymmpと素材を置く専用フォルダを選択してください") {
            mediaRootPath = $0.resolvingSymlinksInPath().path
            settingsChanged("プロジェクト用フォルダを設定しました。")
        }
    }

    private func chooseDirectory(message: String, completion: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.message = message
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.standardizedFileURL)
        }
    }

    private func settingsChanged(_ message: String) {
        lastCheckSucceeded = false
        status = message + " 続けて未設定の項目を選んでください。"
    }

    private func migrateStoredSettings() {
        guard environment["YMM4M_RUNTIME"] == nil,
              environment["YMM4M_WINE"] == nil,
              environment["YMM4M_PREFIX"] == nil,
              environment["YMM4M_EXE"] == nil else { return }
        guard let homePath = environment["HOME"], !homePath.isEmpty else { return }
        let stored = StoredSetupSettings(
            runtimeRootPath: runtimeRootPath,
            winePrefixPath: winePrefixPath,
            ymm4ExecutablePath: ymm4ExecutablePath,
            ymm4ArchivePath: ymm4ArchivePath,
            mediaRootPath: mediaRootPath
        )
        let result = stored.migratingManagedPaths(home: URL(fileURLWithPath: homePath))
        if result.changed {
            runtimeRootPath = result.settings.runtimeRootPath
            winePrefixPath = result.settings.winePrefixPath
            ymm4ExecutablePath = result.settings.ymm4ExecutablePath
            lastCheckSucceeded = false
            status = "保存済みの標準設定を現在のcurrentチャネルへ引き継ぎました。起動前に「設定を確認」を実行してください。"
        } else if result.needsRuntimeSetup || result.needsYMM4Setup {
            lastCheckSucceeded = false
            status = "以前の標準保存先が設定されています。カスタムパスは変更せず、必要なセットアップをやり直すまで起動しません。"
        }
    }

    private func clearStoredSettings() {
        runtimeRootPath = ""
        winePrefixPath = ""
        ymm4ExecutablePath = ""
        ymm4ArchivePath = ""
        mediaRootPath = ""
        lastCheckSucceeded = false
        status = environment.keys.contains(where: { $0.hasPrefix("YMM4M_") })
            ? "保存した設定を消去しました。環境変数で指定された項目は引き続き表示されます。"
            : "保存した設定を消去しました。"
    }

    private func makeBackend() throws -> RosettaWineBackend {
        guard !effectiveRuntimeRootPath.isEmpty else {
            throw RuntimeError.unavailable("手順1の互換ランタイムを選択してください。")
        }
        guard !effectivePrefixPath.isEmpty else {
            throw RuntimeError.unavailable("手順2の専用Wine prefixを選択してください。")
        }
        let runtimeRoot = URL(fileURLWithPath: effectiveRuntimeRootPath, isDirectory: true)
        let defaults = RuntimeSetupPaths.defaults()
        if runtimeRoot.standardizedFileURL == defaults.runtimeRoot.standardizedFileURL,
           URL(fileURLWithPath: effectivePrefixPath, isDirectory: true).standardizedFileURL
            == defaults.prefix.standardizedFileURL {
            try RuntimeBootstrapper.validateActivePair(defaults)
        }
        let wineURL: URL
        if let configuredWine = environment["YMM4M_WINE"], !configuredWine.isEmpty {
            wineURL = URL(fileURLWithPath: configuredWine)
        } else {
            wineURL = runtimeRoot.appendingPathComponent("bin/wine")
        }
        return RosettaWineBackend(
            wineURL: wineURL,
            runtimeRootURL: runtimeRoot,
            prefixURL: URL(fileURLWithPath: effectivePrefixPath, isDirectory: true)
        )
    }

    private func checkSetup() {
        isWorking = true
        lastCheckSucceeded = false
        status = "設定を確認しています…"
        Task {
            defer { isWorking = false }
            do {
                let backend = try makeBackend()
                let probe = try await backend.probe()
                guard probe.available else { throw RuntimeError.unavailable(probe.reason) }

                let prefix = URL(fileURLWithPath: effectivePrefixPath, isDirectory: true)
                guard RosettaWineBackend.isSafePrefixPath(prefix.path, home: environment["HOME"]) else {
                    throw RuntimeError.unavailable("専用Wine prefixに安全な絶対パスを選択してください。")
                }
                guard RosettaWineBackend.hasRequiredWPFSoftwareProfile(at: prefix) else {
                    throw RuntimeError.unavailable("選択したprefixにWPF software profileがありません。準備済みの専用prefixを選択してください。")
                }

                let executable = try configuredExecutable()
                let catalog = try loadYMM4Catalog()
                let compatibility = try await Task.detached(priority: .userInitiated) {
                    try YMM4CompatibilityPolicy.classify(executable: executable, catalog: catalog)
                }.value
                if compatibility.classification == .knownBroken {
                    throw RuntimeError.unavailable("選択したYMM4は既知の非互換版です。")
                }
                try validateRuntimeRequirement(compatibility)

                if !effectiveMediaRootPath.isEmpty {
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(
                        atPath: effectiveMediaRootPath,
                        isDirectory: &isDirectory
                    ), isDirectory.boolValue else {
                        throw RuntimeError.unavailable("選択したプロジェクト用フォルダが見つかりません。")
                    }
                }

                lastCheckSucceeded = true
                if compatibility.classification == .knownCompatible {
                    status = "設定OK：検証済みYMM4 \(compatibility.displayVersion ?? "") とランタイムを確認しました。「YMM4を起動」を押せます。"
                } else if compatibility.classification == .maintenanceCandidate {
                    status = "設定OK：公式保守更新候補YMM4 \(compatibility.displayVersion ?? "")のランタイム境界を確認しました。未検証のアプリ動作があれば「前のYMM4へ戻す」を使用してください。"
                } else {
                    status = "ランタイムとprefixは確認できましたが、YMM4のhashは未検証です。起動時の警告を確認してください。"
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func configuredExecutable() throws -> URL {
        guard !effectiveExecutablePath.isEmpty else {
            throw RuntimeError.unavailable("手順3のYMM4本体を選択してください。")
        }
        let executable = URL(fileURLWithPath: effectiveExecutablePath)
        guard FileManager.default.isReadableFile(atPath: executable.path) else {
            throw RuntimeError.invalidExecutable(executable)
        }
        return executable
    }

    private func launchYMM4(projectURL: URL? = nil) {
        isWorking = true
        status = projectURL == nil ? "YMM4を起動しています…" : "\(projectURL!.lastPathComponent)を開いています…"
        Task {
            defer { isWorking = false }
            do {
                let backend = try makeBackend()
                let executable = try configuredExecutable()
                let catalog = try loadYMM4Catalog()
                let compatibility = try await Task.detached(priority: .userInitiated) {
                    try YMM4CompatibilityPolicy.classify(executable: executable, catalog: catalog)
                }.value
                try validateRuntimeRequirement(compatibility)
                guard approveLaunch(for: compatibility, executable: executable) else { return }

                var arguments: [String] = []
                if let projectURL {
                    guard !effectiveMediaRootPath.isEmpty else {
                        throw RuntimeError.unavailable("手順4のプロジェクト用フォルダを選択してください。")
                    }
                    let mediaRoot = URL(fileURLWithPath: effectiveMediaRootPath, isDirectory: true)
                    let prefix = URL(fileURLWithPath: effectivePrefixPath, isDirectory: true)
                    try WineMediaDrive.configure(prefix: prefix, mediaRoot: mediaRoot)
                    arguments = [try PathMapper(mediaRoot: mediaRoot).winePath(for: projectURL)]
                }

                _ = try await backend.launch(executable: executable, arguments: arguments)
                status = projectURL == nil
                    ? "YMM4を起動しました。YMM4のウィンドウが表示されるまでお待ちください。"
                    : "\(projectURL!.lastPathComponent)をYMM4へ渡しました。元ファイルは変更していません。"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func chooseProject() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType(filenameExtension: "ymmp") ?? .data]
        panel.message = "手順4で選んだフォルダ内の.ymmpを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            launchYMM4(projectURL: url)
        }
    }

    private func openFromFinder(_ url: URL) {
        guard url.pathExtension.lowercased() == "ymmp" else {
            status = ".\(url.pathExtension.lowercased())の自動取り込みは未検証です。ファイルは変更しませんでした。"
            return
        }
        guard hasProjectSettings else {
            status = "Finderからプロジェクトを開く前に、手順1〜4を設定してください。"
            return
        }
        launchYMM4(projectURL: url)
    }

    @MainActor
    private func approveLaunch(for result: YMM4CompatibilityResult, executable: URL) -> Bool {
        switch result.classification {
        case .knownCompatible:
            return true
        case .maintenanceCandidate:
            return true
        case .knownBroken:
            status = "このYMM4実行ファイルは既知の非互換版のため起動しません。"
            return false
        case .unknown:
            let managedStore = YMM4InstallationPaths.defaults().store.standardizedFileURL.path + "/"
            if executable.standardizedFileURL.path.hasPrefix(managedStore) {
                status = "専用領域内のYMM4が検証済みhashから変化しているため起動しません。対応カタログを更新したYMM4Mで公式ZIPを再導入してください。"
                return false
            }
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "未検証のYMM4です"
            alert.informativeText = "この実行ファイルのhashは検証済みYMM4 4.55.1.1（通常版／Lite）と一致しません。続行すると予期しない問題が起きる可能性があります。"
            alert.addButton(withTitle: "理解して続行")
            alert.addButton(withTitle: "選び直す")
            if alert.runModal() == .alertFirstButtonReturn { return true }
            status = "YMM4実行ファイルを選び直してください。"
            return false
        }
    }

    @MainActor
    private func confirmMaintenanceCandidate(
        receipt: YMM4OfficialAssetReceipt,
        family: YMM4MaintenanceFamily
    ) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "公式の保守更新候補 \(receipt.version) を試しますか？"
        alert.informativeText = "公式SHA-256と検証済み \(family.versionPrefix).x 系のランタイム境界を確認しますが、この版固有の画面・IME・編集動作は未検証です。現在の版をpreviousとして保持し、YMM4Mから切り戻せます。"
        alert.addButton(withTitle: "保守更新候補として導入")
        alert.addButton(withTitle: "現在の版を使う")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func rollbackYMM4() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "直前のYMM4へ戻しますか？"
        alert.informativeText = "現在の版は削除せずpreviousとして保持します。共有設定dataも削除しません。切替後に設定確認を実行してください。"
        alert.addButton(withTitle: "前の版へ戻す")
        alert.addButton(withTitle: "キャンセル")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        isWorking = true
        lastCheckSucceeded = false
        status = "以前のYMM4を検証して切り戻しています…"
        Task {
            defer { isWorking = false }
            do {
                let catalog = try loadYMM4Catalog()
                let executable = try await Task.detached(priority: .userInitiated) {
                    try YMM4ArchiveInstaller.rollback(catalog: catalog)
                }.value
                ymm4ExecutablePath = executable.path
                ymm4ArchivePath = ""
                status = "以前のYMM4へ切り戻しました。保存設定もcurrentチャネルへ更新しました。「設定を確認」を実行してください。"
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func validateRuntimeRequirement(_ result: YMM4CompatibilityResult) throws {
        if let required = result.requiredRuntimeProfile,
           required != RuntimeSetupPaths.currentRuntimeProfile {
            throw RuntimeError.unavailable(
                "このYMM4に必要なランタイム \(required) は現在のYMM4Mにはありません。YMM4Mを更新してください。"
            )
        }
    }

    private func commitAssistedText() {
        guard let bridge = YMM4TextInputBridge.configured() else {
            status = "日本語入力helperが未設定です。この開発版ではYMM4M_TEXT_COMMIT_HELPERの設定が必要です。"
            return
        }
        isCommittingText = true
        let committedText = assistedText
        Task {
            do {
                try await bridge.commit(committedText)
                status = "確定した文字をYMM4の台詞欄へ入力しました。"
                assistedText = ""
                isCommittingText = false
            } catch {
                status = error.localizedDescription
                isCommittingText = false
            }
        }
    }
}

private struct SetupStepView: View {
    let number: Int
    let title: String
    let detail: String
    let path: String
    let completed: Bool
    let actionTitle: String
    let sourceIsEnvironment: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(completed ? Color.green : Color.secondary.opacity(0.15))
                    .frame(width: 32, height: 32)
                if completed {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .font(.headline)
                } else {
                    Text("\(number)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    if number == 4 {
                        Text("任意")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if sourceIsEnvironment {
                        Text("環境変数")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(path.isEmpty ? "未設定" : path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(path.isEmpty ? .orange : .primary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            Button(actionTitle, action: action)
                .disabled(sourceIsEnvironment)
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}
