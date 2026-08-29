# Runtime patches

Patches are kept only after a standalone reproducer identifies a runtime defect. Each patch must name its upstream revision, test, removal condition, and validation state.

`0001-dxmt-yymm4-compat.patch` targets DXMT commit `e55ad281c60be97f8815b5848e57cfd9f967d759`. It contains the complete source delta used by the current development runtime: `IDXGISurface2`, D3D11 context-state support, synchronous pipeline dependency execution, correct device initialization before `ArgumentEncodingContext` creates helper compute pipelines, and preference for the layout-independent Wine Metal-view bridge while retaining the existing fallback.

`0002-wine-d2d1-yymm4-compat.patch` targets Wine commit `db11d0fe6a169c457e23d007e20404643d067aa8`. It includes the upstream null-effect-input fix and the Direct2D effect, bounds, command-list, image-position, transparent-Clear, and nested-image changes exercised by the public-API reproducers.

`0003-wine-dwrite-locale-fallback.patch` targets the same Wine commit. It keeps explicit DirectWrite locale mappings separate from the neutral mapping and includes a Wine regression assertion. The standalone `MapCharacters` reproducer now selects Noto Sans CJK JP for Japanese in all tested factory/locale combinations.

`0004-wine-macdrv-metal-view-bridge.patch` targets the same Wine commit. It exports two small macOS-driver entry points that create and release an opaque Metal-view handle for either a top-level or child HWND through Wine's existing managed client-surface lifecycle. This avoids exposing the private `macdrv_win_data` layout to DXMT and keeps child-view position updates in Wine's established OpenGL/Vulkan path.

All four patches compile and pass their standalone reproducers. The CrossOver-derived staging root must never be shipped. A separate CrossOver-free Wine 11.0 + source-built DXMT candidate now passes the eight-fixture suite and YMM4 Lite startup, but release adoption still requires reproducible runtime assembly, the remaining Tier A workflows, packaging/signing, and the release-time license audit.
