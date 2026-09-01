# Changelog

## 0.1.0 development build 12 (draft) — 2026-09-01

### Fixed

- "個別セットアップ・開発者向け詳細設定" で互換ランタイムと専用prefixに
  フォルダ（空でも可）を指定した状態で「互換環境を一括インストール」を押すと、
  その指定フォルダを版管理ストアの起点として `versions/<profile>` と `current`
  を作成し、標準の場所と同じ手順（回復退避・atomic切替・binding検証）で
  セットアップを完了できるようにした。以前は選択パスを無視して常に
  `~/Library/Application Support/YMM4M` 配下へインストールしていた。
- ランタイムとprefixのフォルダが同一、ホーム、filesystem root などの場合は
  セットアップ開始前に理由を表示して停止する。環境変数
  `YMM4M_RUNTIME` / `YMM4M_WINE` / `YMM4M_PREFIX` 指定時は従来どおりそれらを優先する。

## 0.1.0 development build 11 (draft) — 2026-09-01

### Fixed

- The one-pass installer no longer requires a hand-provisioned x86_64 LLVM 15
  toolchain that had no documented acquisition path. When
  `YMM4M_LLVM15_ROOT` is absent, the pinned upstream LLVM 15.0.7 x86_64 release
  is downloaded and SHA-256 verified like every other bootstrap input, then used
  only as a DXMT build tool (never staged into or shipped with the runtime).
- The bootstrap now preflights Rosetta 2 before downloading or building, instead
  of failing at the `[stage]` step after a long compile on a Mac without it. The
  failure message points at `softwareupdate --install-rosetta`.
- Missing Homebrew build tools and unverified MinGW GCC versions now print the
  exact install / `brew pin` commands, and the MinGW message explains that other
  GCC majors are rejected by the app's runtime hash validation.
- `docs/MAC_SETUP.md` now lists the concrete `softwareupdate` / `brew install`
  prerequisites and the corrected (~10 GB) free-space requirement.

## 0.1.0 development build 10 (draft) — 2026-08-31

### Added

- A single guided installer now asks only for the official Standard/Lite YMM4
  ZIP and the media/project folder, then prepares the runtime, prefix, managed
  YMM4 copy, M: mapping, validation, and persisted settings as one operation.
- Explicit recovery contracts cover an empty install, interrupted runtime and
  prefix destinations, invalid managed channels, partial YMM4 extraction, and
  an idempotent second run.

### Fixed

- Incomplete managed destinations are retained under each store's `Recovery`
  directory and rebuilt instead of making every retry fail with an existing-path
  error. Valid current and older versions are preserved.
- Fresh Wine prefix initialization no longer leaves an orphaned `winedbg`
  process holding the setup log pipe open. Prefix-scoped Wine processes are
  always shut down on success or failure, and completion markers remain required.
- A valid relative YMM4 `current` symlink is no longer mistaken for an external
  link during a repeated installation.
- Setup values are saved only after runtime, prefix, YMM4, and media mapping all
  pass validation, so an interrupted run cannot appear complete on next launch.

## 0.1.0 development build 9 (draft) — 2026-08-31

### Fixed

- Automatic setup now streams download, preparation, build, staging, and prefix
  phases to the app and writes `Logs/automatic-setup.log` for failures.
- Wine source/build workspaces moved from the whitespace-containing Application
  Support path to the disposable macOS cache tree, fixing false MinGW
  `x86_64 PE cross-compiler not found` failures.
- Pinned DXMT submodule archives now replace the empty GitHub archive placeholder
  directories instead of being nested one level too deep.
- Network downloads now fail with bounded connect/low-speed timeouts and retry
  transient errors.
- The audited legacy runtime hashes remain accepted alongside the reproduced
  GCC 16.2 variant; both variants still require complete matching hash sets and
  the corresponding `winemac.so` loadable-image hash.

### Changed

- The setup counter now says that paths are specified but not yet validated,
  and explains that the runtime destination stays empty until final validation.
- Runtime generation advances to `wine-11.0-dxmt-e55ad281-patchset5`.

## 0.1.0 development build 8 (draft) — 2026-08-30

- Rebuilt the audited development artifact from the final reviewed source and
  documentation state. Functional changes are the build 6/7 entries below.
- Ad-hoc signing, non-notarized status, and all documented limitations remain.

## 0.1.0 development build 7 (draft) — 2026-08-30

### Fixed

- Reused maintenance candidates now revalidate their PE type, family ID,
  runtime profile, archive receipt fields, release-directory identity, and
  shared user-data link before activation.
- Exact known-version switches now preserve the displaced active version in
  `previous`, matching provisional update behavior.
- Rollback validates the previous executable and managed-store containment
  before changing `current`; a failed validation leaves the active version intact.

### Known limitations

- All build 6 maintenance-candidate limitations below still apply. This is an
  ad-hoc, non-notarized development artifact.

## 0.1.0 development build 6 (draft) — 2026-08-30

### Added

- Provisional intake for future stable YMM4 4.55.1.x Standard/Lite ZIPs after
  official GitHub asset name, size, SHA-256, safe archive, AMD64 GUI PE, and
  fixed .NET/WPF runtime-boundary verification.
- One-click rollback to the previous managed YMM4 version.
- Standard/Lite-separated shared YMM4 user-data storage so managed version
  switches retain the same edition's settings, logs, and backups.

