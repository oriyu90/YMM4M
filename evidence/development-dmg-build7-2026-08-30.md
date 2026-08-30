# Development DMG build 7 — 2026-08-30

## Artifact

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-build7-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-build7-development-adhoc.dmg`
- DMG size: 709,532 bytes
- DMG SHA-256: `50e845fb94bf3b16a04f31ccfd8e4cc3fe8eea0540618b85f44a04995931a458`
- Host binary SHA-256: `71ea68273418884b9c955e326cff635b5c78f765e9f4a7615cadc2c6e141914c`
- Bundle: version `0.1.0`, build `7`, ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`
- Notarization/stapling: not performed

## Verification

- Swift warnings-as-errors build: pass
- Swift contracts: pass, including official receipt, family gate, shared settings,
  legacy copy, tampered previous-version refusal, and successful rollback
- Real official Standard 4.55.1.1 ZIP install contract: pass
- Python tests: 16/16
- Runtime-lock and 20-feature compatibility validators: pass
- Shell syntax, plist/JSON validation, and `git diff --check`: pass
- DMG checksum verification and read-only mount: pass
- Strict bundle signature and ARM64 checks: pass
- Forbidden YMM4/Wine/DLL/font/ZIP payload scan: pass
- Included `READ-ME-FIRST.txt` identifies development build 7: pass
- Bundled/source YMM4 catalog SHA-256:
  `557d5dd90f7315116f0ad6087af716bf2094f54f761a92c67e6c6072c9d3dbd1`
- GUI launch with migration-suppressing environment overrides and normal quit: pass

Build 7 supersedes build 6 by revalidating reused maintenance metadata, runtime boundary,
PE type, release-directory identity, and shared data before activation. Exact known-version
switches preserve `previous`; rollback validates its target before changing `current`.

The runtime and patches were not changed, so the recorded 8/8 runtime fixture and 100/100
compute result remains current and was not rerun as a new runtime candidate.

This is still a development-only artifact: ad-hoc, non-notarized, and runtime/YMM4-free.
It was superseded by build 8 after the final reviewed-source rebuild.
