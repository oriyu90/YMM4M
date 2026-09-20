# License audit addendum — YMM4M v1.0.3

Audit date: 2026-09-21
Audited artifact: `YMM4M-1.0.3-arm64.dmg` (built by `tools/build-app.sh` +
`tools/build-release-dmg.sh` with the v1.0.3 notice and this addendum),
ad-hoc signed, not notarized.
Basis: `LEGAL-AUDIT-v1.0.2.md` (incorporated by reference) and the v1.0.3
diff on `main`.

> This addendum records changed bundled files beyond v1.0.2. No new bundled
> file kinds were added. Every other determination in
> `LEGAL-AUDIT-v1.0.0.md` / `LEGAL-AUDIT-v1.0.1.md` / `LEGAL-AUDIT-v1.0.2.md`
> still holds. It does not grant any right in YukkuriMovieMaker4, Wine, DXMT,
> CrossOver, or Microsoft components; it records that none of them are
> distributed by YMM4M.

## 1. What changed in the DMG since v1.0.2

`YMM4M.app/Contents/` layout is unchanged (no added or removed files).
Content deltas, all YMM4M-authored:

| Path | Change since v1.0.2 | Determination |
|---|---|---|
| `MacOS/YMM4M` | Recompiled Swift (functional Rosetta gate in probe + setup start, `HostCompatibility` majors 26/27, actionable bilingual Rosetta remedy, v1.0.3 badge). No new linked frameworks (still only Apple system frameworks + compiled YMM4M sources). | **OPEN_OK (MIT)** — YMM4M's own code, author `Yuki_Orita`. No new third-party bytes. |
| `Info.plist` | `CFBundleShortVersionString` 1.0.3, `CFBundleVersion` 16. | Metadata only. |
| `Resources/RuntimeBootstrap/bootstrap-wine-dxmt-runtime.sh` | Functional Rosetta preflight (x86_64 execution probe; marker only as no-`arch` fallback), Metal-shader compiler probe with process-local `DEVELOPER_DIR` fallback for the DXMT step, `install_name_tool` libc++ loader-path repair with fail-closed residual check. | **OPEN_OK (MIT)** — YMM4M-authored shell. |
| `Resources/RuntimeBootstrap/Brewfile`, `bootstrap.lock.json`, `patches/`, `tests/fixtures/`, `Resources/YMM4/` | Unchanged since v1.0.2. | Prior determinations stand. |
| `MACでYMM4を開く手順.md` (from `docs/MAC_SETUP.md`) | macOS 26/27 validated surface, post-upgrade Rosetta reinstall note, full-Xcode + Metal Toolchain prerequisite. | YMM4M-authored. |
| `READ-ME-FIRST.txt` | v1.0.3 notice (this release's changes disclosed). | YMM4M-authored. |
| `LEGAL-AUDIT-v1.0.3.md` (this file) | Replaces the v1.0.2 audit file in the image. | YMM4M-authored. |

The `install_name_tool` libc++ step does not add any redistributed binary:
it rewrites a loader path inside the user's locally built DXMT library to
the system C++ runtime. The DMG itself contains no Wine/DXMT binaries at all.

**Still present nowhere in the DMG:** YukkuriMovieMaker4 or any of its files,
Wine, DXMT, FreeType, Noto Sans CJK JP, LLVM, NVAPI, mingw-directx-headers,
CrossOver, D3DMetal, Microsoft .NET / Windows Desktop runtime or fonts, FFmpeg,
AquesTalk. Verified the same way as v1.0.0–v1.0.2: `tools/build-app.sh`
review plus a `shasum` bundle listing before packaging (recorded in
`evidence/`).

## 2. Distribution-model finding

Unchanged from v1.0.0 §4 / v1.0.1 §2 / v1.0.2 §2: the artifact is **YMM4M's
own MIT code plus YMM4M-authored diffs and data** (EXTERNAL_ONLY / 案3). No
redistribution obligations attach. If a later release ships a prebuilt
Wine+DXMT runtime tarball, the full v1.0.0 §4 audit requirement still applies
first.

## 3. Residual limitations recorded (not license blockers)

Same as v1.0.2 §3: no Developer ID signature or notarization (ad-hoc signed;
per-app "Open Anyway"); Windows-reference comparison, full Tier A matrix,
Win32Service crash-impact confirmation, GPU session tracing, and the
clean-machine hardware matrix remain open and disclosed in `STATUS.md` /
`README.md`. The clean-machine end-to-end bootstrap timing is now measured
for one M1 Max / macOS 27.0 run (see the v1.0.3 evidence file); other
hardware/versions remain unmeasured.

## 4. Release gate

For **v1.0.3 as an EXTERNAL_ONLY, ad-hoc-signed distribution of YMM4M's own
code**: license gate **PASS**. No `UNKNOWN` for anything in the DMG.
