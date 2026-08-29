# Runtime baseline recipe

Use one official YMM4 archive hash and one reference project for every run. Create a fresh dedicated prefix for each candidate.

1. Wine 11.0 Stable: WPF software rendering first, then WineD3D Vulkan.
2. Wine 11.16 Development: the same profiles and tests.
3. CrossOver 26.3.0: WineD3D, DXMT, and D3DMetal as a compatibility oracle only.

Record exact builds; never relabel the newest version as the release candidate without results. CrossOver and D3DMetal must not enter the public distribution. OpenGL is diagnostic-only. D3D12 and WebView2 are separate investigations.

