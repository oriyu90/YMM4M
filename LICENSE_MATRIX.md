# License matrix

This is the working inventory. The executed release audit for the v1.0.0 DMG is
`LEGAL-AUDIT-v1.0.0.md`, which resolves every `UNKNOWN` below for the artifact's
actual contents (EXTERNAL_ONLY: only YMM4M's own MIT code, scripts, patches,
fixtures, and catalogue are shipped). Any release that bundles a prebuilt
Wine/DXMT runtime requires a fresh audit before shipping.

| Component | Role | Current use | Intended distribution | Provisional status |
|---|---|---|---|---|
| YMM4M original Swift, C, C#, Python, and shell source | Project code | Built and tested | Source and signed app | OPEN_OK (MIT) |
| YukkuriMovieMaker4 / Lite | Windows application under test | User-supplied external copy | Never bundled | EXTERNAL_ONLY |
| AquesTalk components | Voice engine present only in standard YMM4 package | Not used; Lite preferred for baseline | Never bundled | EXTERNAL_ONLY |
| Wine 11.0 / 11.15 | Compatibility baseline | WineHQ source and Gcenx macOS package may be fetched to build a local candidate | Undecided; full corresponding-source/notices audit required before bundling | UNKNOWN |
| FreeType 2.14.3 | Wine font rendering | Pinned official source headers with the Gcenx base-package library for local build | Not bundled in repository/DMG; generated-runtime obligations require final audit | OPEN_OK (FTL or GPL-2.0-only; final integration audit required) |
| CrossOver 26.3 | Proprietary compatibility oracle | Developer-local testing only | Never bundled | PRIVATE_ONLY |
| DXMT supplied inside CrossOver | D3D11 comparison | Developer-local testing only | Never copied from CrossOver | PRIVATE_ONLY |
| Upstream DXMT source | Candidate D3D11 runtime | Local source/patch research | Undecided; LGPL obligations apply if selected | OPEN_OK (LGPL-2.1-or-later; final integration audit required) |
| NVIDIA NVAPI library files | Pinned DXMT submodule build input | Fetched from fixed upstream commit | Notice required if distributed | OPEN_OK (MIT for nvapi.lib/nvapi64.lib) |
| mingw-directx-headers | Pinned DXMT submodule build input | Fetched from fixed upstream commit | Multiple upstream notices must be preserved if applicable | OPEN_OK (mixed permissive/LGPL header notices; final integration audit required) |
| LLVM 15.0.7 x86_64 release | DXMT compile toolchain (build tool only) | Fetched from pinned llvm.org release, SHA-256 verified | Never staged into or bundled with the runtime/DMG | OPEN_OK (Apache-2.0 WITH LLVM-exception; build tool, not a runtime component) |
| D3DMetal supplied inside CrossOver | D3D11 comparison | Developer-local testing only | Never copied from CrossOver | PRIVATE_ONLY |
| Noto Sans CJK JP | Wine-only font fallback | Fixed upstream font may be downloaded into the local prefix | Not bundled in repository/DMG; notice required if distribution changes | OPEN_OK (SIL OFL 1.1; final audit still required) |
| FFmpeg system executable | Development encoder probe | External executable | Undecided; build configuration determines obligations | UNKNOWN |
| Apple VideoToolbox | Native encoding framework | System framework | Not redistributed separately | CLOSED_OK |
| Microsoft .NET / Windows Desktop files inside YMM4 | YMM4 self-contained runtime | Part of user-supplied YMM4 | Never extracted for redistribution | EXTERNAL_ONLY |

`UNKNOWN` is acceptable during development but is a hard release blocker. The final audit must resolve or remove every such entry.
