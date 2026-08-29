# Changelog

## 0.1.0 development build 4 (draft) — 2026-08-30

### Added

- In-app official YMM4 ZIP selection, strict archive/executable hash validation,
  versioned installation, and a clear `YMM4をMacで開く` launch action.
- Machine-readable YMM4 release catalog with required runtime-profile binding.
- Versioned runtime and prefix stores with atomic active-channel switching.
- Runtime/prefix binding metadata, legacy-layout migration, and update-resilience
  design audit.

### Fixed

- Runtime and prefix updates no longer overwrite a single active destination.
- Managed YMM4 executables changed after installation are refused at launch.
- Unknown YMM4/runtime combinations fail closed instead of being guessed
  compatible.

### Known limitations

- The catalog and strict runtime hashes require a tested YMM4M update before a
  new upstream YMM4 or runtime is accepted.
- A signed remote catalog and rollback selection UI are not implemented.
- The DMG remains ad-hoc and non-notarized because Developer ID is unavailable.

## 0.1.0 pre-alpha development build 3 (draft) — 2026-08-30

### Added

- One-confirmation automatic bootstrap for pinned Wine, DXMT, build dependencies,
  clean runtime staging, and the dedicated WPF-profiled prefix.
- Pinned FreeType headers and prefix-local Noto Sans CJK JP setup.
- Download hash/path validation, build preflight, reproducible Wine PE paths,
  and phase-specific progress/error reporting.
- Runtime bootstrap design, architecture maintenance guide, and reproducible
  end-to-end evidence indexed from `COMMON_RULES.md`.

### Fixed

- Fresh prefixes no longer depend on a host-installed Japanese font.
- The recorded Wine patch now includes the tested Direct2D Premultiply effect.
- Prefix setup shuts down Wine services instead of waiting indefinitely.

### Known limitations

- This remains an ad-hoc, non-notarized development build because Developer ID
  signing is unavailable.
- The app builds the compatibility runtime locally; the DMG does not bundle
  YMM4, Wine/DXMT binaries, proprietary Microsoft files, fonts, or CrossOver.
- Toolchain prerequisites and the remaining Tier A/final-license gates remain
  documented in `STATUS.md`.

## 0.1.0 pre-alpha development build 2 (draft) — 2026-08-30

### Added

- Four-step macOS setup screen for the validated runtime, dedicated Wine
  prefix, official YMM4 executable, and optional project/media root.
- Explicit `Check settings`, `Launch YMM4`, and `Open project` actions.
- Runtime hash, Rosetta, WPF profile, safe-prefix, and YMM4-version feedback in
  the setup UI.
- UI-selected prefix support without requiring `YMM4M_PREFIX` in the launch
  environment.
- In-app explanation of the pre-alpha/ad-hoc limitations and the macOS launch
  workflow.
- `docs/MAC_SETUP.md`, also included in the development DMG.

### Changed

- The misleading ZIP-selection control, which did not install YMM4, has been
  removed from the main flow.
- Finder project opening and the project picker now share the same contained
  `M:` mapping and launch path.
- The main window enforces a readable minimum content size.

### Known limitations

- This is not a release-ready build. It has no Developer ID signature or
  notarization.
- The DMG does not bundle or automatically install YMM4, Wine, DXMT, CrossOver,
  Microsoft runtimes/fonts, or voice engines.
- See `STATUS.md` and `compatibility/features.yaml` for the remaining functional
  and stability gates.

## 0.1.0 pre-alpha development build 1 (local draft) — 2026-08-29

- First local ARM64 ad-hoc development app and DMG draft.
- Host sanitizer, runtime fixture, and low-level Metal trace audit recorded.
