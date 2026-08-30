# Development DMG build 5 — 2026-08-30

## Artifact

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-build5-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-build5-development-adhoc.dmg`
- DMG size: 621,124 bytes
- DMG SHA-256: `54211cd6b908dfe9d694ba4d118a9b749419372e1ac2cf2f24d3a8f50dfd0bf6`
- Bundle: version `0.1.0`, build `5`, ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`
- Notarization/stapling: not performed

## Verification

- Swift warnings-as-errors build: pass
- Swift contracts: pass, including settings persistence/migration
- Real official standard 4.55.1.1 ZIP contract: pass
- Real official Lite 4.55.1.1 ZIP contract: pass
- Python tests: 16/16
- Runtime-lock and 20-feature compatibility validators: pass
- Runtime fixtures: 8/8; compute: 100/100
- Shell syntax, Info.plist lint, and `git diff --check`: pass
- DMG checksum verification and read-only mount: pass
- Strict bundle signature and ARM64 checks: pass
- Forbidden YMM4/Wine/DLL/font payload scan: pass
- Included `READ-ME-FIRST.txt` identifies development build 5: pass
- Bundled/source YMM4 catalog SHA-256:
  `47a5ca96615d7ab115267e2845d1a0b80ad53b8eef690ad5e0bc62041fa3c100`
- GUI process launch with environment overrides that suppress settings migration,
  followed by normal application quit: pass

This remains a development-only artifact. It is not Developer ID signed,
not notarized, and not release-ready. It contains no YMM4 ZIP or executable.
