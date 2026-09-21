# License audit addendum — YMM4M v1.0.5

Audit date: 2026-09-21
Audited artifact: `YMM4M-1.0.5-arm64.dmg` (built by `tools/build-app.sh` +
`tools/build-release-dmg.sh` with the v1.0.5 notice and this addendum),
ad-hoc signed, not notarized.
Basis: `LEGAL-AUDIT-v1.0.4.md` (incorporated by reference) and the v1.0.5
diff on `main`.

> This addendum records changed bundled files beyond v1.0.4. No new bundled
> file kinds were added. Every other determination in
> `LEGAL-AUDIT-v1.0.0.md` through `LEGAL-AUDIT-v1.0.4.md` still holds. It
> does not grant any right in YukkuriMovieMaker4, Wine, DXMT, CrossOver, or
> Microsoft components; it records that none of them are distributed by
> YMM4M.

## 1. What changed in the DMG since v1.0.4

`YMM4M.app/Contents/` layout is unchanged (no added or removed files).
Content deltas, all YMM4M-authored:

| Path | Change since v1.0.4 | Determination |
|---|---|---|
| `MacOS/YMM4M` | Recompiled Swift (shared Rosetta live-check helper, pre-panel Rosetta gate in the setup UI, three Japanese/English status/help strings, v1.0.5 badge). No new linked frameworks (still only Apple system frameworks + compiled YMM4M sources). | **OPEN_OK (MIT)** — YMM4M's own code, author `Yuki_Orita`. No new third-party bytes. |
| `Info.plist` | `CFBundleShortVersionString` 1.0.5, `CFBundleVersion` 18. | Metadata only. |
| `Resources/RuntimeBootstrap/*`, `Brewfile`, `bootstrap.lock.json`, `patches/`, `tests/fixtures/`, `Resources/YMM4/` | Unchanged since v1.0.4. | Prior determinations stand. |
| `MACでYMM4を開く手順.md` (from `docs/MAC_SETUP.md`) | Unchanged since v1.0.4 (the GUI-audit text fixes live in the app's compiled strings, whose source is YMM4M-authored). | YMM4M-authored. |
| `READ-ME-FIRST.txt` | v1.0.5 notice (this release's changes disclosed). | YMM4M-authored. |
| `LEGAL-AUDIT-v1.0.5.md` (this file) | Replaces the v1.0.4 audit file in the image. | YMM4M-authored. |

**Still present nowhere in the DMG:** YukkuriMovieMaker4 or any of its files,
Wine, DXMT, FreeType, Noto Sans CJK JP, LLVM, NVAPI, mingw-directx-headers,
CrossOver, D3DMetal, Microsoft .NET / Windows Desktop runtime or fonts, FFmpeg,
AquesTalk. Verified the same way as v1.0.0–v1.0.4: `tools/build-app.sh`
review plus a `shasum` bundle listing before packaging (recorded in
`evidence/`).

## 2. Distribution-model finding

Unchanged from v1.0.0 §4 / v1.0.1 §2 / v1.0.2 §2 / v1.0.3 §2 / v1.0.4 §2: the
artifact is **YMM4M's own MIT code plus YMM4M-authored diffs and data**
(EXTERNAL_ONLY / 案3). No redistribution obligations attach. If a later
release ships a prebuilt Wine+DXMT runtime tarball, the full v1.0.0 §4 audit
requirement still applies first.

## 3. Residual limitations recorded (not license blockers)

Same as v1.0.4 §3, plus the concurrent-setup note: every setup step is
fail-closed, but two overlapping setups can waste hours; mutual exclusion
is a future design item, disclosed in `STATUS.md`.

## 4. Release gate

For **v1.0.5 as an EXTERNAL_ONLY, ad-hoc-signed distribution of YMM4M's own
code**: license gate **PASS**. No `UNKNOWN` for anything in the DMG.
