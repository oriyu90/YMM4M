# License audit addendum — YMM4M v1.0.1

Audit date: 2026-09-11
Audited artifact: `YMM4M-1.0.1-arm64.dmg` (built by `tools/build-app.sh` +
`tools/build-release-dmg.sh` with the v1.0.1 notice and this addendum),
ad-hoc signed, not notarized.
Basis: `LEGAL-AUDIT-v1.0.0.md` (incorporated by reference) and the v1.0.1
diff on `main`.

> This addendum records that v1.0.1 adds **no new bundled content kinds**
> beyond v1.0.0. Every determination in `LEGAL-AUDIT-v1.0.0.md` therefore
> still holds; only the deltas below need a finding. It does not grant any
> right in YukkuriMovieMaker4, Wine, DXMT, CrossOver, or Microsoft
> components; it records that none of them are distributed by YMM4M.

## 1. What changed in the DMG since v1.0.0

`YMM4M.app/Contents/` layout is unchanged. Content deltas:

| Path | Change since v1.0.0 | Determination |
|---|---|---|
| `MacOS/YMM4M` | Recompiled Swift with bilingual core diagnostics (`CoreLanguage`/`CoreMessages`, Rosetta execution-probe fallback, untested-OS notice). No new linked frameworks (still only Apple system frameworks + compiled YMM4M sources). | **OPEN_OK (MIT)** — YMM4M's own code, author `Yuki_Orita`. No new third-party bytes. |
| `Info.plist` | `CFBundleShortVersionString` 1.0.1, `CFBundleVersion` 14. | Metadata only. |
| `Resources/RuntimeBootstrap/bootstrap.lock.json` | Mirror metadata only: two unverified Internet Archive mirrors demoted to documentation-only (their `sha256` removed). Pinned sources, commits, primary URLs, and hashes are byte-identical to v1.0.0. | **OPEN_OK (MIT)** — YMM4M-authored data; no new upstream content. |
| `Resources/RuntimeBootstrap/*.sh` | `--check-urls` probes effective URLs only; usage text updated. No new downloads, hosts, or build inputs. | **OPEN_OK (MIT)**. |
| `Resources/RuntimeBootstrap/patches/`, `tests/fixtures/`, `Resources/YMM4/` | Unchanged from v1.0.0. | Prior determinations stand. |
| `READ-ME-FIRST.txt` | v1.0.1 notice (this release's changes disclosed). | YMM4M-authored. |
| `LEGAL-AUDIT-v1.0.1.md` (this file) | Replaces the v1.0.0 audit file in the image. | YMM4M-authored. |

**Still present nowhere in the DMG:** YukkuriMovieMaker4 or any of its files,
Wine, DXMT, FreeType, Noto Sans CJK JP, LLVM, NVAPI, mingw-directx-headers,
CrossOver, D3DMetal, Microsoft .NET / Windows Desktop runtime or fonts, FFmpeg,
AquesTalk. Verified the same way as v1.0.0: `tools/build-app.sh` review plus a
`shasum` bundle listing before packaging (recorded in `evidence/`).

## 2. Distribution-model finding

Unchanged from v1.0.0 §4: the artifact is **YMM4M's own MIT code plus
YMM4M-authored diffs and data** (EXTERNAL_ONLY / 案3). No redistribution
obligations attach. If a later release ships a prebuilt Wine+DXMT runtime
tarball, the full v1.0.0 §4 audit requirement still applies first.

## 3. Residual limitations recorded (not license blockers)

Same as v1.0.0 §5: no Developer ID signature or notarization (ad-hoc signed;
per-app "Open Anyway"); Windows-reference comparison, full Tier A matrix,
Win32Service crash-impact confirmation, and the clean-machine hardware matrix
remain open and disclosed in `STATUS.md` / `README.md`.

## 4. Release gate

For **v1.0.1 as an EXTERNAL_ONLY, ad-hoc-signed distribution of YMM4M's own
code**: license gate **PASS**. No `UNKNOWN` for anything in the DMG.
