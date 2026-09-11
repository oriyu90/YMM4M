import Foundation

/// Compile-time-checked bilingual (Japanese / English) strings for the YMM4M
/// setup window. Every field must be supplied in both `Loc.ja` and `Loc.en`, so
/// the two languages can never silently drift apart. `Loc.current` picks the
/// table from the user's preferred languages at launch.
///
/// Diagnostic text raised inside `YMM4MCore` is bilingual too: error types
/// expose `message(for:)` and `CoreMessages` renders both languages, selected
/// by the same preferred-languages rule, so the status area never shows a
/// Japanese-only core message under the English UI.
struct Loc: Sendable {
    // Header / chrome
    let windowTitle: String
    let headerTitle: String
    let headerSubtitle: String
    let versionBadge: String
    let developmentWarning: String
    let detailDisclosure: String
    let optionalTag: String
    let environmentTag: String
    let chooseFolder: String
    let chooseZip: String

    // One-shot install panel
    let bulkInstallTitle: String
    let bulkInstallBody: String
    let bulkInstallFreeSpace: String
    let bulkInstallConsent: String
    let bulkInstallButton: String
    let bulkInstallExcludes: String
    let setupCounter: @Sendable (Int) -> String
    let setupReady: String
    let setupNotReady: String

    // Individual setup steps
    let step1Title: String
    let step1Detail: String
    let step2Title: String
    let step2Detail: String
    let step3Title: String
    let step3Detail: String
    let step3PickExe: String
    let step4Title: String
    let step4Detail: String

    // Launch panel
    let checkSettingsButton: String
    let launchButton: String
    let openProjectButton: String
    let lastCheckOK: String
    let lastCheckPending: String
    let rollbackButton: String
    let clearSettingsButton: String

    // Usage help
    let usageHelpTitle: String
    let usageStep1: String
    let usageStep2: String
    let usageStep3: String
    let usageStep4: String
    let usageGatekeeperNote: String

    // Japanese input helper
    let imePanelTitle: String
    let imePanelBody: String
    let imeFieldPrompt: String
    let imeCommitButton: String

    // Status panel
    let currentStatusTitle: String
    let launchGroupTitle: String

    // Open-panel prompts
    let promptRuntimeFolder: String
    let promptPrefixFolder: String
    let promptArchive: String
    let promptMediaFolder: String
    let promptExe: String
    let promptProject: String
    let promptProjectPicker: String

    // Status / result messages
    let statusInitial: String
    let settingsChangedSuffix: String
    let statusRuntimeFolderSet: String
    let statusPrefixFolderSet: String
    let statusExeSet: String
    let statusMediaFolderSet: String
    let statusBulkStarted: String
    let statusBulkProgress: @Sendable (String) -> String
    let statusBulkRuntimeVerified: String
    let statusBulkComplete: @Sendable (String) -> String
    let statusRetryHint: String
    let statusAutoStarted: String
    let statusAutoProgress: @Sendable (String) -> String
    let statusAutoComplete: @Sendable (String) -> String
    let statusArchiveVerifying: String
    let statusMaintenanceSwitched: @Sendable (String) -> String
    let statusReusedInstall: @Sendable (String) -> String
    let statusPrepared: @Sendable (String) -> String
    let statusUnregisteredChecking: String
    let statusCheckingSettings: String
    let statusCheckOKKnown: @Sendable (String) -> String
    let statusCheckOKMaintenance: @Sendable (String) -> String
    let statusCheckOKUnknown: String
    let statusLaunching: String
    let statusOpening: @Sendable (String) -> String
    let statusLaunched: String
    let statusHandedProject: @Sendable (String) -> String
    let statusUnsupportedFinderType: @Sendable (String) -> String
    let statusFinderNeedsSetup: String
    let statusKnownBroken: String
    let statusManagedHashChanged: String
    let statusPickExeAgain: String
    let statusMigratedSettings: String
    let statusLegacyStandardPaths: String
    let statusClearedWithEnv: String
    let statusCleared: String
    let statusExePickWrongFile: String
    let statusRollbackDone: String
    let statusRollbackVerifying: String
    let statusImeHelperMissing: String
    let statusImeCommitted: String

