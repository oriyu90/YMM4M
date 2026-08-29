# CrossOver-free Wine/DXMT Metal-view evidence (2026-08-26)

## Scope and provenance

This test replaces the earlier CrossOver-derived development staging root with a clean local candidate assembled from:

- Wine Stable 11.0 resources (`wine-11.0`, source base `db11d0fe6a169c457e23d007e20404643d067aa8`)
- DXMT source base `e55ad281c60be97f8815b5848e57cfd9f967d759`
- the tracked Wine and DXMT source patches
- Noto Sans CJK JP Regular extracted from the locally installed SIL OFL TTC with HarfBuzz

No CrossOver file was copied into this candidate. YMM4 Lite remained external and user-supplied.

## Reproducer before the fix

The clean candidate already passed the D3D11 compute and context-state fixtures. The documented `dxgi-surface2-reproducer.exe` stopped while creating its two-buffer flip-sequential swap chain:

```text
CreateSwapChain: unsupported swap effect 3 with backbuffer size 2
Failed to create metal view, it seems like your Wine has no exported symbols needed by DXMT.
```

DXMT's open-source Unix bridge searched for a `macdrv_functions` table and otherwise searched for individual macOS-driver symbols. Upstream Wine 11.0 built those implementation symbols with hidden visibility and did not export the table. Source comparison also showed that DXMT's fallback accesses a private `macdrv_win_data` layout that does not match Wine 11.0. No proprietary implementation was decompiled or used to design the change.

## Fix

`patches/0004-wine-macdrv-metal-view-bridge.patch` exports two small Wine macOS-driver functions. The final create function uses Wine's managed macOS client-surface lifecycle, already exercised by Wine's OpenGL/Vulkan drivers, and creates a Metal view for that surface. The opaque handle releases both through Wine's existing lifetime functions. A first revision that created an unmanaged content view passed the standalone fixture but covered YMM4's client area; the 2026-08-27 actual-UI regression and correction are recorded separately in `wpf-ime-managed-surface-2026-08-27.md`.

`patches/0001-dxmt-yymm4-compat.patch` makes DXMT prefer that layout-independent bridge. Its former function-table path remains as a fallback, with an added null check before dereferencing returned window data.

The final `winemac.so` exports:

```text
_macdrv_create_metal_view
_macdrv_release_metal_view
```

## Standalone validation

All eight fixtures exited with status zero in the CrossOver-free prefix:

- D3D11 compute pipeline: 100 device/dispatch/readback iterations
- D3D11 context state
- DXGI swap chain and `IDXGISurface2` for both top-level and visible child HWNDs
- Direct2D device6
- Direct2D null effect input
- Direct2D 3D transform and command-list contracts
- Direct2D Japanese text bitmap output
- DirectWrite Japanese fallback in all four factory/locale combinations

`tools/stage-clean-wine-dxmt-runtime.sh` then rebuilt a second candidate at a new path from the declared Wine resources and Wine/DXMT build directories. The script rejects any input path containing `CrossOver`, refuses to overwrite an existing destination, reproduced identical hashes, and the second staged root passed the same eight fixtures.

The staging script now writes `ymm4m-runtime.json`. `RosettaWineBackend` requires that manifest, compares it with the candidate hashes pinned in the ARM64 host, re-hashes every declared file, and only then supplies the clean runtime's `WINEDLLPATH` and fixed DLL overrides. A contract test using the generated runtime completed successfully. Inherited `WINEDLLPATH`, CrossOver configuration, credentials, agent sockets, and dynamic-loader injection variables are not passed through.

Final local candidate hashes:

