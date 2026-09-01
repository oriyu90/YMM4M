# Development DMG build 11 — 2026-09-01

## Scope

Build 11 makes the one-pass installer able to complete on a provisioned Apple
Silicon Mac without a hand-placed LLVM toolchain, and fails fast with actionable
messages when a host prerequisite is missing. No app behavior outside the
bootstrap path changed.

- Pinned upstream LLVM 15.0.7 x86_64 release added to `runtime/bootstrap.lock.json`
  (`sources.llvm15Toolchain`, SHA-256
  `d16b6d536364c5bec6583d12dd7e6cf841b9f508c4430d9ee886726bd9983f1c`). When
  `YMM4M_LLVM15_ROOT` is absent, `tools/bootstrap-wine-dxmt-runtime.sh` downloads
  and hash-verifies it and uses it only as a DXMT build tool. It is never staged
  into or shipped with the runtime.
- Rosetta 2 is preflighted before any download/build; the failure points at
  `softwareupdate --install-rosetta`.
- Missing Homebrew build tools and unverified MinGW GCC versions print exact
  install / `brew pin` commands; the MinGW gate stays pinned to 15.2.0 / 16.2.0
  because the app validates staged PE hashes against
  `RosettaWineBackend.verifiedRuntimeVariants`.
- `docs/MAC_SETUP.md`, `docs/RUNTIME_BOOTSTRAP_DESIGN.md`,
  `THIRD_PARTY_NOTICES.md`, and `LICENSE_MATRIX.md` updated for the pinned
  build-tool acquisition and the ~10 GB free-space requirement.

## Artifact

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-09-01/YMM4M-0.1.0-build11-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-09-01/YMM4M-0.1.0-build11-development-adhoc.dmg`
- DMG size: 736,476 bytes
- DMG SHA-256: `734dca85817449312e9083b6f43a13a41bb9a3a91f35337cffd2700c077f4f7d`
- Signed host binary SHA-256: `c32c0579cdbd5499e00daf863bb3dab682493f5ae21a09840f7ef46d6156a4e6`
- Bundle: version `0.1.0`, build `11`, ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`
- Notarization/stapling: not performed

## Verification

- Swift release build and `YMM4MContractTests`: pass
- Python tests: 21/21 (adds LLVM-toolchain pin, Rosetta preflight, and
  LLVM auto-fetch coverage)
- `tools/validate-compatibility.py` (20 features) and
  `tools/validate-runtime-lock.py`: pass
- Shell syntax for every `tools/*.sh` and `git diff --check`: pass
- `bootstrap-wine-dxmt-runtime.sh --plan` with and without
  `--accept-third-party`: reports the pinned LLVM source / local presence and
  Rosetta status; refuses without consent
- DMG `hdiutil verify` and read-only mount: pass
- Strict `codesign --verify --deep --strict` on the mounted app: valid, satisfies
  its Designated Requirement
- ARM64-only host binary: pass
- `READ-ME-FIRST.txt` identifies build 11: pass
- Bundled `Contents/Resources/RuntimeBootstrap` catalog (5 scripts + lock + 4
  patches) byte-matches the tracked `tools/`, `runtime/bootstrap.lock.json`, and
  `patches/` sources
- Bundled and source YMM4 release catalog SHA-256 both:
  `0ca8d2775404576b91185813a8ddd993f2dad9dbdd2a48ae23cc48edca2e75a2`
- No `.exe`, `.dll`, `.so`, font, Wine/DXMT/CrossOver, or Microsoft runtime
  binary payloads in the bundle (only the intended shell/JSON/patch text)
- GUI launch and normal quit: pass

The DMG contains no YMM4, Wine/DXMT runtime binaries, fonts, CrossOver, or
Microsoft runtime payloads. It remains ad-hoc, non-notarized, and
development-only. Developer ID signing and notarization are unavailable in this
environment, so this is not a release-ready distribution.
