# Runtime fixture regression (2026-08-28)

The current CrossOver-free Wine 11.0 plus source-built DXMT runtime was retested
after the PROJECT001 isolation work. `tools/run-runtime-fixtures.sh` now builds
the public-API fixtures into a private temporary directory, launches them with an
empty allow-listed environment and the dedicated prefix, and removes the build
directory on exit.

Runtime:
`/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-managed-surface`

Prefix:
`/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix`

Results:

- D3D11 compute create/dispatch/readback: 100/100
- D3D11 context state: pass
- DXGI top-level and child-HWND swap chain/`IDXGISurface2`: pass
- Direct2D device6: pass
- Direct2D null effect input: pass
- Direct2D 3D transform and command-list contracts: pass
- Direct2D Japanese bitmap rendering: pass
- DirectWrite isolated/shared and empty/`ja-JP` fallback: pass; all map to
  `Noto Sans CJK JP` with complete glyph coverage

All eight processes exited zero. The local complete runner log is
`/private/tmp/ymm4m-runtime-fixtures-20260828.log`, SHA-256
`cd920827642e1e568329a9ba996ffb9fa791832eec9c3fc1dd1e937aa559b2fa`.
It is not committed because it contains verbose platform-driver inventory.