- `winemac.so`: `60978ff67066a2af56a2face8eec0bbfcf55f266067c52388b524fabd79ef037`
- `winemetal.so`: `62777419bdbec505e72d257279976e8bcd71bbf8a895239d729dcec9d56a3ebc`
- `d3d11.dll`: `477fbdb9adae141521351b012fa8f7d818a5a1ea292a6d59bada4aa1905aa62a`
- `dxgi.dll`: `3c0b3efbcab0079e892eee61680ec5863adcc17541fd54942daf94b41784c973`
- `d2d1.dll`: `fb93bcd8a87897913be26b5115f55269db7374638aef2b161998efbb13db003d`
- `dwrite.dll`: `edfbcfdb45f007174624e25696c2a2ef69c5fb2b92778f4831264aa30a16e923`
- extracted Noto OTF: `1e294fd7886e564bb4de40fe3e2221580268a8c7bb568ad557737f563083661d`

## YMM4 Lite validation

The user-supplied YMM4 Lite `--help` command exited with status zero. GUI startup then exposed the public top-level window:

```text
class=HwndWrapper[YukkuriMovieMaker;...]
title=ゆっくりMovieMaker v4.55.1.1 Lite
```

The main window remained available to the public Win32 window enumerator and closed normally through `WM_CLOSE`; the Wine process exited with status zero. On 2026-08-27, after confirming and applying the required WPF software profile, the corrected managed-surface build also visibly rendered the menus, item pane, preview pane, timeline, and dialogue field. This startup did not open or modify a user project.

A traced repeat startup showed the native-crash banner after YMM4 created `YukkuriMovieMaker.Win32Service.exe`; the child process thread was initializing Mono at the banner. In the same run the YMM4 main window was present and the main process closed with status zero. Separate YMM4 public logs repeatedly recorded `System.Management.WmiNetUtilsHelper` initialization failures and an Explorer tool cancellation-source disposal exception. The service's role and user-visible feature impact were not inferred, and no workaround was added.

## Clean-candidate YMM4 export

The reproducibly staged root encoded the existing isolated `core-japanese-noto.ymmp` project through YMM4 Lite's public `--encode` interface. The project and FFmpeg writer-setting hashes were identical before and after the run.

Output: `/Users/user/.ymm4m-dev/exports/upstream-clean-core-japanese-noto.mp4`

- SHA-256: `675957e51b00e773e6e73dc46c010bec5af178e7513f56c7b715be2f32b54f33`
- duration: 3.000 seconds
- video: H.264, 1280x720, 30 fps
- audio: AAC, 48 kHz stereo, mean `-30.1 dB`, max `-26.3 dB`
- extracted frame SHA-256: `279192cb6ceca2761748f4fe9f5b7dde6068f297b79aa3b6b5e81d217af79c87`

The tracked extracted frame `upstream-clean-core-japanese-noto-frame-2026-08-26.png` visibly preserves `日本語テストABC123` without missing-glyph boxes.

Local logs:

- `/Users/user/.ymm4m-dev/upstream-wine-dxmt-eight-fixture-passed.log`
- `/Users/user/.ymm4m-dev/upstream-wine-dxmt-repro-eight-fixture-passed.log`
- `/Users/user/.ymm4m-dev/upstream-wine-dxmt-final-top-child-suite.log`
- `/Users/user/.ymm4m-dev/stage-clean-runtime-repro.log`
- `/Users/user/.ymm4m-dev/stage-clean-runtime-manifest.log`
- `/Users/user/.ymm4m-dev/upstream-wine-dxmt-ymm4-help.stdout.log`
- `/Users/user/.ymm4m-dev/upstream-wine-dxmt-ymm4-help.stderr.log`
- `/Users/user/.ymm4m-dev/upstream-ymm4-gui-window-dump.txt`
- `/Users/user/.ymm4m-dev/upstream-dxgi-metal-view-fixed.log`
- `/Users/user/.ymm4m-dev/upstream-dxgi-top-child-final.stdout.log`
- `/Users/user/.ymm4m-dev/upstream-ymm4-process-trace.log`
- `/Users/user/.ymm4m-dev/upstream-clean-export-input-hashes.before`
- `/Users/user/.ymm4m-dev/upstream-clean-export-input-hashes.after`

## Remaining gate

This is a reproducibly staged source-clean runtime candidate, not a release artifact. Resizing and repeated GUI stress, the remaining Tier A workflows, full component/license inventory, packaging, signing, notarization, and the user-requested release-time audit remain open.
