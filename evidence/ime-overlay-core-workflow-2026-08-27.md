# Native IME overlay core-workflow follow-up (2026-08-27)

## Scope

This follow-up used the clean Wine 11.0/DXMT candidate, its dedicated prefix,
YMM4 Lite v4.55.1.1, the native committed-text bridge, and a new isolated test
project. No user project or YMM4 binary was modified.

## Add and save

The bridge transferred `日本語` to the visible dialogue field. The public Add
button created a five-second voice/text item whose preview visibly rendered the
same text. After dismissing the optional AquesTalk notice, File > Save project
as and the standard save dialog created:

```text
/Users/user/.ymm4m-dev/test-projects/ime-overlay-core-2026-08-27.ymmp
SHA-256 394ae203fc0d9f614cd1bfc61d06a760d19f785d75b141c0dcc88321fa7759ea
```

The public project JSON contains one `VoiceItem` with `Serif` equal to `日本語`,
frame 0, layer 0, and length 300. A scan against credential-like values in the
host environment returned zero matches.

Tracked image: `ime-overlay-project-saved-2026-08-27.png`

- SHA-256: `e41ef8a1db3e4c2420dd15d9c319da681d5c5475de273bfe1b303083460f0319`

## Reopen regression

After a normal main-window close, reopening the saved test project through File
> Open project and the standard open dialog did not complete. The visible
`Loading project file` window remained for more than one minute. The current
candidate was then restarted and the previously passing isolated control
`core-text.ymmp` was opened through the same public path. It also failed to
complete and eventually exposed a blank loading window with a Close button.

YMM4's own current log contains the already observed WMI initialization errors
and an `ObjectDisposedException` from the bundled Community Explorer tool's
`ExplorerViewModel.Refresh` path. The log does not tie either event to project
deserialization, so no cause or workaround is assigned and no compatibility
patch is made.

Tracked control-failure image: `project-reopen-control-failure-2026-08-27.png`

- SHA-256: `7cb6dcf50d0e76e663fbe244e6afb3c0e0b0d7a24cb6df55937ad41c26219437`

`PROJECT001` is downgraded to `fail` for the current clean-candidate state. The
native overlay add/save portion passes, but the complete edit/save/reopen gate
does not.

## Launch-environment correction

One discarded manual launch inherited the caller's full host environment. The
project's product backend already uses an allow-list, but the developer
`tools/run-ymm4.sh` path did not. The script now starts from an empty environment,
passes only the same non-secret host basics and dedicated Wine settings, rejects
the filesystem root and home directory as prefixes, and derives library paths
from the configured validated Wine runtime. All subsequent manual launches used
the allow-listed environment.
