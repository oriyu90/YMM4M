# Local compatibility test plan

Every result must record YMM4 ZIP SHA-256, runtime version/commit, graphics profile, macOS build, evidence paths, operator, timestamp, and status from the registry vocabulary.

## Core workflow

- `UI001`: start twice; verify splash, main window, menus, settings, clean close, no fatal exception.
- `FONT001`: exercise the documented Japanese/CJK/symbol/emoji string plus bold, italic, outline, shadow, ruby, line/character spacing, and mixed width.
- `IME001`: hiragana, katakana, conversion candidates, multi-segment conversion, cursor, backspace, and shortcut suppression during composition.
- `EDIT001`: 1280×720, 30 fps, 10-second project containing PNG, text, WAV, shape, motion, scale, rotation, fade, blur, outline, and shadow.
- `PROJECT001`: save, exit, launch again, reopen without mutation, and preview.
- `DND001`: drag files from Finder to the timeline, file fields, and project intake; verify containment, item creation, and no source mutation.
- `CLIP001`: copy and paste plain text, images, YMM4 items, and effects; verify type fidelity, ordering, and undo/redo.
- `MEDIA001`: PNG, JPEG, and GIF import and visual comparison.
- `AUDIO001`: WAV/MP3, mono/stereo, 44.1/48 kHz, volume/pan/speed/pitch and A/V sync.
- `VID001`: H.264/AAC MP4 import, thumbnail, seek, split, playback, save/reopen.
- `VID002`: compare decoded frames 0, 30, 60, 150, and 299 against Windows reference.
- `EXPORT001`: YMM4 FFmpeg software export, decoded RGB comparison, duration and audio-timing comparison.

## Bridge

- `BRIDGE001`: authenticate over loopback with a random token, reject a bad token and oversized packets, capture validated frame/audio bytes unchanged, cancel, and finalize.

Do not run a later milestone when PE architecture or .NET deployment is `UNKNOWN`, the project is corrupted, the plugin ABI or frame format is unknown, or a rendering difference has an unknown cause.
