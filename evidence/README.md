# Evidence

Generated, non-proprietary evidence belongs here. Inventories must contain hashes and metadata only, never YMM4 binaries or secrets. Large logs are ignored by Git and should be attached to a matching test record after redaction.

The tracked `baseline-2026-08-24.md` is the concise, redacted source of truth for the first runtime comparison. Raw Wine/YMM4 logs and screenshots remain local evidence and are intentionally not release artifacts.

`upstream-wine-dxmt-metal-view-2026-08-26.md` records the first CrossOver-free Wine 11.0 + source-built DXMT candidate, its Metal-view bridge, eight-fixture result, and YMM4 Lite CLI/GUI startup evidence.

`wpf-ime-managed-surface-2026-08-27.md` records the managed client-surface correction, the required WPF software-profile registry value, visible clean-runtime UI evidence, the Japanese IME failure isolated to YMM4's input-control path by passing Wine Notepad and runtime-matched standalone WPF controls, and the basic native committed-text workaround gate.

`ime-overlay-core-workflow-2026-08-27.md` records native-overlay text add/save success, the project-reopen regression observed at that time, and the developer launch-script environment correction. The newer isolation record supersedes that historical failure as current state.

`project-reopen-isolation-2026-08-28.md`, `runtime-fixture-regression-2026-08-28.md`, `ymm4-lite-gif-repeat-2026-08-28.md`, and `ymm4-lite-video-split-2026-08-28.md` record the current PROJECT001 result, automated low-level runtime gate, GIF repeatability, and in-memory video split result respectively.

`finder-integration-2026-08-29.md` records the native `.ymmp` intake implementation, safe `M:` mapping and hash-based YMM4 version gate, the reproducible unsigned ARM64 development bundle, and the passing LaunchServices open test. It leaves `.ymme` installation and all release signing gates open.

`version-management-2026-08-29.md` records the atomic, non-destructive version-selection and rollback primitive. It leaves official-updater behavior and both product update state machines open.

`quality-gates-2026-08-29.md` records the final host/tooling test matrix, process and input-source cleanup, and the repository's all-untracked Git state.
