# Final license audit — YMM4M v1.0.0

Audit date: 2026-09-07
Audited artifact: `YMM4M-1.0.0-arm64.dmg` (built by `tools/build-app.sh` +
`tools/build-development-dmg.sh`), ad-hoc signed, not notarized.
Basis: `common-rules-document/YMM4M/YMM4M ライセンス監査・実装判断指示.md`
(§1–§3, §22–§23) and `NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md` Phase G.

> This audit resolves every prior `UNKNOWN` in `LICENSE_MATRIX.md` for the
> **contents of the distributed DMG**. It does not grant any right in
> YukkuriMovieMaker4, Wine, DXMT, CrossOver, or Microsoft components; it records
> that none of them are distributed by YMM4M.

## 1. What the DMG actually contains

`hdiutil` image → `YMM4M.app` plus three plain-text files
(`READ-ME-FIRST.txt`, `LICENSE.txt`, `MACでYMM4を開く手順.md`) and an
`/Applications` symlink.

`YMM4M.app/Contents/`:

| Path | Origin | Kind |
|---|---|---|
| `MacOS/YMM4M` | YMM4M | Compiled Swift (this repo's `app/`, `bridge/Protocol`) |
| `Info.plist` | YMM4M | Metadata |
| `Resources/RuntimeBootstrap/*.sh` | YMM4M | Bootstrap / stage / prefix / gate shell scripts |
| `Resources/RuntimeBootstrap/bootstrap.lock.json` | YMM4M | Pinned URLs + SHA-256 + mirrors |
| `Resources/RuntimeBootstrap/patches/000{1..4}-*.patch` | YMM4M | Unified diffs authored by YMM4M |
| `Resources/RuntimeBootstrap/tests/fixtures/*.cpp` | YMM4M | 8 compatibility gate reproducers |
| `Resources/YMM4/ymm4-releases.json` | YMM4M | Compatibility catalogue (hashes + notes) |

**Not present anywhere in the DMG:** YukkuriMovieMaker4 or any of its files,
Wine, DXMT, FreeType, Noto Sans CJK JP, LLVM, NVAPI, mingw-directx-headers,
CrossOver, D3DMetal, Microsoft .NET / Windows Desktop runtime or fonts, FFmpeg,
AquesTalk. Verified by `tools/build-app.sh` review and by
`shasum`-listing the built bundle before packaging (recorded in
`evidence/`).

## 2. Public-level determination per component

| Component | In DMG? | Determination | Basis / obligations discharged |
|---|---|---|---|
| YMM4M Swift / C / C# / Python / shell source | yes (compiled) | **OPEN_OK (MIT)** | `LICENSE`; author `Yuki_Orita`. |
| `patches/0001-dxmt-yymm4-compat.patch` | yes | **OPEN_OK (MIT diff over an LGPL-2.1-or-later work)** | The diff is YMM4M's own copyrighted text. It carries a handful of unchanged DXMT context lines (de minimis). The DMG ships **no DXMT binary**, so LGPL §4/§6 relinking and object-code obligations do not attach to the DMG. The *modified DXMT source* is reconstructed on the user's machine from the pinned upstream tarball (SHA-256 in `bootstrap.lock.json`) + this patch; `THIRD_PARTY_NOTICES.md` and `docs/RUNTIME_BOOTSTRAP_DESIGN.md` state this and point at the upstream. |
| `patches/0002…0004-wine-*.patch` | yes | **OPEN_OK (MIT diff over an LGPL-2.1-or-later work)** | Same reasoning as DXMT. Wine 11.0 corresponding source = pinned WineHQ tarball + these diffs. |
| `bootstrap.lock.json`, gate fixtures, catalogue JSON, shell scripts | yes | **OPEN_OK (MIT)** | YMM4M-authored. Contain only URLs, hashes, and YMM4M code. |
| YukkuriMovieMaker4 / Lite | no | **EXTERNAL_ONLY** | User supplies the official ZIP. YMM4M verifies name/size/SHA-256 and extracts it **inside the user's own environment**; never bundled, never auto-downloaded, never uploaded. Launching an interoperable host and extracting a user-obtained archive in-place is interoperability use, not redistribution. |
| AquesTalk (inside Standard YMM4) | no | **EXTERNAL_ONLY** | Present only if the user's own ZIP contains it. YMM4M installs no voice engine; `core.voice.aquestalk1` = `unsupported`. |
| Wine 11.0 (WineHQ source + Gcenx macOS base) | no | **EXTERNAL_ONLY (LGPL-2.1-or-later)** | Fetched by the user's machine directly from the pinned upstream URLs (with mirrors), built locally, never staged into the DMG. If a future release bundles a prebuilt runtime, the full corresponding-source + relink offer must be added first (tracked in `YMM4M.md`). |
| DXMT (3Shain, pinned commit) | no | **EXTERNAL_ONLY (LGPL-2.1-or-later)** | Same as Wine. |
| FreeType 2.14.3 (pinned source headers + Gcenx base dylib) | no | **EXTERNAL_ONLY (FTL or GPL-2.0-only; project elects FTL)** | Headers used only to compile Wine locally; the dylib comes from the Gcenx base the user downloads. Not in the DMG. |
| Noto Sans CJK JP (pinned commit) | no | **EXTERNAL_ONLY (SIL OFL 1.1)** | Downloaded into the user's Wine prefix only; `hb-subset` derives a JP face there. Never in the DMG or the repo. Reserved-Font-Name rules are respected (no renamed redistribution). |
| LLVM 15.0.7 x86_64 release | no | **EXTERNAL_ONLY (Apache-2.0 WITH LLVM-exception)** | A DXMT build tool only. Fetched from the pinned llvm.org release, SHA-256 verified, never staged into or shipped with the runtime. |
| NVIDIA NVAPI headers/libs (pinned commit) | no | **EXTERNAL_ONLY (MIT for nvapi.lib/nvapi64.lib)** | DXMT build input fetched by the user's machine. Notice required only if ever distributed. |
| mingw-directx-headers (pinned commit) | no | **EXTERNAL_ONLY (mixed permissive / LGPL header notices)** | DXMT build input fetched by the user's machine. |
| CrossOver 26.3 / its DXMT / its D3DMetal | no | **PRIVATE_ONLY** | Developer-local comparison oracle only. `bootstrap*.sh` and `stage-*.sh` refuse any input or output path containing `crossover`. Never copied, never bundled. |
| Microsoft .NET / Windows Desktop files inside YMM4 | no | **EXTERNAL_ONLY** | Part of the user's self-contained YMM4; never extracted for redistribution. |
| FFmpeg | no | **EXTERNAL_ONLY** | A system executable used during development probing only; not invoked by, or shipped in, the released app. |
| Apple VideoToolbox / Metal / AppKit / SwiftUI | yes (linked) | **CLOSED_OK** | System frameworks under the Apple SDK/EULA; linked, not redistributed. Standard for a macOS app. |

No `UNKNOWN` remains for anything in the DMG.

## 3. Trademark / naming / assets

- "YukkuriMovieMaker", "YMM4": used nominatively to describe interoperability
  ("a compatibility environment for opening YukkuriMovieMaker4"). `README.md`
  and the app both state YMM4M is unofficial and not affiliated with or endorsed
  by the YMM4 developer, and that YMM4 itself is not part of YMM4M.
- No YMM4 icon, logo, screenshot, or UI artwork is shipped in the DMG or the
  public repo. `evidence/` screenshots of YMM4's own UI stay out of the DMG;
  raw working screenshots are held only in the private common-rules store.
- "YMM4M" and the film-stack SF Symbol are YMM4M's own.

## 4. Distribution-model finding

The released artifact is **YMM4M's own MIT code plus YMM4M-authored diffs and
data**. Every third-party runtime component is obtained by the user's own
machine from a pinned upstream and built locally. This is the EXTERNAL_ONLY /
案3 model in `YMM4M-修正プラン.md` §4.1: it does not create redistribution
obligations for Wine/DXMT/fonts/LLVM on YMM4M, because YMM4M distributes none of
their bytes.

If a later release chooses to ship a prebuilt Wine+DXMT runtime tarball
(§4.1 案1), this audit must be redone: LGPL-2.1-or-later corresponding source +
scripts + a relink offer for Wine and DXMT, the FreeType notice, the Noto OFL
notice, and the LLVM Apache-2.0-with-exception notice all become mandatory in
the distribution.

## 5. Residual limitations recorded (not license blockers)

- No Developer ID signature or notarization (Developer ID unavailable). The DMG
  is ad-hoc signed; `build-development-dmg.sh` rejects an identity-signed app in
  this DMG. Gatekeeper's normal distribution gate is not satisfied; users must
  use Apple's per-app "Open Anyway".
- Windows-reference frame/audio comparison, the full Tier A editing/playback
  matrix, Win32Service crash-impact confirmation, and a clean-machine hardware
  matrix remain open and are disclosed in `STATUS.md` / `README.md`.

## 6. Release gate

For **v1.0.0 as an EXTERNAL_ONLY, ad-hoc-signed distribution of YMM4M's own
code**: license gate **PASS**. Every DMG component is OPEN_OK or a linked
system framework (CLOSED_OK); everything else is EXTERNAL_ONLY or PRIVATE_ONLY
and is provably absent from the artifact.
