# Development runtime evidence: 2026-08-25

Host: Apple M3 Ultra, macOS 26.4, Rosetta 2 installed, Xcode 26.6 selected.

Subject: user-supplied YukkuriMovieMaker v4.55.1.1 Lite. Runtime: isolated local development staging root using source-built DXMT at `e55ad281c60be97f8815b5848e57cfd9f967d759` and Wine Direct2D at `db11d0fe6a169c457e23d007e20404643d067aa8` with the patches in `patches/`.

The staging root was copied from the developer's local CrossOver installation. The original `/Applications/CrossOver.app` was not modified. The staging root and CrossOver components are not distributable and are not part of this repository.

## Passed checks

- Swift build and `YMM4MContractTests`
- Seven Python unit/integration tests
- `dxgi-surface2-reproducer.exe`
- `d3d11-context-state-reproducer.exe`
- `d2d-null-effect-input-reproducer.exe`
- `d2d-device6-reproducer.exe`
- `d2d-3d-transform-reproducer.exe`, including CPU-readback pixels, nested bounds, target offsets, transparent Clear, and image-brush replay
- Fifteen consecutive Direct2D create/render/destroy cycles
- Public-UI project open, save, normal close, and reopen
- Public-UI PNG and WAV import
- Preview playback advancing to approximately 2.2 seconds with the PNG visibly rendered
- YMM4 log evidence for WAV open, 48 kHz resample, seek, and first read
- YMM4 FFmpeg software export to H.264/AAC, 1920x1080 at 60 fps, 48 kHz stereo, duration 5.000 seconds
- Extracted frame at 2 seconds with the 640x360 PNG centered at x=640..1279 and y=360..719
- Non-silent exported audio (peak approximately -26.27 dBFS, RMS approximately -32.33 dBFS)

The Wine child environment was launched from an allowlist. Contract and Win32 probes confirm that arbitrary API-token, SSH-agent, and dynamic-loader variables are not inherited.

## Open gates

Japanese IME entry, video media, audible playback, effects, Windows-reference render/export comparison, OS/hardware matrix, clean redistributable runtime construction, packaging, signing, notarization, update/rollback, and the release-time license audit are not complete.