    // Errors surfaced from the app layer
    let errorNeedRuntime: String
    let errorNeedPrefix: String
    let errorNeedExe: String
    let errorNeedMediaFolder: String
    let errorPrefixUnsafe: String
    let errorPrefixNoProfile: String
    let errorKnownBroken: String
    let errorMediaFolderMissing: String
    let errorCatalogMissing: String
    let errorRuntimeProfileMismatch: String
    let errorRuntimeProfileMissing: @Sendable (String) -> String
    let errorMaintenanceOutsideFamily: String
    let errorMaintenanceCancelled: String
    let errorNeedBothFolders: String
    let errorRuntimePrefixUnsafe: String
    let errorRuntimePrefixSame: String
    let errorPrefixAbsolutePath: String
    let notSetPlaceholder: String

    // Alerts
    let alertUnknownExeTitle: String
    let alertUnknownExeBody: String
    let alertUnknownExeContinue: String
    let alertUnknownExeReselect: String
    let alertMaintenanceTitle: @Sendable (String) -> String
    let alertMaintenanceBody: @Sendable (String) -> String
    let alertMaintenanceAccept: String
    let alertMaintenanceKeep: String
    let alertRollbackTitle: String
    let alertRollbackBody: String
    let alertRollbackConfirm: String
    let alertCancel: String

    static let current: Loc = {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("ja") ? .ja : .en
    }()
}

