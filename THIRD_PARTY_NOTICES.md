# Third-party notices

No third-party binaries are currently distributed by this repository.

| Component | Expected license / terms | Distribution status |
|---|---|---|
| YukkuriMovieMaker4 | Proprietary, official distribution terms apply | Never bundled |
| Wine 11.0 source / Gcenx macOS package | LGPL and other licenses in the selected source revision | Fixed inputs may be downloaded for local build; not bundled |
| FreeType 2.14.3 | FreeType License or GPL-2.0-only | Fixed source headers and base-package library are used for local Wine build; not bundled by the repository/DMG |
| DXMT e55ad281 | LGPL-2.1-or-later | Fixed source may be downloaded for local build; not bundled |
| NVIDIA NVAPI library files d08488f | MIT for nvapi.lib/nvapi64.lib | DXMT build input; not bundled as a repository binary |
| mingw-directx-headers 9df86f2 | MinGW-w64 mixed notices, including LGPL header terms | DXMT build input; not bundled as a repository binary |
| LLVM 15.0.7 x86_64 release (llvm.org) | Apache-2.0 WITH LLVM-exception | x86_64 build tool for DXMT; fetched on demand, never staged into or bundled with the runtime/DMG |
| Noto Sans CJK JP f8d1575 | SIL Open Font License 1.1 | Fixed font may be downloaded into the local Wine prefix; not bundled |
| CrossOver | Proprietary | Compatibility testing only; never bundled |
| FFmpeg | Build-dependent LGPL/GPL terms | System executable used in development only |
| .NET Windows Desktop Runtime | Microsoft terms | Never installed or bundled without deployment analysis |

Release packaging must regenerate a component inventory and include the exact upstream notices and source-offer obligations for every bundled runtime.
