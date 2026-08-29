# Full-audit executable gates and release blockers (2026-08-29)

## Scope and safety

This pass followed `NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md` through the
automatable host, sanitizer, runtime-fixture, and low-level GPU gates. It did
not modify a user project, reset the dedicated prefix, inspect proprietary YMM4
implementation details, or open the deferred release-license audit document.
YMM4 and generated Windows binaries remained untracked and external to release
inputs.

The user explicitly confirmed that Developer ID signing is unavailable. The
result is therefore a pre-alpha development audit, not a release-ready build.
No release DMG was created.

## Locked inputs and provenance

- macOS 26.4 (25E246), ARM64 Mac Studio, Apple M3 Ultra (28 CPU cores, 60 GPU
  cores), 96 GB memory, Metal 4.
- Xcode 26.6 (17F113), Swift 6.3.3.
- YMM4 Lite 4.55.1.1 executable SHA-256:
  `96d80e18c52f00f16b7568e96346e5f8dfa99b57b5a531e60ca0c645dda0a822`.
- Wine source commit: `db11d0fe6a169c457e23d007e20404643d067aa8`.
- DXMT source commit: `e55ad281c60be97f8815b5848e57cfd9f967d759`.
- Implementation inventory: 121 files, inventory SHA-256
  `b2c4e0b22b0832f7c890a4f7d156e8cd183f046a9c7dccb1bfc80539f80355f4`.
- The Git repository still has zero tracked files. The inventory identifies this
  audited snapshot but does not replace release source provenance or authorize
  an initial commit.
- Both root-level YMM4 ZIP files are ignored by `*.zip`; neither was staged.
- High-confidence credential scan, excluding the deferred audit document and
  build/binary artifacts: 0 matching files.

## Host and memory/concurrency gates

| Gate | Current result |
|---|---|
| `swift build` | PASS |
| Swift warnings as errors | PASS |
| `swift run YMM4MContractTests` | PASS |
| Python unit tests | PASS (14 tests) |
| runtime lock validation | PASS |
| compatibility validation after registry expansion | PASS (20 features) |
| Swift AddressSanitizer build/contracts | PASS |
| Swift ThreadSanitizer build/contracts | PASS |
| C# bridge warnings-as-errors | BLOCKED: `dotnet` SDK is not installed |
| host Leaks trace | Contract process exited 0; trace captured, but this short run does not satisfy the required UI/soak/leak-trend gate |

The local Leaks trace is retained outside the repository at
`/Users/user/.ymm4m-dev/audit-artifacts-2026-08-29/host-contracts-leaks.trace`.
Its 137-file trace inventory SHA-256 is
`118927bbfb0ec3097d80f6cfa45f9593a0ee8cfbce2a1e6610830595049f176e`.

## Win32 warning gate and runtime regression

The fixture runner did not previously enable the runbook-required warning
gate. `tools/run-runtime-fixtures.sh` and the documented build commands now use
`-Wall -Wextra -Werror`. With that gate enabled:

- all eight runtime fixtures passed;
- D3D11 compute completed 100/100;
- a separate warning-clean D3D11 create/compute/dispatch/readback stress run
  completed 1,000/1,000 (log SHA-256
  `01f4591968d316b864e9f02e17a9d92cbeecaa6e414cd21f7d9c7c79df59efa9`);
- Japanese DirectWrite fallback completed for isolated/shared factories and
  empty/`ja-JP` locales;
- the native text helper rebuilt with warnings as errors and reproduced SHA-256
  `c57695530db4c754bedec54e57ad59bd2056441ab4adce7027fb63248d939112`.

## Direct GPU-use evidence

`xctrace` on this host lists and successfully recorded the current `Metal System
Trace` template. A warning-clean D3D11 compute fixture ran 100/100 under the
validated DXMT runtime. Exported trace tables attributed the following to the
launched `arch` process and its `dxmt-encode-thr` thread:

- 200 Metal command-buffer submissions;
- 300 Metal encoders;
- 300 Metal GPU intervals on the M3 Ultra;
- 0 Metal command-buffer-error rows.

