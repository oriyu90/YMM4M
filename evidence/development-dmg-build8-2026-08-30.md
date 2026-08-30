# Development DMG build 8 — 2026-08-30

## Artifact

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-build8-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-build8-development-adhoc.dmg`
- DMG size: 709,530 bytes
- DMG SHA-256: `6577e5be1aa053d5829827e9033715f7a993ec00b83765d5f59082e2237b8a40`
- Signed host binary SHA-256: `2bea7722f8c134b9e2c3c5067f63a14057f9f05fde81dcc0bcdd9822c445e6e8`
- Bundle: version `0.1.0`, build `8`, ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`
- Notarization/stapling: not performed

## Verification

- Final-source Swift warning-as-error build and contracts: pass
- Official receipt/family/shared-settings/tamper-refusal/rollback contracts: pass
- Real official Standard 4.55.1.1 ZIP install contract: pass
- Python tests: 16/16; runtime-lock and 20-feature validators: pass
- Shell syntax, plist/JSON validation, and `git diff --check`: pass
- DMG checksum verification and read-only mount: pass
- Strict bundle signature, ARM64, forbidden payload scan: pass
- `READ-ME-FIRST.txt` identifies build 8: pass
- Bundled/source catalog SHA-256 both:
  `557d5dd90f7315116f0ad6087af716bf2094f54f761a92c67e6c6072c9d3dbd1`
- GUI launch with migration-suppressing overrides and normal quit: pass

Build 8 is the current artifact built after the final source review. Runtime and patches did
not change; the existing 8/8 fixture and 100/100 compute evidence remains current.

This remains a runtime/YMM4-free, ad-hoc, non-notarized development artifact.
