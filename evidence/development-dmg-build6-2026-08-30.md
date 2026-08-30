# Development DMG build 6 — 2026-08-30

## Artifact

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-build6-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-build6-development-adhoc.dmg`
- DMG size: 708,268 bytes
- DMG SHA-256: `dffe518a0a56dd96844154c37cdd66759ce3c4dc3484b1c96f8955172bf91e70`
- Bundle: version `0.1.0`, build `6`, ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`
- Notarization/stapling: not performed

## Verification

- Swift warnings-as-errors build: pass
- Swift contracts: pass, including official receipt, same-family gate, settings
  persistence, tampered-previous refusal, successful rollback, and legacy Lite data copy
- Real official Standard 4.55.1.1 ZIP install contract: pass
- Python tests: 16/16
- Runtime-lock and 20-feature compatibility validators: pass
- Shell syntax, Info.plist lint, JSON parse, and `git diff --check`: pass
- DMG checksum verification and read-only mount: pass
- Strict bundle signature and ARM64 checks: pass
- Forbidden YMM4/Wine/DLL/font/ZIP payload scan: pass
- Included `READ-ME-FIRST.txt` identifies development build 6: pass
- Bundled/source YMM4 catalog SHA-256:
  `557d5dd90f7315116f0ad6087af716bf2094f54f761a92c67e6c6072c9d3dbd1`
- GUI process launch with environment overrides that suppress settings migration,
  followed by normal application quit: pass

The runtime and patches were not changed, so the previously recorded 8/8 runtime fixture
and 100/100 compute evidence remains the current result and was not rerun as if it were a
new runtime candidate.

This remains a development-only artifact. It is not Developer ID signed,
not notarized, and not release-ready. It contains no YMM4 ZIP or executable.