extension Loc {
    static let ja = Loc(
        windowTitle: "YMM4M",
        headerTitle: "YMM4M セットアップ",
        headerSubtitle: "YukkuriMovieMaker4をMacで開くための互換環境",
        versionBadge: "v1.0.2",
        developmentWarning: "YMM4本体は同梱・自動取得しません。Wine/DXMTは同意後に固定URL（ミラー対応）から取得してhash検証し、このMac上でビルドします。Developer ID署名・公証はありません。",
        detailDisclosure: "個別セットアップ・開発者向け詳細設定",
        optionalTag: "任意",
        environmentTag: "環境変数",
        chooseFolder: "フォルダを選択",
        chooseZip: "ZIPを選んで準備",
        bulkInstallTitle: "互換環境を一括インストール",
        bulkInstallBody: "公式YMM4 ZIP（通常版／Lite）と、YMM4で素材・プロジェクトを管理するフォルダを順に選ぶだけです。Runtime、専用prefix、YMM4の検証済みコピー、M:ドライブをまとめて準備します。",
        bulkInstallFreeSpace: "選んだ元ZIPは移動・削除しません。途中で失敗しても同じボタンから再開でき、不完全な管理領域はRecoveryへ退避します。完了まで時間と約10 GB以上の空き容量（LLVM toolchainの展開分を含む）が必要です。",
        bulkInstallConsent: "第三者ライセンスのソフトウェアをネットから取得し、このMacでビルドすることに同意します",
        bulkInstallButton: "互換環境を一括インストール",
        bulkInstallExcludes: "取得しないもの：YMM4本体、Microsoftランタイム／フォント、CrossOver、ユーザーのプロジェクト。Noto Sans CJK JPはWine prefix内だけに置きます。",
        setupCounter: { "一括セットアップ \($0) / 4" },
        setupReady: "必要項目は設定済み",
        setupNotReady: "一括インストールを実行してください",
        step1Title: "互換ランタイム",
        step1Detail: "検証済みWine/DXMTフォルダ、または自動セットアップに作成させたい空のフォルダを指定します。指定後に「互換環境を一括インストール」を押すと、その場所へ versions/ と current を作成します。DMGには含まれません。",
        step2Title: "専用Wine prefix",
        step2Detail: "YMM4専用のWindows環境フォルダです。準備済みprefix、または自動セットアップに作成させたい空のフォルダを、互換ランタイムとは別の場所に指定します。",
        step3Title: "公式YMM4 ZIP（通常版／Lite）",
        step3Detail: "先にZIPをダウンロードフォルダなど自動削除されない場所へ保存してください。YMM4Mは選んだZIPを移動・削除せず、hash・構造検証後にversion別専用領域へ展開します。",
        step3PickExe: "展開済みEXEを選ぶ（開発者向け）",
        step4Title: "YMM4のメディア・プロジェクト用フォルダ",
        step4Detail: ".ymmpと素材を置くフォルダです。Wine側では安全なM:ドライブとして見えます。",
        checkSettingsButton: "1. 設定を確認",
        launchButton: "2. YMM4をMacで開く",
        openProjectButton: "プロジェクトを選んで開く",
        lastCheckOK: "直近の設定確認は成功しました",
        lastCheckPending: "起動前に設定確認を実行してください",
        rollbackButton: "前のYMM4へ戻す",
        clearSettingsButton: "保存した設定をクリア",
        usageHelpTitle: "MacでYMM4を開く手順",
        usageStep1: "1. 公式の通常版またはLiteのZIPを、自動削除されない場所へ保存します。",
        usageStep2: "2. 同意項目を確認し、「互換環境を一括インストール」を押します。",
        usageStep3: "3. YMM4 ZIPと、YMM4で使うメディア・プロジェクト用フォルダを順に選びます。以後の準備と検証は自動です。",
        usageStep4: "4. 完了後に「YMM4をMacで開く」を押します。",
        usageGatekeeperNote: "初回起動時にmacOSが拒否する場合があります。この版はDeveloper ID署名・公証がないためで、通常配布版としての起動は保証していません。Gatekeeperを全体無効化しないでください。",
        imePanelTitle: "日本語入力補助（YMM4 Lite 4.55.1.1限定）",
        imePanelBody: "YMM4内で直接日本語変換できない場合に、ここで変換・確定してから台詞欄へ転送します。YMM4を先に起動してください。「追加」は自動操作しません。",
        imeFieldPrompt: "ここで日本語を変換・確定",
        imeCommitButton: "確定した文字をYMM4の台詞欄へ送る",
        currentStatusTitle: "現在の状態",
        launchGroupTitle: "起動",
        promptRuntimeFolder: "互換ランタイムを置くフォルダを選択してください。既存の検証済みランタイム、または空のフォルダ（この場所へ自動セットアップが versions/ と current を作成します）のどちらでも構いません。",
        promptPrefixFolder: "専用Wine prefixを置くフォルダを選択してください。準備済みprefix、または空のフォルダ（自動セットアップがここへ作成します）のどちらでも構いません。互換ランタイムとは別のフォルダにしてください。",
        promptArchive: "自動削除されない場所に保存した公式YMM4 ZIP（通常版／Lite）を選んでください。元ZIPは移動・削除しません。",
        promptMediaFolder: "YMM4で素材と.ymmpプロジェクトを管理するフォルダを選んでください。",
        promptExe: "公式配布物内のYukkuriMovieMaker.exeを選択してください",
        promptProject: ".ymmpと素材を置く専用フォルダを選択してください",
        promptProjectPicker: "手順4で選んだフォルダ内の.ymmpを選択してください",
        statusInitial: "互換環境を自動セットアップし、YMM4本体を選択してください。",
        settingsChangedSuffix: " 続けて未設定の項目を選んでください。",
        statusRuntimeFolderSet: "互換ランタイムの場所を設定しました。空のフォルダなら「互換環境を一括インストール」でここへ作成されます。",
        statusPrefixFolderSet: "専用Wine prefixの場所を設定しました。空のフォルダなら「互換環境を一括インストール」でここへ作成されます。",
        statusExeSet: "YMM4本体を設定しました。",
        statusMediaFolderSet: "プロジェクト用フォルダを設定しました。",
        statusBulkStarted: "一括セットアップを開始します。不完全な管理領域を安全に退避し、runtimeとprefixを検証しています…",
        statusBulkProgress: { "一括セットアップ中（runtimeは最終検証後に配置）\n\($0)" },
        statusBulkRuntimeVerified: "runtimeとprefixの検証が完了しました。YMM4 ZIPを検証し、専用領域へコピーしています…",
        statusBulkComplete: { "一括セットアップが完了しました。YMM4 \($0)、互換runtime、専用prefix、メディアフォルダを検証済みです。「YMM4をMacで開く」を押してください。" },
        statusRetryHint: "\n同じ「互換環境を一括インストール」から再実行できます。",
        statusAutoStarted: "Wine/DXMTを取得・検証・ビルドしています。downloadとbuild完了後にruntimeを一括配置するため、それまではruntime保存先が空でも正常です。アプリを終了しないでください…",
        statusAutoProgress: { "自動セットアップ中（runtimeは最終検証後に配置）\n\($0)" },
        statusAutoComplete: { "互換環境の準備が完了しました。次に公式YMM4 ZIPを選んでください。\n\($0)" },
        statusArchiveVerifying: "YMM4 ZIPのhashと構造を検証し、専用領域へ準備しています…",
        statusMaintenanceSwitched: { "公式の保守更新候補YMM4 \($0)へ切り替えました。以前の版は保持されています。「設定を確認」後、問題があれば「前のYMM4へ戻す」を使用してください。" },
        statusReusedInstall: { "検証済みYMM4 \($0) を再利用します。「設定を確認」へ進んでください。" },
        statusPrepared: { "YMM4 \($0) の準備が完了しました。「設定を確認」へ進んでください。" },
        statusUnregisteredChecking: "未登録ZIPの公式Release情報と保守更新境界を確認しています…",
        statusCheckingSettings: "設定を確認しています…",
        statusCheckOKKnown: { "設定OK：検証済みYMM4 \($0) とランタイムを確認しました。「YMM4を起動」を押せます。" },
        statusCheckOKMaintenance: { "設定OK：公式保守更新候補YMM4 \($0)のランタイム境界を確認しました。未検証のアプリ動作があれば「前のYMM4へ戻す」を使用してください。" },
        statusCheckOKUnknown: "ランタイムとprefixは確認できましたが、YMM4のhashは未検証です。起動時の警告を確認してください。",
        statusLaunching: "YMM4を起動しています…",
        statusOpening: { "\($0)を開いています…" },
        statusLaunched: "YMM4を起動しました。YMM4のウィンドウが表示されるまでお待ちください。",
        statusHandedProject: { "\($0)をYMM4へ渡しました。元ファイルは変更していません。" },
        statusUnsupportedFinderType: { ".\($0)の自動取り込みは未検証です。ファイルは変更しませんでした。" },
        statusFinderNeedsSetup: "Finderからプロジェクトを開く前に、手順1〜4を設定してください。",
        statusKnownBroken: "このYMM4実行ファイルは既知の非互換版のため起動しません。",
        statusManagedHashChanged: "専用領域内のYMM4が検証済みhashから変化しているため起動しません。対応カタログを更新したYMM4Mで公式ZIPを再導入してください。",
        statusPickExeAgain: "YMM4実行ファイルを選び直してください。",
        statusMigratedSettings: "保存済みの標準設定を現在のcurrentチャネルへ引き継ぎました。起動前に「設定を確認」を実行してください。",
        statusLegacyStandardPaths: "以前の標準保存先が設定されています。カスタムパスは変更せず、必要なセットアップをやり直すまで起動しません。",
        statusClearedWithEnv: "保存した設定を消去しました。環境変数で指定された項目は引き続き表示されます。",
        statusCleared: "保存した設定を消去しました。",
        statusExePickWrongFile: "YukkuriMovieMaker.exeを選択してください。別のファイルは保存しませんでした。",
        statusRollbackDone: "以前のYMM4へ切り戻しました。保存設定もcurrentチャネルへ更新しました。「設定を確認」を実行してください。",
        statusRollbackVerifying: "以前のYMM4を検証して切り戻しています…",
        statusImeHelperMissing: "日本語入力helperが未設定です。この機能にはYMM4M_TEXT_COMMIT_HELPERの設定が必要です。",
        statusImeCommitted: "確定した文字をYMM4の台詞欄へ入力しました。",
        errorNeedRuntime: "手順1の互換ランタイムを選択してください。",
        errorNeedPrefix: "手順2の専用Wine prefixを選択してください。",
        errorNeedExe: "手順3のYMM4本体を選択してください。",
        errorNeedMediaFolder: "手順4のプロジェクト用フォルダを選択してください。",
        errorPrefixUnsafe: "専用Wine prefixに安全な絶対パスを選択してください。",
        errorPrefixNoProfile: "選択したprefixにWPF software profileがありません。準備済みの専用prefixを選択してください。",
        errorKnownBroken: "選択したYMM4は既知の非互換版です。",
        errorMediaFolderMissing: "選択したプロジェクト用フォルダが見つかりません。",
        errorCatalogMissing: "YMM4互換カタログがアプリ内にありません。",
        errorRuntimeProfileMismatch: "選択したYMM4が必要とするruntime profileと現在の互換環境が一致しません。",
        errorRuntimeProfileMissing: { "このYMM4に必要なランタイム \($0) は現在のYMM4Mにはありません。YMM4Mを更新してください。" },
        errorMaintenanceOutsideFamily: "公式YMM4であることは確認できましたが、検証済み保守系列の外です。大型更新として扱い、YMM4Mの互換性確認が完了するまで導入しません。",
        errorMaintenanceCancelled: "保守更新候補の導入を中止しました。現在のYMM4は変更していません。",
        errorNeedBothFolders: "個別セットアップでは互換ランタイムと専用prefixの両方のフォルダを指定してください。自動セットアップがその場所へ一式を作成します。",
        errorRuntimePrefixUnsafe: "互換ランタイム／prefixのフォルダに安全な場所を選んでください。",
        errorRuntimePrefixSame: "互換ランタイムと専用prefixには別々のフォルダを選んでください。",
        errorPrefixAbsolutePath: "専用prefixのフォルダに安全な絶対パスを選んでください。",
        notSetPlaceholder: "未設定",
        alertUnknownExeTitle: "未検証のYMM4です",
        alertUnknownExeBody: "この実行ファイルのhashは検証済みYMM4 4.55.1.1（通常版／Lite）と一致しません。続行すると予期しない問題が起きる可能性があります。",
        alertUnknownExeContinue: "理解して続行",
        alertUnknownExeReselect: "選び直す",
        alertMaintenanceTitle: { "公式の保守更新候補 \($0) を試しますか？" },
        alertMaintenanceBody: { "公式SHA-256と検証済み \($0).x 系のランタイム境界を確認しますが、この版固有の画面・IME・編集動作は未検証です。現在の版をpreviousとして保持し、YMM4Mから切り戻せます。" },
        alertMaintenanceAccept: "保守更新候補として導入",
        alertMaintenanceKeep: "現在の版を使う",
        alertRollbackTitle: "直前のYMM4へ戻しますか？",
        alertRollbackBody: "現在の版は削除せずpreviousとして保持します。共有設定dataも削除しません。切替後に設定確認を実行してください。",
        alertRollbackConfirm: "前の版へ戻す",
        alertCancel: "キャンセル"
    )

