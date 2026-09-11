import Foundation

/// Central table for localizable YMM4MCore user-visible strings.
///
/// Every function renders the same message in Japanese and English.
/// The `language` parameter defaults to the current locale so ordinary call
/// sites stay short; tests pass an explicit language to verify both sides.
/// No function here throws, allocates beyond the string itself, or touches
/// the filesystem, so rendering can never crash setup or launch flows.
public enum CoreMessages {
    // MARK: - RosettaWineBackend: runtime manifest validation

    public static func runtimeManifestMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "ランタイムマニフェストが検証済み構成と一致しません。"
        case .english: return "The runtime manifest does not match a verified configuration."
        }
    }

    public static func runtimeFileHashMalformed(_ relativePath: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "ランタイムファイルのハッシュ表記が不正です: \(relativePath)"
        case .english: return "Runtime file has a malformed hash entry: \(relativePath)"
        }
    }

    public static func runtimeFileMissing(_ relativePath: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "ランタイムファイルがありません: \(relativePath)"
        case .english: return "Runtime file is missing: \(relativePath)"
        }
    }

    public static func runtimeFileHashMismatch(_ relativePath: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "ランタイムファイルのハッシュが一致しません: \(relativePath)"
        case .english: return "Runtime file hash mismatch: \(relativePath)"
        }
    }

    public static func winemacLoadableMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "winemac.soのloadable image hashが検証済み構成と一致しません。"
        case .english: return "The winemac.so loadable-image hash does not match the verified configuration."
        }
    }

    public static func schema2ProvenanceMissing(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "schema 2のランタイムマニフェストにprovenance情報がありません。"
        case .english: return "The schema-2 runtime manifest has no provenance record."
        }
    }

    public static func unsupportedManifestSchema(_ schema: Int, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "未対応のランタイムマニフェストschemaです: \(schema)"
        case .english: return "Unsupported runtime manifest schema: \(schema)"
        }
    }

    public static func provenanceSourcesMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "ランタイムのソース入力が固定値と一致しません。"
        case .english: return "The runtime source inputs do not match the pinned values."
        }
    }

    public static func provenancePatchesMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "適用パッチが固定値と一致しません。"
        case .english: return "The applied patches do not match the pinned values."
        }
    }

    public static func provenanceToolchainTooOld(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "記録されたMinGW toolchainがWine 11.0のビルド要件を満たしません。"
        case .english: return "The recorded MinGW toolchain does not meet the Wine 11.0 build requirements."
        }
    }

    public static func gateRuntimeMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "fixtureゲートの実行対象が現在のランタイム構成と一致しません。"
        case .english: return "The fixture gate was not run against the current runtime files."
        }
    }

    public static func gateLoadableMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "記録されたwinemac.soのloadable image hashが実ファイルと一致しません。"
        case .english: return "The recorded winemac.so loadable-image hash does not match the file on disk."
        }
    }

    public static func gateFixturesMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "fixtureゲートの対象が固定の8 fixtureと一致しません。"
        case .english: return "The fixture gate did not cover the pinned set of eight fixtures."
        }
    }

    public static func gateResultsNotPass(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "fixtureゲートの記録された結果がpassではありません。"
        case .english: return "The recorded fixture-gate results are not both pass."
        }
    }

    public static func winemacMachOStructureInvalid(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "winemac.soのMach-O構造が不正です。"
        case .english: return "winemac.so has an invalid Mach-O structure."
        }
    }

    public static func winemacNotX86_64MachO(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "winemac.soはx86_64 Mach-Oではありません。"
        case .english: return "winemac.so is not an x86_64 Mach-O binary."
        }
    }

    public static func winemacLoadCommandInvalid(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "winemac.soのload commandが不正です。"
        case .english: return "winemac.so has an invalid load command."
        }
    }

    public static func winemacUUIDInvalid(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "winemac.soのLC_UUIDが不正です。"
        case .english: return "winemac.so has an invalid LC_UUID."
        }
    }

    public static func winemacLinkEditMissing(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "winemac.soに有効な__LINKEDITがありません。"
        case .english: return "winemac.so has no valid __LINKEDIT segment."
        }
    }

    // MARK: - RosettaWineBackend: probe and launch

    public static func wineNotConfigured(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "Wine runtimeが設定されていません。検証済みx86_64 Wineを指定してください。"
        case .english: return "Wine runtime is not configured. Set YMM4M_WINE to a validated x86_64 Wine executable."
        }
    }

    public static func rosettaUnavailable(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "このMacでRosettaを確認できません。softwareupdate --install-rosetta で導入してください。"
        case .english: return "Rosetta is unavailable on this Mac. Install it with softwareupdate --install-rosetta."
        }
    }

    public static func cleanRuntimeUnidentifiable(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4Mのクリーンランタイム構成を特定できません。"
        case .english: return "The YMM4M clean-runtime layout could not be identified."
        }
    }

    public static func cleanRuntimeVerified(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "ハッシュ検証済みWine 11.0/DXMTランタイムとRosettaを確認しました。"
        case .english: return "Verified the hash-checked Wine 11.0/DXMT runtime and Rosetta."
        }
    }

    public static func archBridgeMissing(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "x86_64実行のためのarchコマンドがありません。Xcode command line toolsを導入してください。"
        case .english: return "The arch command for x86_64 execution is missing. Install the Xcode command line tools."
        }
    }

    public static func prefixEnvNotAbsolute(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4M_PREFIXに専用の絶対パスを指定してください。"
        case .english: return "Set YMM4M_PREFIX to a dedicated absolute path."
        }
    }

    public static func dedicatedPrefixMissing(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "専用Wineプレフィックスがありません。先に安全な初期化を実行してください。"
        case .english: return "The dedicated Wine prefix is missing. Run the safe initialization first."
        }
    }

    public static func prefixMissingWPFProfile(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "専用WineプレフィックスにWPF software profileが適用されていません。"
        case .english: return "The dedicated Wine prefix has no WPF software profile applied."
        }
    }

    // MARK: - VersionedDirectoryChannel

    public static func invalidChannelName(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "無効なversion channel名です。"
        case .english: return "Invalid version channel name."
        }
    }

    public static func versionTargetVerificationFailed(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "version保管先の検証に失敗しました。"
        case .english: return "The versioned destination failed verification."
        }
    }

    public static func existingChannelNotSymlink(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "既存のversion channelがsymlinkでないため置き換えません。"
        case .english: return "The existing version channel is not a symlink and will not be replaced."
        }
    }

    public static func existingChannelOutsideStore(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "既存のversion channelが専用storeの外を指しています。"
        case .english: return "The existing version channel points outside the dedicated store."
        }
    }

    public static func channelAtomicSwitchFailed(_ errnoValue: Int32, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "version channelのatomic切替に失敗しました。errno=\(errnoValue)"
        case .english: return "Atomic version-channel switch failed. errno=\(errnoValue)"
        }
    }

    // MARK: - RuntimeBootstrapper

    public static func setupMigratedLegacyPair(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "既存の検証済みruntime/prefixをversion付き保管先へ移行し、current channelを切り替えました。"
        case .english: return "Migrated the existing verified runtime/prefix into versioned storage and switched the current channel."
        }
    }

    public static func setupReusesVerifiedPair(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "既存の検証済みランタイムと専用prefixを使用します。"
        case .english: return "Reusing the existing verified runtime and dedicated prefix."
        }
    }

    public static func setupStarted(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "[開始] downloadとbuildを開始します。runtimeは最終検証後に配置されます。"
        case .english: return "[start] Starting download and build. The runtime is placed only after final verification."
        }
    }

    public static func setupReusedVersionedPair(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "既存のversion付きruntime/prefixを検証しました。"
        case .english: return "Verified the existing versioned runtime/prefix."
        }
    }

    public static func setupCompleted(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "[完了] runtimeとprefixを検証し、currentへ切り替えました。"
        case .english: return "[done] Verified the runtime and prefix and switched current."
        }
    }

    public static func setupActivatedSuffix(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "version付き保管先を検証し、current channelをatomicに切り替えました。"
        case .english: return "Verified the versioned storage and atomically switched the current channel."
        }
    }

    public static func setupPrefixReadinessFailed(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "専用prefixの完了検査に失敗しました。"
        case .english: return "The dedicated prefix failed its completion check."
        }
    }

    public static func activePairNotReady(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "runtimeまたはprefixの準備が完了していません。"
        case .english: return "The runtime or prefix is not ready."
        }
    }

    public static func activePairMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "runtimeとprefixのversion組み合わせが一致しません。自動セットアップを再実行してください。"
        case .english: return "The runtime/prefix version combination does not match. Re-run the automatic setup."
        }
    }

    public static func recoveredIncompleteRuntime(_ path: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "不完全なruntimeを\(path)へ退避しました。"
        case .english: return "Moved the incomplete runtime aside to \(path)."
        }
    }

    public static func recoveredIncompletePrefix(_ path: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "不完全なprefixを\(path)へ退避しました。"
        case .english: return "Moved the incomplete prefix aside to \(path)."
        }
    }

    public static func recoveredIncompleteChannel(_ channel: String, _ path: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "不完全な\(channel) channelを\(path)へ退避しました。"
        case .english: return "Moved the incomplete \(channel) channel aside to \(path)."
        }
    }

    public static func managedPathOutsideStore(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "再セットアップ対象がYMM4Mのversion保管先の外です。"
        case .english: return "The re-setup target is outside YMM4M versioned storage."
        }
    }

    public static func recoveryNotDirectory(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "Recovery保管先がdirectoryではないため変更しません。"
        case .english: return "The Recovery location is not a directory, so nothing was changed."
        }
    }

    public static func recoveryOutsideStore(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "Recovery保管先が専用storeの外を指しています。"
        case .english: return "The Recovery location points outside the dedicated store."
        }
    }

    public static func setupResourcesMissing(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "自動セットアップ用ファイルがアプリ内にありません。"
        case .english: return "Automatic-setup files are missing from the app."
        }
    }

    public static func setupFileNotExecutable(_ name: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "セットアップ用ファイルを実行できません: \(name)"
        case .english: return "Cannot execute the setup file: \(name)"
        }
    }

    public static func setupFailed(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "自動セットアップに失敗しました。"
        case .english: return "Automatic setup failed."
        }
    }

    public static func diagnosticLogPath(_ path: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "診断ログ: \(path)"
        case .english: return "Diagnostic log: \(path)"
        }
    }

    // MARK: - YMM4ArchiveInstaller

    public static func catalogUnsupportedFormat(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4互換カタログの形式が対応外です。"
        case .english: return "The YMM4 compatibility catalog uses an unsupported format."
        }
    }

    public static func catalogInvalidEntries(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4互換カタログに無効または重複した項目があります。"
        case .english: return "The YMM4 compatibility catalog has invalid or duplicate entries."
        }
    }

    public static func catalogMissingMaintenancePolicy(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4互換カタログschema 2にeditionまたは保守更新ポリシーがありません。"
        case .english: return "The schema-2 YMM4 compatibility catalog has no edition or maintenance-update policy."
        }
    }

    public static func maintenancePolicyInvalid(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4保守更新ポリシーに無効または重複した項目があります。"
        case .english: return "The YMM4 maintenance-update policy has invalid or duplicate entries."
        }
    }

    public static func archiveNotOfficialZIP(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "公式YMM4のZIPファイルを選択してください。"
        case .english: return "Choose the official YMM4 ZIP file."
        }
    }

    public static func archiveExceedsSizeLimit(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 ZIPのサイズが安全上の上限を超えています。"
        case .english: return "The YMM4 ZIP exceeds the safety size limit."
        }
    }

    public static func noPreviousYMM4(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "戻せる以前のYMM4はありません。"
        case .english: return "There is no previous YMM4 to roll back to."
        }
    }

    public static func previousYMM4FailsCatalog(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "以前のYMM4は現在のカタログとhash検証に合格しないため切り戻しません。"
        case .english: return "The previous YMM4 fails the current catalog hash check and will not be restored."
        }
    }

    public static func rolledBackExecutableUnverifiable(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "切り戻したYMM4実行ファイルを確認できません。"
        case .english: return "The rolled-back YMM4 executable could not be verified."
        }
    }

    public static func archiveUnverified(_ archiveHash: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "このYMM4 ZIPは未検証です。更新後のZIPは、互換性テストとカタログ更新が完了するまで導入しません。SHA-256: \(archiveHash)"
        case .english: return "This YMM4 ZIP is unverified. An updated ZIP is not installed until compatibility testing and the catalog update are complete. SHA-256: \(archiveHash)"
        }
    }

    public static func archiveLaunchForbidden(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "このYMM4 ZIPはカタログ上で起動許可されていません。"
        case .english: return "The catalog does not permit launching this YMM4 ZIP."
        }
    }

    public static func maintenanceReceiptMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "公式YMM4保守更新候補の検証情報が一致しません。"
        case .english: return "The official YMM4 maintenance-candidate verification data does not match."
        }
    }

    public static func maintenanceCompletionFailed(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4保守更新候補の完了検査に失敗しました。"
        case .english: return "The YMM4 maintenance candidate failed its completion check."
        }
    }

    public static func ymm4ChannelOutsideStore(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "既存のYMM4 current channelが専用storeの外を指しています。"
        case .english: return "The existing YMM4 current channel points outside the dedicated store."
        }
    }

    public static func ymm4RecoveryNotDirectory(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 Recovery保管先がdirectoryではないため変更しません。"
        case .english: return "The YMM4 Recovery location is not a directory, so nothing was changed."
        }
    }

    public static func ymm4RecoveryOutsideStore(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 Recovery保管先が専用storeの外を指しています。"
        case .english: return "The YMM4 Recovery location points outside the dedicated store."
        }
    }

    public static func maintenanceBoundaryMismatch(_ path: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4保守更新候補のランタイム境界が検証済み系列と一致しません: \(path)"
        case .english: return "The YMM4 maintenance candidate runtime boundary does not match the verified train: \(path)"
        }
    }

    public static func distributionFileMissing(_ name: String, language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4配布物の必須ファイルがありません: \(name)"
        case .english: return "The YMM4 distribution is missing a required file: \(name)"
        }
    }

    public static func candidateNotValidPE(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4保守更新候補の実行ファイルは有効なWindows PEではありません。"
        case .english: return "The YMM4 maintenance-candidate executable is not a valid Windows PE file."
        }
    }

    public static func candidateNotAMD64GUI(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4保守更新候補はAMD64 Windows GUI実行ファイルではありません。"
        case .english: return "The YMM4 maintenance candidate is not an AMD64 Windows GUI executable."
        }
    }

    public static func userDataLinkElsewhere(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 user-data linkが別の場所を指しているため変更しません。"
        case .english: return "The YMM4 user-data link points elsewhere, so nothing was changed."
        }
    }

    public static func userDataDuplicated(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 user-dataがversion領域と共有領域の両方にあるため、自動統合せず停止しました。"
        case .english: return "YMM4 user data exists in both the version area and the shared area, so automatic merge was stopped."
        }
    }

    public static func userPathNotDirectory(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4のuser pathがdirectoryではないため変更しません。"
        case .english: return "The YMM4 user path is not a directory, so nothing was changed."
        }
    }

    public static func extractedExecutableHashFailed(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "展開後のYMM4実行ファイルがhash検証に失敗しました。"
        case .english: return "The extracted YMM4 executable failed hash verification."
        }
    }

    public static func archiveExtractionUninspectable(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 ZIPの展開結果を検査できません。"
        case .english: return "The YMM4 ZIP extraction result could not be inspected."
        }
    }

    public static func archiveFileCountExceeded(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 ZIPのファイル数が安全上の上限を超えています。"
        case .english: return "The YMM4 ZIP exceeds the safe file-count limit."
        }
    }

    public static func archiveForbiddenFileType(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 ZIPに許可されないファイル種別が含まれています。"
        case .english: return "The YMM4 ZIP contains a disallowed file type."
        }
    }

    public static func archiveStructureInvalid(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 ZIPの構造が不正または安全上の制限を超えています。"
        case .english: return "The YMM4 ZIP structure is invalid or exceeds the safety limits."
        }
    }

    public static func archiveExtractionFailed(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 ZIPの展開に失敗しました。"
        case .english: return "YMM4 ZIP extraction failed."
        }
    }

    public static func archiveExpandedSizeExceeded(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4 ZIPの展開後サイズが安全上の上限を超えています。"
        case .english: return "The expanded YMM4 ZIP exceeds the safe size limit."
        }
    }

    // MARK: - YMM4OfficialReleaseVerifier

    public static func officialReleaseUnverifiable(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4公式Release情報を安全に確認できませんでした。既知の検証済みZIPを使用してください。"
        case .english: return "The official YMM4 release information could not be verified safely. Use a known verified ZIP."
        }
    }

    public static func archiveNotStableAsset(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "選択したZIPをYMM4公式Releaseの安定版assetとして確認できませんでした。"
        case .english: return "The selected ZIP could not be confirmed as a stable asset of the official YMM4 release."
        }
    }

    public static func officialDigestMalformed(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "YMM4公式ReleaseのSHA-256情報が不正です。"
        case .english: return "The official YMM4 release SHA-256 information is malformed."
        }
    }

    public static func archiveSizeMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "選択したZIPのサイズがYMM4公式Release情報と一致しません。"
        case .english: return "The selected ZIP size does not match the official YMM4 release information."
        }
    }

    public static func archiveDigestMismatch(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "選択したZIPのSHA-256がYMM4公式Release情報と一致しません。"
        case .english: return "The selected ZIP SHA-256 does not match the official YMM4 release information."
        }
    }

    public static func archiveFileNameChanged(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "公式のYMM4 ZIPファイル名（通常版またはLite）を変更せず選択してください。"
        case .english: return "Choose the official YMM4 ZIP file name (Standard or Lite) unchanged."
        }
    }

    // MARK: - Arm64WineFEXBackend (research, disabled)

    public static func researchBackendDisabled(language: CoreLanguage = .current) -> String {
        switch language {
        case .japanese: return "研究用backendは無効です。配布可能なmacOS FEX buildと必要なentitlementの検証が完了するまで使用できません。"
        case .english: return "Research backend is disabled until a distributable macOS FEX build and required entitlement are validated."
        }
    }
}
