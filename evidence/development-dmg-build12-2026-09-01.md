# Development DMG build 12 — 2026-09-01

## Scope

Build 12 lets the automatic installer populate developer-selected folders. When
"個別セットアップ・開発者向け詳細設定" has both the 互換ランタイム and 専用prefix
folders set, "互換環境を一括インストール" now roots the same versioned
`versions/<profile>` + atomic `current` layout at those folders and completes
runtime, prefix, YMM4 copy, M: mapping, validation, and settings persistence
there. Previously the button ignored the selected folders and always installed
under `~/Library/Application Support/YMM4M`.

- `RuntimeSetupPaths.custom(runtimeStore:prefixStore:)` builds the same layout as
  `defaults()` at arbitrary roots. All existing recovery, atomic activation, and
  runtime/prefix binding checks apply unchanged.
- `resolvedSetupPaths()` in the app returns the custom layout only when both
  folders are set, distinct, not the home directory or filesystem root, and no
  `YMM4M_RUNTIME` / `YMM4M_WINE` / `YMM4M_PREFIX` environment override is present.
  Otherwise the standard Application Support location is used. Invalid selections
  stop before setup starts with a stated reason.
- Developer-settings picker and step copy updated to say an empty target folder
  is accepted.

## Artifact

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-09-01/YMM4M-0.1.0-build12-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-09-01/YMM4M-0.1.0-build12-development-adhoc.dmg`
- DMG size: 738,724 bytes
- DMG SHA-256: `2891f917ded6710909ced501c4c0f88f6f8a5bc5ecf1f3952a980189a18ded4c`
- Signed host binary SHA-256: `a875c835e37dc976734e7d5a17fc932107a8f8cb487b45fe65ef2bb01812ce9a`
- Bundle: version `0.1.0`, build `12`, ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`
- Notarization/stapling: not performed

## Verification

- Swift release build and `YMM4MContractTests` (adds
  `testAutomaticSetupPopulatesDeveloperSelectedStoreRoots`): pass
- Python tests: 21/21; `validate-compatibility.py` (20 features) and
  `validate-runtime-lock.py`: pass
- Every `tools/*.sh` `sh -n` and `git diff --check`: pass
- DMG `hdiutil verify` and read-only mount: pass
- Strict `codesign --verify --deep --strict` on the mounted app: valid, satisfies
  its Designated Requirement
- ARM64-only host binary: pass
- `READ-ME-FIRST.txt` identifies build 12: pass
- Bundled `RuntimeBootstrap` catalog (5 scripts + lock + 4 patches) byte-matches
  the tracked sources; bundle carries only the host binary and those text files —
  no `.exe`/`.dll`/`.dylib`/font/Wine/DXMT/CrossOver payloads
- Bundled and source YMM4 release catalog SHA-256 both:
  `0ca8d2775404576b91185813a8ddd993f2dad9dbdd2a48ae23cc48edca2e75a2`
- GUI launch and normal quit: pass

The DMG contains no YMM4, Wine/DXMT runtime binaries, fonts, CrossOver, or
Microsoft runtime payloads. It remains ad-hoc, non-notarized, and
development-only. Developer ID signing and notarization are unavailable in this
environment, so this is not a release-ready distribution. A full clean-machine
bootstrap into a custom folder was not run here; the custom-store layout,
recovery, and atomic activation are covered by the new contract test.
