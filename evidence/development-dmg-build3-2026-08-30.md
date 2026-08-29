# Development DMG build 3 — 2026-08-30

## Outcome

The automatic-bootstrap UI and resources were packaged as an ARM64,
development-only DMG. Developer ID signing and notarization were intentionally
not attempted because no Developer ID identity is available.

- App: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-build3-development.app`
- DMG: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-prealpha3-development-adhoc.dmg`
- DMG SHA-256: `33248b15eae13b1d7a87b4fbeb90145e6d77461963ebb86d2bfd9996b7adabfe`
- DMG size: 529,913 bytes
- App binary SHA-256: `abecf949e5e837f19b85742632bd5a247ac9f5a152ed800593af6f81637dea59`
- Bundle version: 3
- Architecture: ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`

## Packaging correction

The first build-3 packaging attempt exposed that a linker ad-hoc signature on
the executable did not seal resources added later. That candidate failed
`codesign --verify --deep --strict` and was renamed with
`invalid-signature`; it is not the release-draft asset. `tools/build-app.sh`
now ad-hoc signs the completed bundle and immediately verifies it. The final
app passes strict deep verification.

## DMG inspection

- `hdiutil verify`: PASS
- read-only mount: PASS
- mounted app strict signature verification: PASS
- contents: YMM4M.app, Applications symlink, MIT license, development warning,
  and Mac setup guide
- bundled bootstrap resources: scripts, lock file, and four source patches
- `.exe`, `.dll`, Wine executable, TTC, and OTF payload scan: none found
- Gatekeeper assessment: rejected, as expected for ad-hoc/non-notarized output

The app launched and remained responsive as a normal ARM64 process. Automated
screen capture returned a black desktop image in this execution context, so it
is not accepted as new visual evidence; the earlier inspected setup UI remains
recorded in `evidence/setup-ui-development-dmg-2026-08-30.md`.

This artifact is not release-ready and must remain a draft prerelease asset.
