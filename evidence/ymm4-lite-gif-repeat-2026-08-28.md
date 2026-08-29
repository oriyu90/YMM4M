# YMM4 Lite GIF repeat evidence (2026-08-28)

## Scope

This follow-up repeats the existing isolated JPEG/MP3/animated-GIF project on the
current clean runtime. It addresses the one historical DXMT pure-virtual stop
which did not reproduce in the first controlled retry.

- Project: `/Users/user/.ymm4m-dev/test-projects/media-formats.ymmp`
- Project SHA-256:
  `ad79eacf286a61a8908b915b37923acc2d41463da21c5d4fdf9d8c1d83a4f286`
- YMM4 Lite v4.55.1.1 executable SHA-256:
  `96d80e18c52f00f16b7568e96346e5f8dfa99b57b5a531e60ca0c645dda0a822`

The project is 1920x1080/60 fps. The installed user's restored FFmpeg writer
setting is 1280x720/30 fps, so a first diagnostic export correctly reproduced
the already documented dimension-mismatch `ReadbackToBuffer`
`ArgumentOutOfRangeException` after all 300 volume frames. This was not assigned
to GIF decoding.

To avoid changing the installed application or settings, an APFS clone was made
under `/private/tmp` and only the clone's public FFmpeg writer JSON was set to
1920x1080/60. The original writer-setting hash remained
`1ac0143ad5bb1211e1d5e93b78ad215059b9f93aa842b525283141eaefb9b7e6`.

## Result

Three sequential exports completed with process status zero. All three files are
byte-identical:

- SHA-256: `6a9277fb5d8a234345e8ed3aff25c1b259bd364e350e7d0c082ca4781df48838`
- duration: 5.000 seconds
- video: H.264, 1920x1080, 60 fps
- audio: AAC, 48 kHz, stereo

Decoded-frame MD5 values are identical between all runs and distinct across GIF
times:

- 0.5 s: `5997142171256fd2d6c4fb712adecc7e`
- 1.5 s: `da6c9735856c9b47d93f067f78fb2bd1`
- 2.5 s: `fc002a60a00a86aa9811c1fc41888a28`

The historical native stop has now failed to reproduce in four controlled runs
(the 2026-08-26 retry plus these three repeats). No compatibility patch is
justified. Animated GIF decode and matched-setting export are repeatable on the
current candidate; the broader image/media feature remains partial only for its
other declared format and Windows-reference gates.

