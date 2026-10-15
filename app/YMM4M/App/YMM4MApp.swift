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
        WindowGroup(Loc.current.windowTitle) { ContentView() }
            .defaultSize(width: 860, height: 760)
            .windowResizability(.contentMinSize)
    }
}

private struct ContentView: View {
    private let L = Loc.current
    @State private var status = Loc.current.statusInitial
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

    private var configuredSetupCount: Int {
        configuredRequiredCount + (effectiveMediaRootPath.isEmpty ? 0 : 1)
    }

    private var hasRequiredSettings: Bool {
        isValidRuntimeSelection(effectiveRuntimeRootPath)
            && isValidPrefixSelection(effectivePrefixPath)
            && isReadableFileSelection(effectiveExecutablePath)
    }
    private var hasProjectSettings: Bool {
        hasRequiredSettings && isValidMediaSelection(effectiveMediaRootPath)
    }

    /// Fail-closed launch gating: a non-empty string is not enough. An empty
    /// folder picked for the one-shot setup must not look "ready" before the
    /// runtime is actually built, otherwise the launch button fails late with
    /// a manifest/hash message. These helpers only use `fileExists` (no
    /// hashing, no registry parsing) so SwiftUI recomputes stay cheap; the
    /// full manifest/WPF/catalog checks still run in `checkSetup`/`launch`.
    private func isValidRuntimeSelection(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return false }
        // A built runtime always carries its manifest at the root (`current`
        // resolves to `versions/<profile>`). An empty folder chosen for the
        // one-shot setup has no manifest yet and must not enable launch.
        let manifest = (path as NSString).appendingPathComponent("ymm4m-runtime.json")
        let wine = (path as NSString).appendingPathComponent("bin/wine")
        return FileManager.default.fileExists(atPath: manifest)
            || FileManager.default.isExecutableFile(atPath: wine)
    }

    private func isValidPrefixSelection(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return false }
        // A prepared prefix always has `user.reg`. An empty folder chosen for
        // the one-shot setup must not enable launch.
        let registry = (path as NSString).appendingPathComponent("user.reg")
        return FileManager.default.fileExists(atPath: registry)
    }

    private func isReadableFileSelection(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        return FileManager.default.isReadableFile(atPath: path)
    }

    private func isValidMediaSelection(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                developmentWarning
                automaticSetupPanel
                setupProgress
                DisclosureGroup(L.detailDisclosure) {
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
                Text(L.headerTitle)
                    .font(.largeTitle.bold())
                Text(L.headerSubtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(L.versionBadge)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.orange.opacity(0.16), in: Capsule())
                .foregroundStyle(.orange)
        }
    }

    private var developmentWarning: some View {
        Label {
            Text(L.developmentWarning)
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
        GroupBox(L.bulkInstallTitle) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L.bulkInstallBody)
                    .font(.callout)
                Text(L.bulkInstallFreeSpace)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle(L.bulkInstallConsent, isOn: $acceptsThirdPartySetup)
                HStack {
                    Button(L.bulkInstallButton) { chooseAndRunCompleteSetup() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!acceptsThirdPartySetup || isWorking)
                    if isWorking { ProgressView().controlSize(.small) }
                }
                Text(L.bulkInstallExcludes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private var setupProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.setupCounter(configuredSetupCount))
                    .font(.headline)
                Spacer()
                Text(hasProjectSettings ? L.setupReady : L.setupNotReady)
                    .font(.callout)
                    .foregroundStyle(hasProjectSettings ? .green : .secondary)
            }
            ProgressView(value: Double(configuredSetupCount), total: 4)
        }
    }

    private var setupSteps: some View {
        VStack(spacing: 12) {
            SetupStepView(
                number: 1,
                title: L.step1Title,
                detail: L.step1Detail,
                path: effectiveRuntimeRootPath,
                completed: !effectiveRuntimeRootPath.isEmpty,
                actionTitle: L.chooseFolder,
                sourceIsEnvironment: environment["YMM4M_RUNTIME"] != nil || environment["YMM4M_WINE"] != nil,
                action: chooseRuntimeRoot
            )
            SetupStepView(
                number: 2,
                title: L.step2Title,
                detail: L.step2Detail,
                path: effectivePrefixPath,
                completed: !effectivePrefixPath.isEmpty,
                actionTitle: L.chooseFolder,
                sourceIsEnvironment: environment["YMM4M_PREFIX"] != nil,
                action: choosePrefix
            )
            SetupStepView(
                number: 3,
                title: L.step3Title,
                detail: L.step3Detail,
                path: ymm4ArchivePath.isEmpty ? effectiveExecutablePath : ymm4ArchivePath,
                completed: !effectiveExecutablePath.isEmpty,
                actionTitle: L.chooseZip,
                sourceIsEnvironment: environment["YMM4M_EXE"] != nil,
                action: chooseAndInstallYMM4Archive
            )
            if environment["YMM4M_EXE"] == nil {
                HStack {
                    Spacer()
                    Button(L.step3PickExe, action: chooseYMM4Executable)
                        .buttonStyle(.link)
                }
            }
            SetupStepView(
                number: 4,
                title: L.step4Title,
                detail: L.step4Detail,
                path: effectiveMediaRootPath,
                completed: !effectiveMediaRootPath.isEmpty,
                actionTitle: L.chooseFolder,
                sourceIsEnvironment: environment["YMM4M_MEDIA_ROOT"] != nil,
                action: chooseMediaRoot
            )
        }
    }

    private var actionPanel: some View {
        GroupBox(L.launchGroupTitle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button(L.checkSettingsButton) { checkSetup() }
                        .disabled(!hasProjectSettings || isWorking)
                    Button(L.launchButton) { launchYMM4() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasProjectSettings || isWorking)
                    Button(L.openProjectButton) { chooseProject() }
                        .disabled(!hasProjectSettings || isWorking)
                    if isWorking { ProgressView().controlSize(.small) }
                }
                HStack {
                    Label(
                        lastCheckSucceeded ? L.lastCheckOK : L.lastCheckPending,
                        systemImage: lastCheckSucceeded ? "checkmark.seal.fill" : "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(lastCheckSucceeded ? .green : .secondary)
                    Spacer()
                    Button(L.rollbackButton) { rollbackYMM4() }
                        .buttonStyle(.link)
                        .disabled(isWorking)
                    Button(L.clearSettingsButton, role: .destructive) { clearStoredSettings() }
                        .buttonStyle(.link)
                }
            }
            .padding(8)
        }
    }

    private var usageHelp: some View {
        DisclosureGroup(L.usageHelpTitle) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.usageStep1)
                Text(L.usageStep2)
                Text(L.usageStep3)
                Text(L.usageStep4)
                Text(L.usageGatekeeperNote)
                    .foregroundStyle(.orange)
            }
            .font(.callout)
            .padding(.top, 10)
        }
    }

    private var japaneseInputPanel: some View {
        GroupBox(L.imePanelTitle) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L.imePanelBody)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField(L.imeFieldPrompt, text: $assistedText, axis: .vertical)
                    .lineLimit(2...4)
                HStack {
                    Button(L.imeCommitButton) { commitAssistedText() }
                        .disabled(assistedText.isEmpty || isCommittingText)
                    if isCommittingText { ProgressView().controlSize(.small) }
                }
            }
            .padding(8)
        }
    }

    private var statusPanel: some View {
        GroupBox(L.currentStatusTitle) {
            Label(status, systemImage: lastCheckSucceeded ? "checkmark.circle" : "text.bubble")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .textSelection(.enabled)
        }
    }

    private func chooseRuntimeRoot() {
        chooseDirectory(message: L.promptRuntimeFolder) {
            runtimeRootPath = $0.path
            settingsChanged(L.statusRuntimeFolderSet)
        }
    }

    private func chooseAndRunCompleteSetup() {
        // Fail before asking the user to pick files: without a working
        // Rosetta 2 translation runtime, x86_64 Wine can never launch, so
        // file picking would only waste the user's effort. The same gate
        // runs again inside the setup itself; this pre-check only saves
        // two dialog interactions.
        guard RosettaWineBackend.workingTranslationAvailable() else {
            lastCheckSucceeded = false
            status = CoreMessages.rosettaUnavailable() + L.statusRetryHint
            return
        }
        let archivePanel = NSOpenPanel()
        archivePanel.allowsMultipleSelection = false
        archivePanel.canChooseDirectories = false
        archivePanel.canChooseFiles = true
        archivePanel.allowedContentTypes = [.zip]
        archivePanel.message = L.promptArchive
        guard archivePanel.runModal() == .OK, let archive = archivePanel.url else { return }

        let mediaPanel = NSOpenPanel()
        mediaPanel.allowsMultipleSelection = false
        mediaPanel.canChooseDirectories = true
        mediaPanel.canChooseFiles = false
        mediaPanel.canCreateDirectories = true
        mediaPanel.message = L.promptMediaFolder
        guard mediaPanel.runModal() == .OK, let mediaRoot = mediaPanel.url else { return }

        runCompleteSetup(
            archive: archive.standardizedFileURL,
            mediaRoot: mediaRoot.standardizedFileURL.resolvingSymlinksInPath()
        )
    }

    /// Folder chosen in "個別セットアップ・開発者向け詳細設定" that the automatic
    /// installer should populate. A stored `.../current` value resolves back to
    /// its store root so pressing setup again reuses the same location.
    private func developerStoreRoot(_ stored: String) -> URL? {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var url = URL(fileURLWithPath: trimmed, isDirectory: true).standardizedFileURL
        if url.lastPathComponent == "current" { url = url.deletingLastPathComponent() }
        return url
    }

    /// Uses the developer-selected runtime/prefix folders as versioned store
    /// roots when both are set; otherwise the standard Application Support
    /// location. Environment-provided runtimes always take precedence and are
    /// resolved at launch, so they keep the default here.
    private func resolvedSetupPaths() throws -> RuntimeSetupPaths {
        let defaults = RuntimeSetupPaths.defaults()
        guard environment["YMM4M_RUNTIME"] == nil, environment["YMM4M_WINE"] == nil,
              environment["YMM4M_PREFIX"] == nil else { return defaults }

        let runtimeStored = runtimeRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixStored = winePrefixPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if runtimeStored.isEmpty, prefixStored.isEmpty { return defaults }
        guard let runtimeStore = developerStoreRoot(runtimeStored),
              let prefixStore = developerStoreRoot(prefixStored) else {
            throw RuntimeError.unavailable(L.errorNeedBothFolders)
        }

        if runtimeStore == defaults.runtimeStore?.standardizedFileURL,
           prefixStore == defaults.prefixStore?.standardizedFileURL {
            return defaults
        }

        let home = environment["HOME"].map { URL(fileURLWithPath: $0).standardizedFileURL }
        for store in [runtimeStore, prefixStore] {
            guard store.path.hasPrefix("/"), store.path != "/", store != home else {
                throw RuntimeError.unavailable(L.errorRuntimePrefixUnsafe)
            }
            // `:` would silently split WINEDLLPATH (colon-joined) and
            // newlines/tabs break shell quoting. Spaces are allowed: the
            // standard `~/Library/Application Support/...` location itself
            // contains a space and works (build happens in the whitespace-free
            // compile cache). Only reject what actually breaks the build.
            if store.path.contains(":") || store.path.contains("\n") || store.path.contains("\t") {
                throw RuntimeError.unavailable(L.errorCustomPathWhitespace)
            }
        }
        guard runtimeStore != prefixStore else {
            throw RuntimeError.unavailable(L.errorRuntimePrefixSame)
        }
        guard RosettaWineBackend.isSafePrefixPath(
            prefixStore.appendingPathComponent("versions").path, home: environment["HOME"]
        ) else {
            throw RuntimeError.unavailable(L.errorPrefixAbsolutePath)
        }
        return RuntimeSetupPaths.custom(runtimeStore: runtimeStore, prefixStore: prefixStore)
    }

    private func runCompleteSetup(archive: URL, mediaRoot: URL) {
        isWorking = true
        lastCheckSucceeded = false
        status = L.statusBulkStarted
        Task { @MainActor in
            defer { isWorking = false }
            do {
                let paths = try resolvedSetupPaths()
                // Fail fast before the multi-hour runtime build: the archive
                // and media folder are already picked, so validate them now.
                // A renamed maintenance ZIP or missing file must not waste
                // hours of Wine/DXMT compilation before failing.
                try await preflightArchiveBeforeBuild(archive)
                var isMediaDirectory: ObjCBool = false
                guard FileManager.default.fileExists(
                    atPath: mediaRoot.path, isDirectory: &isMediaDirectory
                ), isMediaDirectory.boolValue else {
                    throw RuntimeError.unavailable(L.errorMediaFolderMissing)
                }
                _ = try await RuntimeBootstrapper.install(paths: paths) { update in
                    Task { @MainActor in
                        status = L.statusBulkProgress(update)
                    }
                }
                status = L.statusBulkRuntimeVerified
                let catalog = try loadYMM4Catalog()
                let installed = try await installSelectedYMM4Archive(archive, catalog: catalog)
                guard installed.release.runtimeProfile == paths.runtimeProfile else {
                    throw RuntimeError.unavailable(L.errorRuntimeProfileMismatch)
                }
                try RuntimeBootstrapper.validateActivePair(paths)
                try WineMediaDrive.configure(
                    prefix: paths.prefix,
                    mediaRoot: mediaRoot,
                    replaceExistingMapping: true
                )

                // Persist only after every managed component and M: mapping has
                // passed validation, so an interrupted run never looks complete.
                runtimeRootPath = paths.runtimeRoot.path
                winePrefixPath = paths.prefix.path
                ymm4ExecutablePath = installed.executable.path
                ymm4ArchivePath = archive.path
                mediaRootPath = mediaRoot.path
                acceptsThirdPartySetup = false
                lastCheckSucceeded = true
                status = L.statusBulkComplete(installed.release.displayVersion)
            } catch {
                status = error.localizedDescription + L.statusRetryHint
            }
        }
    }

    /// Lightweight pre-build archive gate (local only, no network). Computes
    /// the archive hash, allows exact known releases regardless of filename,
    /// and rejects a renamed file before the runtime build when it cannot be
    /// a known release (maintenance path requires the official filename).
    private func preflightArchiveBeforeBuild(_ archive: URL) async throws {
        guard archive.isFileURL,
              FileManager.default.isReadableFile(atPath: archive.path),
              archive.pathExtension.lowercased() == "zip" else {
            throw RuntimeError.unavailable(CoreMessages.archiveNotOfficialZIP())
        }
        let catalog = try loadYMM4Catalog()
        let archiveHash = try await Task.detached(priority: .userInitiated) {
            try YMM4ArchiveInstaller.archiveSHA256(at: archive.standardizedFileURL)
        }.value
        if catalog.release(archiveSHA256: archiveHash) != nil { return }
        // Unknown hash: maintenance path will enforce the official filename
        // via YMM4OfficialReleaseVerifier. Fail here instead of after hours.
        let name = archive.standardizedFileURL.lastPathComponent
        let pattern = #"^YukkuriMovieMaker_v\d+\.\d+\.\d+(\.\d+)?(_Lite)?\.zip$"#
        if name.range(of: pattern, options: .regularExpression) == nil {
            throw RuntimeError.unavailable(CoreMessages.archiveFileNameChanged())
        }
    }

    private func runAutomaticSetup() {
        isWorking = true
        lastCheckSucceeded = false
        status = L.statusAutoStarted
        Task { @MainActor in
            defer { isWorking = false }
            do {
                let paths = try resolvedSetupPaths()
                let output = try await RuntimeBootstrapper.install(paths: paths) { update in
                    Task { @MainActor in
                        status = L.statusAutoProgress(update)
                    }
                }
                runtimeRootPath = paths.runtimeRoot.path
                winePrefixPath = paths.prefix.path
                acceptsThirdPartySetup = false
                status = L.statusAutoComplete(output)
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func choosePrefix() {
        chooseDirectory(message: L.promptPrefixFolder) {
            winePrefixPath = $0.path
            settingsChanged(L.statusPrefixFolderSet)
        }
    }

    private func chooseYMM4Executable() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = L.promptExe
        if panel.runModal() == .OK, let url = panel.url {
            guard url.lastPathComponent.caseInsensitiveCompare("YukkuriMovieMaker.exe") == .orderedSame else {
                status = L.statusExePickWrongFile
                return
            }
            ymm4ExecutablePath = url.standardizedFileURL.path
            ymm4ArchivePath = ""
            settingsChanged(L.statusExeSet)
        }
    }

    private func chooseAndInstallYMM4Archive() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.message = L.promptArchive
        guard panel.runModal() == .OK, let archive = panel.url else { return }

        isWorking = true
        lastCheckSucceeded = false
        status = L.statusArchiveVerifying
        Task { @MainActor in
            defer { isWorking = false }
            do {
                let catalog = try loadYMM4Catalog()
                let selectedArchive = archive.standardizedFileURL
                let installed = try await installSelectedYMM4Archive(
                    selectedArchive, catalog: catalog
                )
                ymm4ArchivePath = archive.standardizedFileURL.path
                ymm4ExecutablePath = installed.executable.path
                if installed.release.classification == .maintenanceCandidate {
                    status = L.statusMaintenanceSwitched(installed.release.displayVersion)
                } else {
                    status = installed.reusedExistingInstall
                        ? L.statusReusedInstall(installed.release.displayVersion)
                        : L.statusPrepared(installed.release.displayVersion)
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    @MainActor
    private func installSelectedYMM4Archive(
        _ selectedArchive: URL,
        catalog: YMM4ReleaseCatalog
    ) async throws -> YMM4InstalledRelease {
        let archiveHash = try await Task.detached(priority: .userInitiated) {
            try YMM4ArchiveInstaller.archiveSHA256(at: selectedArchive)
        }.value
        if catalog.release(archiveSHA256: archiveHash) != nil {
            return try await YMM4ArchiveInstaller.install(
                archive: selectedArchive, catalog: catalog
            )
        }

        status = L.statusUnregisteredChecking
        let receipt = try await YMM4OfficialReleaseVerifier.verify(archive: selectedArchive)
        guard let family = catalog.maintenanceFamily(
            version: receipt.version, edition: receipt.edition
        ) else {
            throw RuntimeError.unavailable(L.errorMaintenanceOutsideFamily)
        }
        guard confirmMaintenanceCandidate(receipt: receipt, family: family) else {
            throw RuntimeError.unavailable(L.errorMaintenanceCancelled)
        }
        return try await YMM4ArchiveInstaller.installMaintenanceCandidate(
            archive: selectedArchive, receipt: receipt, family: family
        )
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
            throw RuntimeError.unavailable(L.errorCatalogMissing)
        }
        return try YMM4ReleaseCatalog.load(from: development)
    }

    private func chooseMediaRoot() {
        chooseDirectory(message: L.promptProject) {
            mediaRootPath = $0.resolvingSymlinksInPath().path
            settingsChanged(L.statusMediaFolderSet)
        }
    }

    private func chooseDirectory(message: String, completion: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = message
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.standardizedFileURL)
        }
    }

    private func settingsChanged(_ message: String) {
        lastCheckSucceeded = false
        status = message + L.settingsChangedSuffix
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
            status = L.statusMigratedSettings
        } else if result.needsRuntimeSetup || result.needsYMM4Setup {
            lastCheckSucceeded = false
            status = L.statusLegacyStandardPaths
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
            ? L.statusClearedWithEnv
            : L.statusCleared
    }

    private func makeBackend() throws -> RosettaWineBackend {
        guard !effectiveRuntimeRootPath.isEmpty else {
            throw RuntimeError.unavailable(L.errorNeedRuntime)
        }
        guard !effectivePrefixPath.isEmpty else {
            throw RuntimeError.unavailable(L.errorNeedPrefix)
        }
        let runtimeRoot = URL(fileURLWithPath: effectiveRuntimeRootPath, isDirectory: true)
        let prefixURL = URL(fileURLWithPath: effectivePrefixPath, isDirectory: true)
        let defaults = RuntimeSetupPaths.defaults()
        if runtimeRoot.standardizedFileURL == defaults.runtimeRoot.standardizedFileURL,
           prefixURL.standardizedFileURL
            == defaults.prefix.standardizedFileURL {
            try RuntimeBootstrapper.validateActivePair(defaults)
        } else {
            // Custom versioned stores (`.../current`) carry the same binding
            // contract as the defaults. A stale prefix paired with a new
            // runtime must stop here with a bilingual message, not later
            // inside Wine with an opaque failure.
            try validateCustomPairIfVersioned(runtimeRoot: runtimeRoot, prefix: prefixURL)
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
            prefixURL: prefixURL
        )
    }

    /// Best-effort binding check for developer-selected versioned stores.
    /// `.../current` channels without a readable binding are not trusted;
    /// plain folders (pre-setup empty dirs) are left to `probe()` so the
    /// error stays the specific manifest/profile message, not a generic one.
    private func validateCustomPairIfVersioned(runtimeRoot: URL, prefix: URL) throws {
        guard runtimeRoot.lastPathComponent == "current",
              prefix.lastPathComponent == "current" else { return }
        let runtimeBindingCandidate = runtimeRoot
            .appendingPathComponent("ymm4m-runtime.json")
        let prefixBindingCandidate = prefix
            .appendingPathComponent("ymm4m-runtime-binding.json")
        // Only enforce when the pair looks like a built versioned pair
        // (both markers present). Empty pre-setup folders have neither and
        // fall through to the specific probe errors.
        let runtimeLooksBuilt = FileManager.default
            .fileExists(atPath: runtimeBindingCandidate.path)
        let prefixLooksBuilt = FileManager.default
            .fileExists(atPath: prefixBindingCandidate.path)
        guard runtimeLooksBuilt || prefixLooksBuilt else { return }
        // Reconstruct stores as `<...>/Runtimes` / `<...>/Prefixes` siblings
        // is unreliable for arbitrary custom layouts, so validate the live
        // pair directly: both must be ready and the binding must match the
        // current profile.
        let runtimeReady = FileManager.default
            .fileExists(atPath: runtimeBindingCandidate.path)
        let prefixReady = RosettaWineBackend
            .hasRequiredWPFSoftwareProfile(at: prefix)
        guard runtimeReady, prefixReady else {
            throw RuntimeError.unavailable(CoreMessages.activePairNotReady())
        }
        guard let data = try? Data(contentsOf: prefixBindingCandidate),
              let binding = try? JSONDecoder().decode(
                PrefixBindingSnapshot.self, from: data
              ),
              binding.schema == RuntimeSetupPaths.currentPrefixSchema,
              binding.runtimeProfile == RuntimeSetupPaths.currentRuntimeProfile else {
            throw RuntimeError.unavailable(CoreMessages.activePairMismatch())
        }
    }

    private struct PrefixBindingSnapshot: Decodable {
        let schema: Int
        let runtimeProfile: String
    }

    private func checkSetup() {
        isWorking = true
        lastCheckSucceeded = false
        status = L.statusCheckingSettings
        Task { @MainActor in
            defer { isWorking = false }
            do {
                let backend = try makeBackend()
                let probe = try await backend.probe()
                guard probe.available else { throw RuntimeError.unavailable(probe.reason) }

                let prefix = URL(fileURLWithPath: effectivePrefixPath, isDirectory: true)
                guard RosettaWineBackend.isSafePrefixPath(prefix.path, home: environment["HOME"]) else {
                    throw RuntimeError.unavailable(L.errorPrefixUnsafe)
                }
                guard RosettaWineBackend.hasRequiredWPFSoftwareProfile(at: prefix) else {
                    throw RuntimeError.unavailable(L.errorPrefixNoProfile)
                }

                let executable = try configuredExecutable()
                let catalog = try loadYMM4Catalog()
                let compatibility = try await Task.detached(priority: .userInitiated) {
                    try YMM4CompatibilityPolicy.classify(executable: executable, catalog: catalog)
                }.value
                if compatibility.classification == .knownBroken {
                    throw RuntimeError.unavailable(L.errorKnownBroken)
                }
                try validateRuntimeRequirement(compatibility)

                if !effectiveMediaRootPath.isEmpty {
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(
                        atPath: effectiveMediaRootPath,
                        isDirectory: &isDirectory
                    ), isDirectory.boolValue else {
                        throw RuntimeError.unavailable(L.errorMediaFolderMissing)
                    }
                }

                lastCheckSucceeded = true
                if compatibility.classification == .knownCompatible {
                    status = L.statusCheckOKKnown(compatibility.displayVersion ?? "")
                } else if compatibility.classification == .maintenanceCandidate {
                    status = L.statusCheckOKMaintenance(compatibility.displayVersion ?? "")
                } else {
                    status = L.statusCheckOKUnknown
                }
                // Non-blocking: a host outside the validated macOS 26 surface
                // is informed, never refused, at the settings gate.
                if let hostNotice = HostCompatibility.untestedOSNotice() {
                    status += "\n" + hostNotice
                }
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func configuredExecutable() throws -> URL {
        guard !effectiveExecutablePath.isEmpty else {
            throw RuntimeError.unavailable(L.errorNeedExe)
        }
        let executable = URL(fileURLWithPath: effectiveExecutablePath)
        guard FileManager.default.isReadableFile(atPath: executable.path) else {
            throw RuntimeError.invalidExecutable(executable)
        }
        return executable
    }

    private func launchYMM4(projectURL: URL? = nil) {
        let openingName = projectURL?.lastPathComponent
        isWorking = true
        status = openingName == nil ? L.statusLaunching : L.statusOpening(openingName ?? "")
        Task { @MainActor in
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
                        throw RuntimeError.unavailable(L.errorNeedMediaFolder)
                    }
                    let mediaRoot = URL(fileURLWithPath: effectiveMediaRootPath, isDirectory: true)
                    let prefix = URL(fileURLWithPath: effectivePrefixPath, isDirectory: true)
                    try WineMediaDrive.configure(prefix: prefix, mediaRoot: mediaRoot)
                    arguments = [try PathMapper(mediaRoot: mediaRoot).winePath(for: projectURL)]
                }

                _ = try await backend.launch(executable: executable, arguments: arguments)
                if let openingName {
                    status = L.statusHandedProject(openingName)
                    if projectURL != nil, let hostNotice = HostCompatibility.untestedOSNotice() {
                        status += "\n" + hostNotice
                    }
                } else {
                    status = L.statusLaunched
                    if let hostNotice = HostCompatibility.untestedOSNotice() {
                        status += "\n" + hostNotice
                    }
                }
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
        panel.message = L.promptProjectPicker
        if panel.runModal() == .OK, let url = panel.url {
            launchYMM4(projectURL: url)
        }
    }

    private func openFromFinder(_ url: URL) {
        guard url.pathExtension.lowercased() == "ymmp" else {
            status = L.statusUnsupportedFinderType(url.pathExtension.lowercased())
            return
        }
        guard hasProjectSettings else {
            status = L.statusFinderNeedsSetup
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
            status = L.statusKnownBroken
            return false
        case .unknown:
            let managedStore = YMM4InstallationPaths.defaults().store.standardizedFileURL.path + "/"
            if executable.standardizedFileURL.path.hasPrefix(managedStore) {
                status = L.statusManagedHashChanged
                return false
            }
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L.alertUnknownExeTitle
            alert.informativeText = L.alertUnknownExeBody
            alert.addButton(withTitle: L.alertUnknownExeContinue)
            alert.addButton(withTitle: L.alertUnknownExeReselect)
            if alert.runModal() == .alertFirstButtonReturn { return true }
            status = L.statusPickExeAgain
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
        alert.messageText = L.alertMaintenanceTitle(receipt.version)
        alert.informativeText = L.alertMaintenanceBody(family.versionPrefix)
        alert.addButton(withTitle: L.alertMaintenanceAccept)
        alert.addButton(withTitle: L.alertMaintenanceKeep)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func rollbackYMM4() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L.alertRollbackTitle
        alert.informativeText = L.alertRollbackBody
        alert.addButton(withTitle: L.alertRollbackConfirm)
        alert.addButton(withTitle: L.alertCancel)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        isWorking = true
        lastCheckSucceeded = false
        status = L.statusRollbackVerifying
        Task { @MainActor in
            defer { isWorking = false }
            do {
                let catalog = try loadYMM4Catalog()
                let executable = try await Task.detached(priority: .userInitiated) {
                    try YMM4ArchiveInstaller.rollback(catalog: catalog)
                }.value
                ymm4ExecutablePath = executable.path
                ymm4ArchivePath = ""
                status = L.statusRollbackDone
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private func validateRuntimeRequirement(_ result: YMM4CompatibilityResult) throws {
        if let required = result.requiredRuntimeProfile,
           required != RuntimeSetupPaths.currentRuntimeProfile {
            throw RuntimeError.unavailable(L.errorRuntimeProfileMissing(required))
        }
    }

    private func commitAssistedText() {
        guard let bridge = YMM4TextInputBridge.configured() else {
            status = L.statusImeHelperMissing
            return
        }
        isCommittingText = true
        let committedText = assistedText
        Task { @MainActor in
            do {
                try await bridge.commit(committedText)
                status = L.statusImeCommitted
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
    private let L = Loc.current
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
                        Text(L.optionalTag)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if sourceIsEnvironment {
                        Text(L.environmentTag)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }
                }
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(path.isEmpty ? L.notSetPlaceholder : path)
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
