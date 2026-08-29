# YMM4 Lite JPEG, MP3, and GIF evidence (2026-08-26)

## Scope

The tests used YMM4 Lite 4.55.1.1 through its public media buttons, standard file dialog, save shortcut, normal close/reopen path, and command-line encoder. All assets and projects are isolated fixtures under `/Users/user/.ymm4m-dev`. No YMM4 implementation was inspected or decompiled.

Test assets:

- JPEG: `/Users/user/.ymm4m-dev/test-media/core-image.jpg`, SHA-256 `6ddd63e6e6576beeed89eac3f755f412731b94ff81b293fa5ca47f6527d4c844`
- MP3: `/Users/user/.ymm4m-dev/test-media/core-audio.mp3`, SHA-256 `d282e7bfd8f9e073189679e8cc1fd652c187d1dbbe20fd279a75c3ff0699efac`
- GIF: `/Users/user/.ymm4m-dev/test-media/core-animated.gif`, SHA-256 `6e98c7f79da3b36b6a208d13332e68a3be81e33fb9526f9125a6b8a7c04a4d52`

The GIF is a three-second 320x180/5 fps animation derived from the existing synthetic video fixture.

## JPEG and MP3 result

The JPEG and MP3 were added to `/Users/user/.ymm4m-dev/test-projects/media-formats.ymmp` through the corresponding public media buttons and file dialog. The saved project has SHA-256 `b47109a983b343dd6a4dfa022143f7923389f47d31c29c6d296543d6c9700a31` and retains:

- an `ImageItem` for the JPEG at frame 0, length 300;
- an `AudioItem` for the MP3 at frame 0, length 181.

The project closed normally and reopened without a recovery prompt. With project and writer settings matched at 1920x1080/60, command-line encoding exited successfully and produced:

- output: `/Users/user/.ymm4m-dev/exports/media-jpeg-mp3-roundtrip.mp4`
- SHA-256: `26e2d5345457aa176c47f5d4d6c80334a33a68bc0d491d05d4afb329cb1656d2`
- duration: 5.000 seconds
- video: H.264, 1920x1080, 60 fps
- audio: AAC, 48 kHz, stereo
- decoded audio: 240,000 samples, RMS -29.61 dBFS, peak -23.88 dBFS

The one-second evidence frame visibly contains the JPEG item and is stored at `evidence/ymm4-lite-jpeg-mp3-roundtrip-frame-2026-08-26.png`. Audible speaker-output verification remains open; the non-silent decoded export proves only the file-processing path.

## GIF result

The image button did not accept the GIF as an image item and left the file dialog open; no project mutation occurred. The video button is the working import path. A first attempt made after several rejected file-dialog submissions ended before persistence and recorded:

```text
err:   Pure virtual function called
wine: Unhandled illegal instruction at address 00006FFFFB37AB3D (thread 0460), starting debugger...
```

Wine started its debugger for guest process 216, the active YMM4 process. The next launch displayed YMM4's abnormal-termination recovery prompt. The project on disk remained valid. The stderr text comes from DXMT's open-source `__cxa_pure_virtual` handler, but it does not identify the destroyed object or caller.

A clean controlled retry did not reproduce the failure. The GIF then imported through the video button and persisted as a `VideoItem` at frame 0 with length 180. The project SHA-256 after that save is `ad79eacf286a61a8908b915b37923acc2d41463da21c5d4fdf9d8c1d83a4f286`.

With all temporary diagnostics removed, the final candidate exported the JPEG, MP3, and GIF together:

- output: `/Users/user/.ymm4m-dev/exports/media-jpeg-mp3-gif-final.mp4`
- SHA-256: `f4edf03a1da97391140ab59407b12ebfced2278983c70622313408175d5e2aeb`
- duration: 5.000 seconds
- video: H.264, 1920x1080, 60 fps
- audio: AAC, 48 kHz, stereo
- process exit: 0

Frames at 0.5, 1.5, and 2.5 seconds have distinct hashes and visibly different synthetic-test positions, establishing animated GIF decoding rather than a static first-frame result. The 0.5-second frame is stored at `evidence/ymm4-lite-gif-roundtrip-frame-2026-08-26.png`.

The earlier pure-virtual failure is retained as an unresolved intermittent observation, not attributed to GIF and not used to justify a compatibility-code change. Repetition and a resolved public-API call site are still required before any fix.