    static let en = Loc(
        windowTitle: "YMM4M",
        headerTitle: "YMM4M Setup",
        headerSubtitle: "A compatibility environment for opening YukkuriMovieMaker4 on a Mac",
        versionBadge: "v1.0.2",
        developmentWarning: "YMM4 itself is never bundled or auto-downloaded. After you consent, Wine/DXMT are fetched from fixed URLs (with mirrors), hash-verified, and built on this Mac. There is no Developer ID signature or notarization.",
        detailDisclosure: "Individual setup / developer options",
        optionalTag: "Optional",
        environmentTag: "Env var",
        chooseFolder: "Choose folder",
        chooseZip: "Choose a ZIP to prepare",
        bulkInstallTitle: "Install the compatibility environment",
        bulkInstallBody: "Just pick the official YMM4 ZIP (Standard or Lite) and a folder where YMM4 will keep your assets and projects. The runtime, the dedicated prefix, a verified copy of YMM4, and the M: drive are all prepared together.",
        bulkInstallFreeSpace: "Your source ZIP is never moved or deleted. If a run is interrupted you can resume from the same button, and incomplete managed areas are moved to Recovery. Allow time and about 10 GB of free space (including the extracted LLVM toolchain).",
        bulkInstallConsent: "I agree to download third-party licensed software from the network and build it on this Mac",
        bulkInstallButton: "Install the compatibility environment",
        bulkInstallExcludes: "Never fetched: YMM4 itself, Microsoft runtimes/fonts, CrossOver, your projects. Noto Sans CJK JP is placed only inside the Wine prefix.",
        setupCounter: { "One-shot setup \($0) / 4" },
        setupReady: "Required items are set",
        setupNotReady: "Run the one-shot install",
        step1Title: "Compatibility runtime",
        step1Detail: "Choose a verified Wine/DXMT folder, or an empty folder for the automatic setup to populate. After choosing, pressing “Install the compatibility environment” creates versions/ and current there. It is not included in the DMG.",
        step2Title: "Dedicated Wine prefix",
        step2Detail: "A Windows-environment folder used only by YMM4. Choose a prepared prefix, or an empty folder for the automatic setup to create, in a different location from the compatibility runtime.",
        step3Title: "Official YMM4 ZIP (Standard / Lite)",
        step3Detail: "First save the ZIP somewhere that is not auto-deleted, such as your Downloads folder. YMM4M never moves or deletes the ZIP you choose; after hash and structure checks it extracts into a per-version dedicated area.",
        step3PickExe: "Choose an already-extracted EXE (developers)",
        step4Title: "YMM4 media / project folder",
        step4Detail: "The folder that holds .ymmp files and assets. Wine sees it as a contained M: drive.",
        checkSettingsButton: "1. Check settings",
        launchButton: "2. Open YMM4 on the Mac",
        openProjectButton: "Choose a project to open",
        lastCheckOK: "The last settings check succeeded",
        lastCheckPending: "Run a settings check before launching",
        rollbackButton: "Roll back to the previous YMM4",
        clearSettingsButton: "Clear saved settings",
        usageHelpTitle: "How to open YMM4 on a Mac",
        usageStep1: "1. Save the official Standard or Lite ZIP somewhere that is not auto-deleted.",
        usageStep2: "2. Review the consent item and press “Install the compatibility environment”.",
        usageStep3: "3. Choose the YMM4 ZIP and the media/project folder YMM4 will use. Everything after that is prepared and verified automatically.",
        usageStep4: "4. When it finishes, press “Open YMM4 on the Mac”.",
        usageGatekeeperNote: "macOS may refuse the first launch. This build has no Developer ID signature or notarization, so launching it as a normal distribution is not guaranteed. Do not disable Gatekeeper globally.",
        imePanelTitle: "Japanese input helper (YMM4 Lite 4.55.1.1 only)",
        imePanelBody: "When Japanese cannot be composed directly inside YMM4, convert and confirm it here, then transfer it to the dialogue field. Launch YMM4 first. “Add” is never triggered automatically.",
        imeFieldPrompt: "Convert and confirm Japanese here",
        imeCommitButton: "Send the confirmed text to YMM4's dialogue field",
        currentStatusTitle: "Current status",
        launchGroupTitle: "Launch",
        promptRuntimeFolder: "Choose a folder for the compatibility runtime. It can be an existing verified runtime, or an empty folder (the automatic setup creates versions/ and current there).",
        promptPrefixFolder: "Choose a folder for the dedicated Wine prefix. It can be a prepared prefix, or an empty folder (the automatic setup creates it there). Use a different folder from the compatibility runtime.",
        promptArchive: "Choose the official YMM4 ZIP (Standard / Lite) you saved somewhere that is not auto-deleted. The source ZIP is never moved or deleted.",
        promptMediaFolder: "Choose the folder where YMM4 will manage assets and .ymmp projects.",
        promptExe: "Choose YukkuriMovieMaker.exe from the official distribution",
        promptProject: "Choose a dedicated folder for .ymmp files and assets",
        promptProjectPicker: "Choose a .ymmp inside the folder you selected in step 4",
        statusInitial: "Set up the compatibility environment automatically, then choose YMM4.",
        settingsChangedSuffix: " Continue by choosing the remaining items.",
        statusRuntimeFolderSet: "Set the compatibility runtime location. If it is an empty folder, “Install the compatibility environment” creates it here.",
        statusPrefixFolderSet: "Set the dedicated Wine prefix location. If it is an empty folder, “Install the compatibility environment” creates it here.",
        statusExeSet: "YMM4 is set.",
        statusMediaFolderSet: "Project folder is set.",
        statusBulkStarted: "Starting the one-shot setup. Moving any incomplete managed area aside safely and verifying the runtime and prefix…",
        statusBulkProgress: { "One-shot setup in progress (the runtime is placed only after final verification)\n\($0)" },
        statusBulkRuntimeVerified: "Runtime and prefix verified. Verifying the YMM4 ZIP and copying it into the dedicated area…",
        statusBulkComplete: { "One-shot setup complete. YMM4 \($0), the compatibility runtime, the dedicated prefix, and the media folder are all verified. Press “Open YMM4 on the Mac”." },
        statusRetryHint: "\nYou can run it again from the same “Install the compatibility environment” button.",
        statusAutoStarted: "Fetching, verifying, and building Wine/DXMT. The runtime is placed in one step after download and build finish, so an empty runtime location is normal until then. Do not quit the app…",
        statusAutoProgress: { "Automatic setup in progress (the runtime is placed only after final verification)\n\($0)" },
        statusAutoComplete: { "The compatibility environment is ready. Next, choose the official YMM4 ZIP.\n\($0)" },
        statusArchiveVerifying: "Verifying the YMM4 ZIP hash and structure and preparing the dedicated area…",
        statusMaintenanceSwitched: { "Switched to the official maintenance-update candidate YMM4 \($0). The previous version is kept. After “Check settings”, use “Roll back to the previous YMM4” if there is a problem." },
        statusReusedInstall: { "Reusing verified YMM4 \($0). Continue to “Check settings”." },
        statusPrepared: { "YMM4 \($0) is ready. Continue to “Check settings”." },
        statusUnregisteredChecking: "Checking the official release info and maintenance-update boundary for an unregistered ZIP…",
        statusCheckingSettings: "Checking settings…",
        statusCheckOKKnown: { "Settings OK: verified YMM4 \($0) and the runtime are confirmed. You can press “Open YMM4”." },
        statusCheckOKMaintenance: { "Settings OK: the runtime boundary of the official maintenance-update candidate YMM4 \($0) is confirmed. If any app behavior is unverified, use “Roll back to the previous YMM4”." },
        statusCheckOKUnknown: "The runtime and prefix are confirmed, but this YMM4's hash is unverified. Check the warning shown at launch.",
        statusLaunching: "Launching YMM4…",
        statusOpening: { "Opening \($0)…" },
        statusLaunched: "YMM4 launched. Please wait for the YMM4 window to appear.",
        statusHandedProject: { "Handed \($0) to YMM4. The source file was not modified." },
        statusUnsupportedFinderType: { "Automatic import of .\($0) is unverified. The file was not modified." },
        statusFinderNeedsSetup: "Before opening a project from Finder, complete steps 1–4.",
        statusKnownBroken: "This YMM4 executable is a known-incompatible version and will not be launched.",
        statusManagedHashChanged: "The YMM4 in the dedicated area has changed from its verified hash and will not be launched. Reinstall the official ZIP with a YMM4M that has an updated catalog.",
        statusPickExeAgain: "Please re-select the YMM4 executable.",
        statusMigratedSettings: "Carried the saved standard settings over to the current channel. Run “Check settings” before launching.",
        statusLegacyStandardPaths: "A previous standard location is set. Custom paths are left unchanged and it will not launch until the needed setup is redone.",
        statusClearedWithEnv: "Cleared the saved settings. Items set through environment variables are still shown.",
        statusCleared: "Cleared the saved settings.",
        statusExePickWrongFile: "Please choose YukkuriMovieMaker.exe. A different file was not saved.",
        statusRollbackDone: "Rolled back to the previous YMM4. Saved settings were updated to the current channel too. Run “Check settings”.",
        statusRollbackVerifying: "Verifying the previous YMM4 and rolling back…",
        statusImeHelperMissing: "The Japanese input helper is not configured. This feature needs YMM4M_TEXT_COMMIT_HELPER to be set.",
        statusImeCommitted: "Entered the confirmed text into YMM4's dialogue field.",
        errorNeedRuntime: "Choose the compatibility runtime in step 1.",
        errorNeedPrefix: "Choose the dedicated Wine prefix in step 2.",
        errorNeedExe: "Choose YMM4 in step 3.",
        errorNeedMediaFolder: "Choose the project folder in step 4.",
        errorPrefixUnsafe: "Choose a safe absolute path for the dedicated Wine prefix.",
        errorPrefixNoProfile: "The chosen prefix has no WPF software profile. Choose a prepared dedicated prefix.",
        errorKnownBroken: "The chosen YMM4 is a known-incompatible version.",
        errorMediaFolderMissing: "The chosen project folder was not found.",
        errorCatalogMissing: "The YMM4 compatibility catalog is missing from the app.",
        errorRuntimeProfileMismatch: "The runtime profile the chosen YMM4 requires does not match the current compatibility environment.",
        errorRuntimeProfileMissing: { "The runtime \($0) required by this YMM4 is not in the current YMM4M. Update YMM4M." },
        errorMaintenanceOutsideFamily: "This was confirmed as official YMM4, but it is outside the verified maintenance train. It is treated as a feature update and will not be installed until YMM4M compatibility is confirmed.",
        errorMaintenanceCancelled: "Installation of the maintenance-update candidate was cancelled. The current YMM4 is unchanged.",
        errorNeedBothFolders: "Individual setup needs both the compatibility runtime folder and the dedicated prefix folder. The automatic setup creates the full set in those locations.",
        errorRuntimePrefixUnsafe: "Choose a safe location for the compatibility runtime / prefix folders.",
        errorRuntimePrefixSame: "Choose separate folders for the compatibility runtime and the dedicated prefix.",
        errorPrefixAbsolutePath: "Choose a safe absolute path for the dedicated prefix folder.",
        notSetPlaceholder: "Not set",
        alertUnknownExeTitle: "Unverified YMM4",
        alertUnknownExeBody: "This executable's hash does not match verified YMM4 4.55.1.1 (Standard / Lite). Continuing may cause unexpected problems.",
        alertUnknownExeContinue: "I understand, continue",
        alertUnknownExeReselect: "Choose again",
        alertMaintenanceTitle: { "Try the official maintenance-update candidate \($0)?" },
        alertMaintenanceBody: { "The official SHA-256 and the runtime boundary of the verified \($0).x train are checked, but this version's own UI, IME, and editing behavior are unverified. The current version is kept as previous, and YMM4M can roll back." },
        alertMaintenanceAccept: "Install as a maintenance-update candidate",
        alertMaintenanceKeep: "Use the current version",
        alertRollbackTitle: "Roll back to the previous YMM4?",
        alertRollbackBody: "The current version is kept as previous, not deleted. Shared settings data is not deleted either. Run a settings check after switching.",
        alertRollbackConfirm: "Roll back to the previous version",
        alertCancel: "Cancel"
    )
}
