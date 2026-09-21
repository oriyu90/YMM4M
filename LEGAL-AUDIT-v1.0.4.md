# License audit addendum — YMM4M v1.0.4

Audit date: 2026-09-21
Audited artifact: `YMM4M-1.0.4-arm64.dmg` (built by `tools/build-app.sh` +
`tools/build-release-dmg.sh` with the v1.0.4 notice and this addendum),
ad-hoc signed, not notarized.
Basis: `LEGAL-AUDIT-v1.0.3.md` (incorporated by reference) and the v1.0.4
diff on `main`.

> This addendum records changed bundled files beyond v1.0.3. No new bundled
> file kinds were added. Every other determination in
> `LEGAL-AUDIT-v1.0.0.md` through `LEGAL-AUDIT-v1.0.3.md` still holds. It
> does not grant any right in YukkuriMovieMaker4, Wine, DXMT, CrossOver, or
> Microsoft components; it records that none of them are distributed by
> YMM4M.

## 1. What changed in the DMG since v1.0.3

`YMM4M.app/Contents/` layout is unchanged (no added or removed files).
Content deltas, all YMM4M-authored:

| Path | Change since v1.0.3 | Determination |
|---|---|---|
| `MacOS/YMM4M` | Recompiled Swift (new 4.56 catalog family is data, but: anchor-accepting `accepts()`, atomic-only install receipts, unreadable-receipt nil classification, v1.0.4 badge). No new linked frameworks (still only Apple system frameworks + compiled YMM4M sources). | **OPEN_OK (MIT)** — YMM4M's own code, author `Yuki_Orita`. No new third-party bytes. |
| `Info.plist` | `CFBundleShortVersionString` 1.0.4, `CFBundleVersion` 17. | Metadata only. |
| `Resources/YMM4/ymm4-releases.json` | Added `4.56-runtime-boundary-1` maintenance family (SHA-256 records of official upstream files, not the files themselves). | **OPEN_OK (MIT)** — YMM4M-authored compatibility data. |
| `Resources/RuntimeBootstrap/*`, `Brewfile`, `bootstrap.lock.json`, `patches/`, `tests/fixtures/` | Unchanged since v1.0.3. | Prior determinations stand. |
| `MACでYMM4を開く手順.md` (from `docs/MAC_SETUP.md`) | 4.56 provisional-candidate note and the original-filename requirement. | YMM4M-authored. |
| `READ-ME-FIRST.txt` | v1.0.4 notice (this release's changes disclosed). | YMM4M-authored. |
| `LEGAL-AUDIT-v1.0.4.md` (this file) | Replaces the v1.0.3 audit file in the image. | YMM4M-authored. |

**Still present nowhere in the DMG:** YukkuriMovieMaker4 or any of its files,
Wine, DXMT, FreeType, Noto Sans CJK JP, LLVM, NVAPI, mingw-directx-headers,
CrossOver, D3DMetal, Microsoft .NET / Windows Desktop runtime or fonts, FFmpeg,
AquesTalk. Verified the same way as v1.0.0–v1.0.3: `tools/build-app.sh`
review plus a `shasum` bundle listing before packaging (recorded in
`evidence/`).

## 2. Distribution-model finding

Unchanged from v1.0.0 §4 / v1.0.1 §2 / v1.0.2 §2 / v1.0.3 §2: the artifact is
**YMM4M's own MIT code plus YMM4M-authored diffs and data** (EXTERNAL_ONLY /
案3). No redistribution obligations attach. If a later release ships a
prebuilt Wine+DXMT runtime tarball, the full v1.0.0 §4 audit requirement
still applies first.

## 3. Residual limitations recorded (not license blockers)

Same as v1.0.3 §3, plus: 4.56 behavior beyond install/CLI/main-window
(editing, playback, export, IME, voices) is unverified and disclosed in
`STATUS.md` / `README.md`; upstream v4.56.1.1 exists but was not installed.

## 4. Release gate

For **v1.0.4 as an EXTERNAL_ONLY, ad-hoc-signed distribution of YMM4M's own
code**: license gate **PASS**. No `UNKNOWN` for anything in the DMG.
