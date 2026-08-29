# YMM4 Lite video split follow-up (2026-08-28)

## Inputs and safety

- Project: `/Users/user/.ymm4m-dev/test-projects/video-import-720p30.ymmp`
- SHA-256 before and after:
  `14f4cb7974b45c32c79bfe5b2733bdea110f4c1d2bf4e239a48165e38efa1924`
- Item: one public `VideoItem`, frame 0, length 90, layer 0
- Source: `Y:\.ymm4m-dev\test-media\core-video.mp4`
- Project settings: 1280x720, 30 fps, 3 seconds

The original project was not saved or overwritten. The test used only the public
YMM4 UI and documented input actions.

## Preview and timeline

After public direct-open and a Home seek, frame 0 visibly rendered the synthetic
video pattern in the preview. Maximizing the public main window exposed the
timeline's single blue `core-video.mp4` item from frame 0 through frame 90.

Tracked screenshot: `ymm4-lite-video-preview-home-2026-08-28.png`

- SHA-256: `c164fd9003ab6a3c432a2f6716ced56d3fd09b7cadff4c53a4b5716cfd3c878e`

The timeline item was too short at the tested zoom to establish image-thumbnail
generation independently of its label, so the thumbnail sub-gate remains open.

## Split

The official YMM4 documentation describes the `Split at playback position`
operation, and YMM4 v4.55.1.1's public File menu exposes its current shortcuts.
The official release note also documents Ctrl- or Shift-middle-click item split:

- <https://manjubox.net/ymm4/faq/editing/%E5%80%8D%E9%80%9F%E3%83%BB%E9%80%86%E5%86%8D%E7%94%9F%E7%B7%A8%E9%9B%86%E3%81%99%E3%82%8B/>
- <https://manjubox.net/ymm4/release/4.30.0.0/>

A Win32 `SendInput` helper brought the YMM4 main window forward and issued a
Ctrl-middle-click at the midpoint of the visible video item. A subsequent normal
close produced YMM4's standard owned confirmation dialog:

```text
title=Confirm
The project is not saved.
Do you want to save it?
buttons=&Yes, &No, Cancel
```

No other state-changing action occurred before this first close request; Home
seek and window maximize had not marked the project dirty. This establishes that
the documented split action changed the in-memory project. The No button was
then selected so the original project remained byte-identical.

The public `Save project as` command advertises Ctrl+Shift+S. In the current Wine
candidate it opens a blank custom WPF top-level picker whose edit control does not
receive focus through public Win32 focus APIs. The attempted isolated Save As did
not create a file. Therefore split persistence/reopen is not claimed and remains
part of the editing/UI picker gate rather than the video decode gate.

