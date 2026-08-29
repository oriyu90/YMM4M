# Project reopen isolation (2026-08-28)

## Scope and safety

This investigation used only YMM4's public project JSON, public UI/command-line
entry points, YMM4's own logs and Win32 window/accessibility APIs. No YMM4 binary
was modified or decompiled. Existing test projects were opened read-only and
were not overwritten. Fresh installations and prefixes used new paths under
`/Users/user/.ymm4m-dev`.

The deferred release license-audit document was not opened. In particular, the
AquesTalk plug-in was not downloaded, installed or redistributed.

## Locked inputs

- Runtime: `/Users/user/.ymm4m-dev/upstream-wine-dxmt-root-managed-surface`
- Current prefix: `/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix`
- Fresh prefix: `/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix-project001-20260828`
- Association-isolation prefix:
  `/Users/user/.ymm4m-dev/upstream-wine-dxmt-prefix-association-20260828`
- YMM4 Lite: v4.55.1.1
- YMM4 executable SHA-256:
  `96d80e18c52f00f16b7568e96346e5f8dfa99b57b5a531e60ca0c645dda0a822`
- Wine launcher SHA-256:
  `bad3b6126b6612680e26302c0e0b7e56d6c7036eac9bf6313878bdd9039b003f`
- `winemac.drv` SHA-256:
  `9c52f24507b692ef0fcc0dc5439b8bee63f869f04ef38494bf52e52ddfbfecf0`
- `dxgi.dll` SHA-256:
  `3c0b3efbcab0079e892eee61680ec5863adcc17541fd54942daf94b41784c973`

`runtime.lock.json`, the YMM4 ZIP inventory, the installed executable and the
runtime component hashes were checked before the project tests. The executable
hash formerly recorded in the lock contained a transcription error; the ZIP's
embedded executable and installed executable are byte-identical and the lock is
corrected to their shared hash above.

## Prefix and loader controls

The current and fresh prefixes produced the same result for both original
failure controls when invoked through YMM4's documented `--encode` path: project
deserialization completed, voice generation reached all frames, and processing
then failed later in the separate FFmpeg video stage. This establishes that the
files are readable and that the prefix is not the primary deserialization axis.
It does not claim that FFmpeg export passes.

A pristine YMM4 Lite copy and pristine prefix also logged the Community Explorer
`ObjectDisposedException` before any project was opened. Text-only and media
projects subsequently opened despite the same log entry, so the Explorer event
is not assigned as the reopen cause. The known WMI initialization messages are
likewise not assigned a cause.

## Item-type isolation

Projects were opened by passing the `.ymmp` path as YMM4's registered public file
association does (`"YukkuriMovieMaker.exe" "%1"`). The pristine association
dialog itself wrote that command to the isolated prefix registry.

| Project | Public item types | SHA-256 | Result |
|---|---|---|---|
| `core-empty.ymmp` | none | `77070ccae3d68f75f68c942f2c3c571b8bb2f9ec3b863abed5085b8db591f43f` | opened |
| `ime-entry.ymmp` | TextItem | `d7011ccc6dc0e10e701dca5f0042ee36464a150023df52286498acf69631ba85` | opened |
| `core-japanese-noto.ymmp` | AudioItem, ImageItem, TextItem | `38df902010d211c3f383ed6b82aab9b5f3ebf7c3fb7324680276856cb532f5e2` | opened |
| `ime-overlay-core-2026-08-27.ymmp` | VoiceItem | `394ae203fc0d9f614cd1bfc61d06a760d19f785d75b141c0dcc88321fa7759ea` | AquesTalk1 modal |
| `core-text.ymmp` | AudioItem, ImageItem, TextItem, VideoItem, VoiceItem | `2ebbd854e0efee964346f0d4658f9bbcbaf30acbd92753b890b326ae324a03da` | AquesTalk1 modal |

The two VoiceItem projects name the public character `Yukkuri Reimu`. The public
character settings resolve that character to
`YukkuriMovieMaker.Voice.AquesTalk1VoiceParameter`. On the current installation,
the apparent loading stop is an enabled, visible, owner-modal WPF window titled
`AquesTalk1`; the main YMM4 window is disabled while it is present. Its content
surface does not render through the current Wine/WPF path and exposes no MSAA
children. Sending Enter to the focused top-level window does not dismiss it.

The official YMM4 documentation says that YMM4 Lite is distributed without
AquesTalk1/2/10 and that those engines may be installed separately as plug-ins:

- <https://manjubox.net/ymm4/faq/etc/YMM4Lite/>
- <https://www.manjubox.net/ymm4/>

Therefore the two former PROJECT001 controls contain an optional engine which is
not present in the tested Lite installation. Installing it is not a valid
ordinary-development workaround because it changes the licensed component set.

## Repeated current-candidate result

`core-japanese-noto.ymmp`, a saved project with Japanese text, PNG and WAV items
but no optional voice engine, was reopened three times in the current runtime and
current prefix. Each iteration used a fresh Wine server, a 50-second observation
window and a public Win32 top-level-window dump. All 3/3 iterations ended at one
enabled `YukkuriMovieMaker v4.55.1.1 Lite` main window with no loading or modal
window.

The public YMM4 `RecentFiles` and `MainWindowState.ProjectPath` settings recorded
the isolated empty, text and media project paths after their successful opens.
No secret-bearing settings are copied into this evidence.

## Conclusion

The 2026-08-27 observation was real but was not a generic filesystem or project
deserialization regression. PROJECT001 passes 3/3 for a previously saved project
whose item types are supported by the tested vanilla YMM4 Lite installation.
Projects referring to the absent optional AquesTalk1 engine reach a distinct
AquesTalk1 modal whose WPF content does not render under the candidate; that is a
separate optional voice-engine/UI compatibility issue and remains unresolved.