### Fixed

- Small upstream maintenance candidates no longer require an exact executable
  hash merely to be staged and tried, while still remaining distinct from
  `knownCompatible` releases.
- Versioned YMM4 installs no longer hide the previous version's `user` root.
  Legacy Lite data is copied once and retained; conflicting roots stop safely.

### Known limitations

- Structural and official-source checks do not prove UI, IME, editing, plug-in,
  preview, or export behavior. Exact hashes are promoted to known-compatible
  only after the normal runtime workflow evidence is recorded.
- Only future stable 4.55.1.x versions with the unchanged recorded runtime
  boundary are eligible. Other release trains and runtime changes fail closed.
- Rollback is manual and retains one previous active version; automatic
  crash-loop detection is not implemented.
- The DMG remains ad-hoc and non-notarized because Developer ID is unavailable.

## 0.1.0 development build 5 (draft) — 2026-08-30

### Added

- Hash-pinned official YMM4 4.55.1.1 standard-edition ZIP installation, CLI,
  and GUI-startup support alongside Lite.
- Restart contracts for all five persisted setup values and safe migration of
  legacy managed paths to existing `current` channels.

### Fixed

- Setup copy now tells users to keep the official ZIP in a location that will
  not be automatically deleted and confirms that YMM4M does not move or delete it.
- App updates no longer leave old managed runtime, prefix, or YMM4 version paths
  selected when a valid current channel exists. Custom paths remain untouched.

### Known limitations

- Detailed editing, media, export, and IME regression coverage remains primarily
  on Lite; standard-edition support currently claims installation, CLI, first-run,
  main-window startup, and restart persistence only.
- The DMG remains ad-hoc and non-notarized because Developer ID is unavailable.

## 0.1.0 development build 4 (draft) — 2026-08-30

### Added

- In-app official YMM4 ZIP selection, strict archive/executable hash validation,
  versioned installation, and a clear `YMM4をMacで開く` launch action.
- Machine-readable YMM4 release catalog with required runtime-profile binding.
- Versioned runtime and prefix stores with atomic active-channel switching.
- Runtime/prefix binding metadata, legacy-layout migration, and update-resilience
  design audit.

### Fixed

- Runtime and prefix updates no longer overwrite a single active destination.
- Managed YMM4 executables changed after installation are refused at launch.
- Unknown YMM4/runtime combinations fail closed instead of being guessed
  compatible.

### Known limitations

- The catalog and strict runtime hashes require a tested YMM4M update before a
  new upstream YMM4 or runtime is accepted.
- A signed remote catalog and rollback selection UI are not implemented.
- The DMG remains ad-hoc and non-notarized because Developer ID is unavailable.

## 0.1.0 pre-alpha development build 3 (draft) — 2026-08-30

### Added

- One-confirmation automatic bootstrap for pinned Wine, DXMT, build dependencies,
  clean runtime staging, and the dedicated WPF-profiled prefix.
- Pinned FreeType headers and prefix-local Noto Sans CJK JP setup.
- Download hash/path validation, build preflight, reproducible Wine PE paths,
  and phase-specific progress/error reporting.
- Runtime bootstrap design, architecture maintenance guide, and reproducible
  end-to-end evidence indexed from `COMMON_RULES.md`.

### Fixed

- Fresh prefixes no longer depend on a host-installed Japanese font.
- The recorded Wine patch now includes the tested Direct2D Premultiply effect.
- Prefix setup shuts down Wine services instead of waiting indefinitely.

### Known limitations

- This remains an ad-hoc, non-notarized development build because Developer ID
  signing is unavailable.
- The app builds the compatibility runtime locally; the DMG does not bundle
  YMM4, Wine/DXMT binaries, proprietary Microsoft files, fonts, or CrossOver.
- Toolchain prerequisites and the remaining Tier A/final-license gates remain
  documented in `STATUS.md`.

## 0.1.0 pre-alpha development build 2 (draft) — 2026-08-30

### Added

- Four-step macOS setup screen for the validated runtime, dedicated Wine
  prefix, official YMM4 executable, and optional project/media root.
- Explicit `Check settings`, `Launch YMM4`, and `Open project` actions.
- Runtime hash, Rosetta, WPF profile, safe-prefix, and YMM4-version feedback in
  the setup UI.
- UI-selected prefix support without requiring `YMM4M_PREFIX` in the launch
  environment.
- In-app explanation of the pre-alpha/ad-hoc limitations and the macOS launch
  workflow.
- `docs/MAC_SETUP.md`, also included in the development DMG.

### Changed

- The misleading ZIP-selection control, which did not install YMM4, has been
  removed from the main flow.
- Finder project opening and the project picker now share the same contained
  `M:` mapping and launch path.
- The main window enforces a readable minimum content size.

### Known limitations

- This is not a release-ready build. It has no Developer ID signature or
  notarization.
- The DMG does not bundle or automatically install YMM4, Wine, DXMT, CrossOver,
  Microsoft runtimes/fonts, or voice engines.
- See `STATUS.md` and `compatibility/features.yaml` for the remaining functional
  and stability gates.

## 0.1.0 pre-alpha development build 1 (local draft) — 2026-08-29

- First local ARM64 ad-hoc development app and DMG draft.
- Host sanitizer, runtime fixture, and low-level Metal trace audit recorded.
