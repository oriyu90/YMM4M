# Status

## Implemented

- SwiftPM build graph for ARM64 host, core, protocol, and separate native encoder
- `RuntimeBackend` boundary with safe Rosetta/Wine probing and disabled research backend
- WPF software profile as the default configuration
- M: media-root path containment
- Versioned, length-prefixed localhost bridge protocol with session-token authentication
- Native raw video/audio receiver for protocol and format discovery
- Dependency-free YMM4 ZIP, PE architecture, and .NET deployment inspection
- Hash-verified, traversal-safe installation of a user-supplied YMM4 archive
- Redacted environment evidence and diagnostic text
- Compatibility registry, legal boundaries, third-party notice structure, and tests
- Wine 11.0, Wine 11.15, and CrossOver 26.3 runtime baselines
- CrossOver WineD3D, DXMT, and D3DMetal comparison with application-owned logs
- Isolated Noto Sans CJK JP font fallback for Wine prefixes
- Full Xcode 26.6 toolchain selected at `/Applications/Xcode.app/Contents/Developer`
- Source-built DXMT and Wine Direct2D compatibility patches with standalone public-API reproducers
- Sanitized Wine launch environment that excludes host credentials, agent sockets, and dynamic-loader injection variables
- YMM4 public-UI image/audio import, isolated project save/reopen, and preview playback probes
- Wine DirectWrite locale-fallback correction with a documented `MapCharacters` reproducer and regression assertion
- DXMT compute-pipeline device initialization-order correction with a documented D3D11 dispatch/readback reproducer
- Public-UI H.264/AAC video import, normal save/close/reopen, FFmpeg software-frame upload, and matched-setting export evidence
- Public-UI JPEG, MP3, and animated-GIF import, persistence, and matched-setting export evidence; one non-reproduced DXMT pure-virtual observation retained without a speculative patch
- CrossOver-free Wine 11.0 + source-built DXMT candidate with a small macOS-driver Metal-view bridge for top-level and child HWND swap chains
- Reproducible clean-runtime staging script that rejects CrossOver-derived inputs and reproduces the verified candidate hashes without overwriting an existing destination
- Host-side clean-runtime discovery and pinned SHA-256 manifest validation; only the verified Wine 11.0/DXMT file set receives the required library paths and DLL overrides
- Wine-managed client-surface Metal bridge that keeps DXMT's child-HWND preview confined to the preview pane while preserving WPF software rendering
- Version-scoped native macOS Japanese-input overlay and private temporary-file/Unicode-event bridge for YMM4 Lite 4.55.1.1; it never presses Add automatically
- Allow-listed developer launch environment matching the product backend; arbitrary host credentials and loader settings are no longer inherited by `tools/run-ymm4.sh`
- ARM64 development app-bundle builder plus Finder `.ymmp` intake, contained `M:` media mapping, non-overwrite protection, and SHA-256 YMM4 compatibility gating
- Atomic YMM4 version selection/rollback primitive that preserves installed versions and refuses non-symlink channels or escaping version links

## Verified baseline