The local trace is retained outside the repository at
`/Users/user/.ymm4m-dev/audit-artifacts-2026-08-29/dxmt-compute-metal.trace`.
Its 639-file trace inventory SHA-256 is
`a53d90c84c64c6c5c03ceb0e00569408e0b2996e5d51d4d7f761c8851f804824`.

This directly proves GPU work for the low-level DXMT compute fixture. It does
not prove the complete real-YMM4 rendering/performance matrix, Windows parity,
or soak stability. The Direct2D fixture does not currently expose an internal
1,000-iteration mode, so the documented 15-cycle Direct2D create/render/destroy
result remains the current limit and the runbook's 1,000-cycle Direct2D stress
gate remains open.

## Registry completeness correction

The runbook requires Finder drag-and-drop and clipboard workflows as independent
Tier A features. They were missing from `compatibility/features.yaml`. `DND001`
and `CLIP001` are now registered as `untested`; no behavior is inferred from
Finder LaunchServices or text-input results.

## Current release blockers

- Developer ID signing is unavailable by explicit user confirmation. Signing,
  notarization, stapling, Gatekeeper release assessment, and a release-ready DMG
  cannot pass.
- There is no Windows reference evidence or declared clean-machine OS/hardware
  matrix.
- Audible speaker playback requires an operator and was not claimed.
- No separately licensed Lite-compatible VoiceItem engine was introduced.
- Win32Service remains an unassigned crash, and the required repeat/soak/fault
  injection matrices remain incomplete.
- Tier A still contains partial and untested features, including the newly
  explicit drag-and-drop and clipboard entries.
- The `dotnet` SDK is absent, so the C# warning gate is not executable.
- Git/source provenance is insufficient for release because no file is tracked.

The release stop conditions are therefore active. The deferred final license
audit remains unopened, and packaging/signing/notarization were not started.

## Development-only app artifact

The existing non-release builder produced a runtime-free ARM64 development app
at `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-29/YMM4M-pre-alpha-development.app`.
It contains only `Contents/MacOS/YMM4M` and `Contents/Info.plist`; it contains no
YMM4, Wine, DXMT, Microsoft runtime/font, test media, or release DMG content.

- app binary SHA-256:
  `69c1757cabea1d54a61cdaa053c54925a3027c4abef5ae94e5c29058459c3b62`
- relative two-file inventory SHA-256:
  `94c144486bb4cba556e1b4bbef3fca575f7acb50a794f1177eaf6247899c0747`
- architecture: ARM64
- signature: linker-generated ad-hoc signature; no TeamIdentifier, Developer ID,
  Hardened Runtime release signing, notarization, or Gatekeeper release claim

This artifact is for local development inspection only and is not a substitute
for any Phase H or Phase I release deliverable.

## Development DMG and release draft

With explicit user authorization, the ad-hoc development app was placed in a
development-only DMG. The DMG was created by
`tools/build-development-dmg.sh`, which refuses overwrites and requires an ARM64
app with an ad-hoc signature and no TeamIdentifier.

- DMG:
  `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-29/YMM4M-0.1.0-prealpha-development-adhoc.dmg`
- SHA-256:
  `db06f04018f3c2de0a121c163a6dda41e4da939003520e4e0384645c5b8be800`
- size: 376,293 bytes
- `hdiutil verify`: PASS
- read-only mount contents: `YMM4M.app`, `Applications`, `READ-ME-FIRST.txt`,
  `LICENSE.txt`
- YMM4/Wine/DXMT/CrossOver/Microsoft runtime binary scan: PASS, none bundled
- mounted app: ARM64, ad-hoc signature, TeamIdentifier not set
- Gatekeeper release assessment: rejected with `source=no usable signature`, as
  expected for this non-notarized development artifact

The local unpublished draft is
`release-drafts/v0.1.0-prealpha-development.md`. A GitHub Draft Release was not
created because the repository has no HEAD commit and no configured remote.

## Cleanup

- The dedicated runtime fixture Wine server was stopped through its own
  `wineserver`; the post-run process-name check was clear.
- The selected macOS keyboard layout was `ABC`.
- No user project was written or overwritten.
