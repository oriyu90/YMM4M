# YMM4 Lite video import and round-trip evidence (2026-08-26)

## Scope

This test used YMM4 Lite 4.55.1.1 through its public UI and command-line interface. It did not inspect or decompile YMM4 implementation code. All project files are isolated fixtures under `/Users/user/.ymm4m-dev`; no user project was modified.

The source asset was a three-second H.264/AAC MP4:

- path: `/Users/user/.ymm4m-dev/test-media/core-video.mp4`
- SHA-256: `a44b0d12de0e1e48cf1000b128ada23164efbe1d0891ca21b756d5f43e3f9ed2`
- video: 640x360, 30 fps, YUV420P
- audio: AAC, 48 kHz, mono

## Import, save, and reopen

The video was added through YMM4's media-item command and standard file dialog, saved with the normal shortcut, closed normally, and reopened. The saved fixture has SHA-256 `b1a4518735f8d860f03e5d4c62089f25fe1e429a65ba999b9f0efa5ff9a8a226` and retains a `VideoItem` for the source path at frame 0 with length 180.

After reopen and preview playback, the application log records:

- FFmpeg video open and stream discovery at 640x360/30 fps for three seconds;
- FFmpeg audio open, 48 kHz resampling, seek, and read;
- D3D11VA initialization failure kept separate from the subsequent DXVA2 attempt;
- a decoded `AV_PIX_FMT_YUV420P` frame converted to BGRA with `sws_scale` and copied into the Direct2D bitmap.

The DXVA2 surface path is not implemented by the current development runtime, so the source ultimately uses FFmpeg's software-frame upload path. No claim of hardware decoding is made.

## Export-setting matrix

The first command-line export failed with `ArgumentOutOfRangeException` in YMM4's `ReadbackToBuffer`. A temporary Wine Direct2D trace showed that the exception occurred before `ID2D1Bitmap1::GetPixelSize` or `Map`, so no Direct2D compatibility change was made.

A controlled matrix then established that the failure was caused by a test-setting mismatch, not by the imported video:

| Project | FFmpeg writer setting | Result |
| --- | --- | --- |
| 1280x720, 60 fps | 1280x720, 30 fps | success; 1280x720 H.264/AAC |
| 1280x720, 30 fps | 1280x720, 30 fps | success; 3.000-second H.264/AAC |
| 1920x1080, 30 fps | 1280x720, 30 fps | `ReadbackToBuffer` range exception |
| 1920x1080, 60 fps | 1920x1080, 60 fps | success; 3.000-second H.264/AAC |

The writer setting was backed up before the matched 1920x1080/60 test and restored byte-for-byte afterward.

## Matched round trip

With project and writer settings both at 1920x1080/60, the isolated video-only project exported successfully:

- output: `/Users/user/.ymm4m-dev/exports/video-import-matched-1080p60.mp4`
- SHA-256: `12bee5f407a692d219bdcc4932d9b6ec94b7072084db447bd369bc0703cbaa7d`
- duration: 3.000 seconds
- video: H.264, 1920x1080, 60 fps
- audio: AAC, 48 kHz, stereo
- process exit: 0

The one-second output frame visibly contains the imported test pattern at the position produced by YMM4's default item transform. Comparing the 640x360 item region against the source frame gives PSNR 37.624 dB after the additional lossy encode. The recorded frame is `evidence/ymm4-lite-video-roundtrip-frame-2026-08-26.png`.

## Remaining VID001 work

Import, preview decode/upload, save, normal close, reopen, and matched-setting export are verified. Thumbnail behavior, split editing, broader codecs, audible speaker output, and Windows-reference comparison remain open, so the feature stays `partial`.
