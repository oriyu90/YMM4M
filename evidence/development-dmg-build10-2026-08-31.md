# Development DMG build 10 — 2026-08-31

## Artifact

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-31/YMM4M-0.1.0-build10-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-31/YMM4M-0.1.0-build10-development-adhoc.dmg`
- DMG size: 734,530 bytes
- DMG SHA-256: `45c11ce14839d3839976d0cad4d38c35834eb38f057a46135cf6513be01a8308`
- Signed host binary SHA-256: `25f90cf227bc48d9cc9c2bf63fce26d9a1f2004f6c94fc7822264b4435b2d5c1`
- Bundle: version `0.1.0`, build `10`, ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`
- Notarization/stapling: not performed

## Verification

- Real interrupted-state complete setup and idempotent second run: pass
- Official Standard and Lite 4.55.1.1 ZIP install contracts: pass
- Swift warning-as-error build and contracts: pass
- Python tests: 19/19; runtime-lock and 20-feature validators: pass
- Shell syntax, plist validation, and source/bundled catalog equality: pass
- DMG checksum verification and read-only mount: pass
- Strict bundle signature, ARM64, and forbidden payload scan: pass
- `READ-ME-FIRST.txt` identifies build 10: pass
- Bundled/source catalog SHA-256 both:
  `0ca8d2775404576b91185813a8ddd993f2dad9dbdd2a48ae23cc48edca2e75a2`
- GUI launch and normal quit: pass

The DMG contains no YMM4, Wine/DXMT runtime binaries, fonts, CrossOver, or
Microsoft runtime payloads. It remains ad-hoc, non-notarized, and development-only.