- YMM4 v4.55.1.1 Lite is AMD64 and self-contained on .NET 10.0.10.
- The YMM4 CLI loads successfully on Wine 11.0, Wine 11.15, and CrossOver 26.3.
- The unpatched WineD3D and D3DMetal baselines stop at `ID2D1Device6.CreateDeviceContext`; unpatched DXMT stops at `IDXGISwapChain.GetBuffer(IDXGISurface2)`.
- The isolated, source-patched DXMT/Wine development runtime passes the eight-fixture D3D11, DXGI, Direct2D, and DirectWrite regression suite.
- YMM4 v4.55.1.1 Lite opens a project, advances preview playback, and visibly renders an imported 640x360 PNG.
- YMM4's own log confirms the imported 48 kHz WAV reaches FFmpeg open, resample, seek, and first read.
- YMM4 FFmpeg software export produces a 5.000-second H.264/AAC MP4 at 1920x1080/60 fps with 48 kHz stereo audio; the extracted 2-second frame places the 640x360 PNG exactly at canvas center and the audio stream is non-silent.
- Project save and reopen preserve TextItem, ImageItem, and AudioItem records in the isolated test project.
- Fifteen consecutive Direct2D create/render/destroy cycles pass with the candidate patch set.
- Wine's system font fallback now maps Japanese from an Arial base to Noto Sans CJK JP with complete glyph coverage in isolated/shared factories and empty/`ja-JP` locales.
- YMM4 Lite preview and a 10.000-second 1280x720/30 fps H.264/AAC export visibly preserve `日本語テストABC123` without missing-glyph boxes.
- One hundred D3D11 device/compute/dispatch/readback cycles pass after correcting `ArgumentEncodingContext` member initialization order; the final build contains neither the diagnostic receiver fallback nor temporary tracing.
- An isolated three-second H.264/AAC video survives public-UI import, normal save/close/reopen, and preview decoding; matching the project and FFmpeg-writer dimensions produces a valid 1920x1080/60 fps H.264/AAC round trip. The earlier readback exception is reproduced only when those dimensions differ, before Direct2D bitmap readback is entered.
- Isolated JPEG and MP3 items survive public-UI import and normal save/close/reopen. An animated GIF imports through YMM4's video path, persists as a `VideoItem`, and produces distinct frames in valid five-second H.264/AAC exports. Three additional matched-setting exports are byte-identical; the prior DXMT pure-virtual/illegal-instruction stop has not recurred in four controlled runs.
- A clean candidate assembled from Wine Stable 11.0 resources plus only source-built patched Wine/DXMT files passes the eight-fixture suite, including 100 compute iterations and child-HWND swap-chain creation. YMM4 Lite CLI help exits successfully, and the GUI reaches the titled main window and closes normally without using CrossOver files.
- The reproducibly staged clean candidate completes YMM4 Lite's own FFmpeg export of the isolated Japanese project: H.264 1280x720/30 fps plus non-silent AAC 48 kHz stereo, 3.000 seconds. The extracted frame visibly preserves `日本語テストABC123`, and the project and writer settings hashes remain unchanged.
- With `DisableHWAcceleration=1` present in the dedicated prefix, the clean managed-surface candidate visibly renders YMM4's menus, item pane, preview pane, timeline, and dialogue field; its eight-fixture suite still passes, including 100 compute iterations and top-level/child HWND swap chains.
- The macOS Japanese Romaji IME confirms `日本語` in Wine Notepad and in a standalone WPF TextBox built with .NET 10.0.10. The fixture's `PresentationCore.dll` and `PresentationFramework.dll` hashes exactly match YMM4 Lite's corresponding self-contained runtime files. YMM4's dialogue field still accepts the ASCII control but not the confirmed Japanese composition, narrowing the failure to YMM4's input-control path rather than macdrv or WPF generally.
- A correctly focused Wine boundary trace shows the marked-text progression and completed `日本語` reaching YMM4's Wine content view while the dialogue field remains unchanged, so no speculative Wine patch was added. The native-host committed-text workaround then transferred `日本語` into that field under the clean candidate and exited zero without pressing Add or modifying a project.
- The native-overlay `日本語` string was added through YMM4's public button, visibly rendered, and saved in a new isolated project whose public JSON retains the exact string. Follow-up isolation showed that both former failure controls select AquesTalk1, which vanilla YMM4 Lite does not include. Empty, Text-only, and Text/Image/Audio projects open; the current candidate reopens the saved Japanese Text/Image/Audio control 3/3 times in fresh Wine-server sessions. PROJECT001 is restored to pass for the tested Lite-supported item set.
- The new allow-listed `tools/run-runtime-fixtures.sh` rebuilt and reran the complete current-runtime suite: all eight fixtures pass, including 100/100 D3D11 compute iterations, top-level/child-HWND swap chains, Direct2D contracts and complete Japanese DirectWrite fallback.
- The isolated JPEG/MP3/animated-GIF project completed three matched 1920x1080/60 exports on the current candidate. The outputs are byte-identical and contain distinct decoded frames at 0.5, 1.5 and 2.5 seconds. The old one-time DXMT native stop has now failed to reproduce in four controlled runs and remains historical rather than a current blocker.
- The isolated H.264/AAC project visibly renders frame 0 and the officially documented Ctrl-middle-click action changes the in-memory timeline, confirmed by YMM4's unsaved-project dialog on normal close. The original project remains byte-identical. Persisted split/reopen is still open because the current custom WPF Save As picker renders as a blank top-level surface and exposes no focused edit control.
- A reproducible unsigned ARM64 development bundle contains the expected `.ymmp`/`.ymme` document declarations. LaunchServices delivered an isolated `.ymmp`; the host mapped it to `M:\core-japanese-noto.ymmp`, YMM4's public settings recorded that path, the main window appeared, and normal close preserved the source hash. Contract tests cover containment, idempotent `M:` creation, conflict preservation, and executable hash classification. `.ymme` installation behavior is not guessed.

