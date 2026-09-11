# License audit addendum — YMM4M v1.0.2

Audit date: 2026-09-11
Audited artifact: `YMM4M-1.0.2-arm64.dmg` (built by `tools/build-app.sh` +
`tools/build-release-dmg.sh` with the v1.0.2 notice and this addendum),
ad-hoc signed, not notarized.
Basis: `LEGAL-AUDIT-v1.0.1.md` (incorporated by reference) and the v1.0.2
diff on `main`.

> This addendum records one added bundled file beyond v1.0.1. Every other
> determination in `LEGAL-AUDIT-v1.0.0.md` / `LEGAL-AUDIT-v1.0.1.md` still
> holds. It does not grant any right in YukkuriMovieMaker4, Wine, DXMT,
> CrossOver, or Microsoft components; it records that none of them are
> distributed by YMM4M.

## 1. What changed in the DMG since v1.0.1

`YMM4M.app/Contents/` layout is unchanged except one addition.
Content deltas:

| Path | Change since v1.0.1 | Determination |
|---|---|---|
| `MacOS/YMM4M` | Recompiled Swift (setup-hardening: Brewfile resolution, flex/brew/space preflights, heartbeat phase tags incl. `[gate]`, whitespace-safe compile cache, v1.0.2 badge). No new linked frameworks (still only Apple system frameworks + compiled YMM4M sources). | **OPEN_OK (MIT)** — YMM4M's own code, author `Yuki_Orita`. No new third-party bytes. |
| `Info.plist` | `CFBundleShortVersionString` 1.0.2, `CFBundleVersion` 15. | Metadata only. |
| `Resources/RuntimeBootstrap/Brewfile` | **New.** The repository-root `Brewfile` (meson/ninja/cmake/mingw-w64/bison/harfbuzz prerequisites), installed 0644 next to the bootstrap script so the in-app remedy points at a file the user actually has. | **OPEN_OK (MIT)** — YMM4M-authored build-prerequisite list naming Homebrew formulae; contains no third-party code. |
| `Resources/RuntimeBootstrap/*.sh`, `bootstrap.lock.json` (mirror metadata unchanged since v1.0.1) | Preflight/heartbeat/space-gate wording; pinned sources/hashes identical. | **OPEN_OK (MIT)**. |
| `Resources/RuntimeBootstrap/patches/`, `tests/fixtures/`, `Resources/YMM4/` | Unchanged since v1.0.1. | Prior determinations stand. |
| `READ-ME-FIRST.txt` | v1.0.2 notice (this release's changes disclosed). | YMM4M-authored. |
| `LEGAL-AUDIT-v1.0.2.md` (this file) | Replaces the v1.0.1 audit file in the image. | YMM4M-authored. |

**Still present nowhere in the DMG:** YukkuriMovieMaker4 or any of its files,
Wine, DXMT, FreeType, Noto Sans CJK JP, LLVM, NVAPI, mingw-directx-headers,
CrossOver, D3DMetal, Microsoft .NET / Windows Desktop runtime or fonts, FFmpeg,
AquesTalk. Verified the same way as v1.0.0/v1.0.1: `tools/build-app.sh`
review plus a `shasum` bundle listing before packaging (recorded in
`evidence/`).

## 2. Distribution-model finding

Unchanged from v1.0.0 §4 / v1.0.1 §2: the artifact is **YMM4M's own MIT code
plus YMM4M-authored diffs and data** (EXTERNAL_ONLY / 案3). No redistribution
obligations attach. If a later release ships a prebuilt Wine+DXMT runtime
tarball, the full v1.0.0 §4 audit requirement still applies first.

## 3. Residual limitations recorded (not license blockers)

Same as v1.0.1 §3: no Developer ID signature or notarization (ad-hoc signed;
per-app "Open Anyway"); Windows-reference comparison, full Tier A matrix,
Win32Service crash-impact confirmation, GPU session tracing, and the
clean-machine hardware matrix remain open and disclosed in `STATUS.md` /
`README.md`. The full clean-machine end-to-end bootstrap timing is additionally
unmeasured (heartbeat + resume cover it by design, not by a fresh run).

## 4. Release gate

For **v1.0.2 as an EXTERNAL_ONLY, ad-hoc-signed distribution of YMM4M's own
code**: license gate **PASS**. No `UNKNOWN` for anything in the DMG.
