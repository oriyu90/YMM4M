# Guided setup UI and development DMG build 2 (2026-08-30)

## Scope

This change makes the existing development requirements visible and selectable
in the native macOS host. It does not change YMM4 compatibility code, bundle a
runtime, install a voice engine, modify a user project, or open the deferred
release-license audit document.

## UI correction

The previous screen exposed only the YMM4 executable and Media Root even though
launch also required a validated Wine/DXMT runtime and a dedicated WPF-profiled
prefix through environment variables. The new screen presents:

1. validated runtime folder;
2. dedicated Wine prefix;
3. official `YukkuriMovieMaker.exe`;
4. optional project/media root;
5. explicit Check settings, Launch YMM4, and Open project actions;
6. an in-app Mac launch guide and development/ad-hoc warning;
7. the existing version-scoped Japanese-input workaround as a separate panel.

The selected prefix is passed explicitly to `RosettaWineBackend`; the sanitized
allow-list, runtime manifest/full-file hash validation, safe-prefix check, WPF
profile check, YMM4 executable classification, and contained M: mapping remain
mandatory. A contract test confirms that a UI-selected prefix overrides an
environment value without allowing unrelated environment data through.

The removed ZIP picker only selected a file and did not install it; removing it
prevents the UI from implying that YMM4 installation completed.

## Visual QA

The final UI was launched with the existing isolated development inputs and
brought to the foreground for visual inspection. The minimum content size,
four steps, paths, environment-source badges, progress, launch actions, and
pre-alpha warning are visible without horizontal clipping.

- screenshot: `evidence/ymm4m-setup-ui-2026-08-30.png`
- SHA-256:
  `b906fddb42500d3de6e2c74dcd80e7ff9c5444211f74a83db268924f6ba85d6e`

No YMM4 launch button or project action was invoked during visual QA.

## Documentation

`docs/MAC_SETUP.md` records the exact four settings, paths used on the current
development machine, per-app macOS approval guidance, launch/project-open
steps, Japanese-input workaround, and known limitations. The guide is included
in the DMG as `MACでYMM4を開く手順.md`.

## Verification

- Swift warnings-as-errors build: PASS
- contract tests with the validated runtime and prefix: PASS
- Swift AddressSanitizer build/contracts: PASS
- Swift ThreadSanitizer build/contracts: PASS
- Python tests: PASS (14/14)
- runtime lock validation: PASS
- compatibility validation: PASS (20 features)
- all shell syntax and Info.plist lint: PASS

## Development artifact build 2

- DMG:
  `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-prealpha2-development-adhoc.dmg`
- SHA-256:
  `f12f7ace403d8a95834dfb4aa0e12e71c2b68d0bb142b7e2370b9c656b199746`
- size: 452,517 bytes
- app binary SHA-256:
  `d418c7b4d6e633b59ada79f55d15edb2d003c59c65b2486d8d97f57fc733bb07`
- bundle version: 2
- architecture: ARM64
- signature: linker-generated ad-hoc; TeamIdentifier not set
- `hdiutil verify`: PASS
- read-only mount: PASS
- mounted items: app, Applications symlink, LICENSE, development warning, Mac
  setup guide
- YMM4/Wine/DXMT/CrossOver/Microsoft runtime binary scan: PASS, none bundled
- Gatekeeper release assessment: rejected with `source=no usable signature`, as
  expected for a non-notarized development artifact

This is not a release-ready DMG. The local draft remains unpublished because
the Git repository has no HEAD commit or remote.