## Blocking gates

- Direct Japanese IME composition still fails in YMM4's dialogue field even though the same Wine/prefix passes standard Win32 and runtime-matched WPF controls. The native ARM64 overlay passes the IME001 hiragana, katakana, kanji-candidate, Space/Enter, phrase, cursor, Backspace, and shortcut-suppression matrix, and explicitly transfers committed text to the tested YMM4 Lite 4.55.1.1 field; this remains a version-scoped workaround. Video thumbnail/split editing, audible playback, effects, remaining media-format cases, and Windows-reference export comparison still need repeatable Tier A verification.
- AquesTalk1 VoiceItem projects reach an enabled owner-modal window titled `AquesTalk1`, while the main window is disabled. Its WPF surface is black and exposes no MSAA child controls under the current candidate. Official YMM4 documentation confirms that vanilla Lite omits AquesTalk and provides it only as an optional plug-in; it was not installed because component/license decisions are deferred to the final release audit. This is tracked separately from PROJECT001 as unsupported on the tested vanilla Lite component set.
- The clean Wine 11.0 + source-built DXMT candidate is not yet a shipping runtime: full component/source inventory, licensing decision, packaging, and release validation remain open. Its local staging script reproduced identical verified binaries and passed the eight-fixture suite; the older CrossOver-derived staging root remains strictly non-distributable.
- Clean-candidate GUI startup reproducibly emits a native-crash banner during `YukkuriMovieMaker.Win32Service.exe` Mono initialization. A process trace identifies that child process; the traced YMM4 main process still reaches the titled window and closes with status zero. YMM4's public log separately records repeated `System.Management.WmiNetUtilsHelper` initialization failures. The service role and feature impact remain unassigned, and no speculative workaround is applied.
- No Windows reference renders or hardware/OS test matrix are available.
- A Developer ID identity and Apple restricted cross-architecture entitlement have not been supplied.
- Signing, notarization, official YMM4 updater behavior, crash recovery, and the release-time license audit remain unexecuted. Versioned local ZIP install and interrupted-channel self-repair are implemented; rollback selection UI is not.
- Development packaging is implemented and audited. It remains runtime-free, ad-hoc, non-notarized, and not release-ready.

## Full-audit update (2026-08-29)

- Swift warning-as-error, AddressSanitizer, and ThreadSanitizer builds and contract tests pass. The C# warning gate is blocked because the `dotnet` SDK is not installed.
- The runtime fixture runner now builds all eight Win32 fixtures with `-Wall -Wextra -Werror`; all eight pass and compute remains 100/100. The text-input helper also rebuilds warning-clean with its pinned reproducible hash.
- A separate warning-clean D3D11 create/compute/dispatch/readback stress run passes 1,000/1,000. Direct2D remains evidenced at 15 cycles, so its required 1,000-cycle stress gate is still open.
- A Metal System Trace directly records 200 command-buffer submissions, 300 encoders, and 300 GPU intervals for the DXMT compute fixture, with zero command-buffer-error rows. This proves the low-level compute path uses the GPU, not the complete YMM4 rendering matrix.
- Tier A drag-and-drop (`DND001`) and clipboard (`CLIP001`) are now explicitly registered as `untested` instead of being absent from the machine-readable registry.
- Developer ID signing is unavailable by user confirmation. Release signing, notarization, stapling, Gatekeeper release assessment, and a release-ready DMG are not possible in this environment.
- A runtime-free ARM64 development app was built at `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-29/YMM4M-pre-alpha-development.app`. It has only a linker-generated ad-hoc signature and is not a release artifact.
- With explicit user authorization, that app was packaged as the development-only `YMM4M-0.1.0-prealpha-development-adhoc.dmg`. Its internal checksum and read-only mount inspection pass, but Gatekeeper rejects it as expected because it has no Developer ID signature or notarization. The unpublished local release draft is `release-drafts/v0.1.0-prealpha-development.md`; no GitHub draft exists because the repository has no HEAD commit or remote.
- Full results and trace inventory hashes are in `evidence/full-audit-gates-2026-08-29.md`. The final release-license audit document remains unopened because the pre-release gates are not complete.

## Guided setup and development build 2 (2026-08-30)

