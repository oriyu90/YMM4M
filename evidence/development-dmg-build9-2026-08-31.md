# Development DMG build 9 — 2026-08-31

## Artifact

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-31/YMM4M-0.1.0-build9-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-31/YMM4M-0.1.0-build9-development-adhoc.dmg`
- DMG size: 716,434 bytes
- DMG SHA-256: `e09ceaf0152c3f7e71ac4a7b561b7d2d6f8abf6dc444d0496e4c70333d6db302`
- Signed host binary SHA-256: `9502d95c043669c6d0a10c368e624e3d88a6d97a54a6a7d01a2ec4c4f952e082`
- Bundle: version `0.1.0`, build `9`, ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`
- Notarization/stapling: not performed

## Verification

- Full automatic Wine/DXMT download/build/stage/prefix/activation: pass
- Active patchset5 runtime and prefix host validation: pass
- Swift warning-as-error build and contracts: pass
- Python tests: 18/18; runtime-lock and 20-feature validators: pass
- Runtime fixtures: 8/8; D3D11 compute: 100/100
- Shell syntax, plist validation, and source/bundled catalog equality: pass
- DMG checksum verification and read-only mount: pass
- Strict bundle signature, ARM64, and forbidden payload scan: pass
- `READ-ME-FIRST.txt` identifies build 9: pass
- Bundled/source catalog SHA-256 both:
  `0ca8d2775404576b91185813a8ddd993f2dad9dbdd2a48ae23cc48edca2e75a2`
- GUI launch and normal quit: pass

The DMG contains no YMM4, Wine/DXMT runtime binaries, fonts, CrossOver, or
Microsoft runtime payloads. It remains ad-hoc, non-notarized, and development-only.