- The native host now exposes the actual launch requirements as a numbered setup flow: validated Wine/DXMT runtime, dedicated WPF-profiled prefix, official YMM4 executable, and optional project/media root.
- Users can check settings, launch YMM4 without a project, or choose and open a contained `.ymmp` directly from the app. UI-selected prefixes use the same sanitized backend and do not bypass runtime hashes, safe-prefix checks, WPF profile checks, executable classification, or M: containment.
- `docs/MAC_SETUP.md` documents how to open the ad-hoc app on Mac without globally disabling Gatekeeper, which paths to select on the current development machine, how to launch YMM4/open a project, and the Japanese input workaround.
- Development build 2 is `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-prealpha2-development-adhoc.dmg`, SHA-256 `f12f7ace403d8a95834dfb4aa0e12e71c2b68d0bb142b7e2370b9c656b199746`. It remains ad-hoc, non-notarized, Gatekeeper-rejected, and not release-ready.
- UI and DMG evidence is in `evidence/setup-ui-development-dmg-2026-08-30.md`. The local release draft is updated to pre-alpha 2; no hosted draft exists because Git still has no HEAD or remote.

## Automatic runtime/prefix bootstrap (2026-08-30)

- The setup action now fetches only lock-pinned HTTPS inputs, verifies every archive SHA-256 and member path, applies the recorded Wine/DXMT patches, builds, clean-stages, and creates a dedicated WPF-profiled prefix after explicit confirmation.
- Wine now uses FreeType with pinned 2.14.3 source headers. The pinned Noto TTC is converted to a prefix-local Japanese OTF, so the result does not depend on a user-installed host font.
- The missing Direct2D Premultiply implementation was recovered into the recorded compatibility patch after a fresh-build fixture exposed it. Prefix service shutdown no longer waits indefinitely.
- Wine PE source/build paths are normalized. Two independent build roots produced byte-identical `d2d1.dll` and `dwrite.dll`, allowing strict whole-file runtime hashes to remain enabled.
- A new runtime and new prefix passed all eight fixtures, including compute 100/100, Premultiply/3D transform, Japanese output (`wrote=1`), and shared/isolated DirectWrite fallback. Evidence is in `evidence/automatic-runtime-prefix-bootstrap-2026-08-30.md`.
- This validates local bootstrap only. Generated runtime redistribution and the remaining Tier A/release gates are still open.
- Development build 3 is `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-prealpha3-development-adhoc.dmg`, SHA-256 `33248b15eae13b1d7a87b4fbeb90145e6d77461963ebb86d2bfd9996b7adabfe`. The completed bundle has a valid explicit ad-hoc signature; the DMG contains no YMM4/Wine/DXMT binaries or font payloads and remains Gatekeeper-rejected/non-notarized by design.

## v0.1.0 update-resilience and ZIP setup (2026-08-30)

- Runtime and prefix are created in version-specific directories and activated through validated `current` channels. Prefix binding records the runtime profile and prefix schema; mismatches fail closed.
- The UI accepts the user-supplied official YMM4 ZIP, validates archive/exe SHA-256 and archive structure, installs under `YMM4/versions`, and exposes `YMM4をMacで開く`.
- `compatibility/ymm4-releases.json` binds tested YMM4 Lite 4.55.1.1 to the tested runtime profile. Unknown updates are refused until regression evidence and the catalog are updated.
- Swift warnings-as-errors/contracts, the real official ZIP contract, Python 16/16, validators, and all eight runtime fixtures with compute 100/100 pass.
- v0.1.0 development build 4 DMG is `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-development-adhoc.dmg`, 607,858 bytes, SHA-256 `9bc7987d87f967fa967382f110a1dfe0064a2a634d1130a03ee4e2e57df3e2de`. Read-only mount, ad-hoc signature, ARM64, bundled catalog, forbidden-payload scan, GUI launch and clean quit pass.
- Design/limitations: `docs/UPDATE_COMPATIBILITY_AUDIT.md`. Evidence: `evidence/update-resilience-zip-launch-v0.1.0-2026-08-30.md`.

The project remains Discovery / pre-alpha and must not be tagged v1.0 or `milestone-core-workflow`.

The 2026-08-29 host/tooling gate passes Swift build and contracts, all 14 Python tests, runtime-lock and compatibility validation, shell/plist checks, credential-pattern scanning, process cleanup, and ABC input-source restoration. The Git index is empty, so all repository files remain untracked and no commit was created.
