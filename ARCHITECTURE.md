# Architecture

YMM4M keeps four graphics concerns separate: WPF/D3D9 UI, D2D/D3D11 editing, D3D12 compute, and WebView2 composition. The Swift host never invokes Wine directly from UI code; it talks through `RuntimeBackend`.

```text
YMM4M host (ARM64)
  ├─ Runtime manager ── Rosetta/x86_64 Wine ── official YMM4
  ├─ Installer and M: drive mapping
  ├─ Native text input ── private UTF-8 handoff ── Unicode input helper
  ├─ Diagnostics
  └─ Bridge session ── localhost authenticated IPC ── YMM4 plugin
                       └─ native encoder ── FFmpeg / later VideoToolbox
```

Rosetta Wine is the production candidate only on supported macOS releases. ARM64 Wine plus FEX remains research-only. The native encoder is a separate process because translated x86_64 and ARM64 code cannot be mixed in one process.

The native text-input path is a version-scoped compatibility workaround, not a YMM4 patch. Composition stays in the ARM64 macOS host; only text explicitly committed by the user crosses into the tested YMM4 dialogue field. The handoff file is created with owner-only permissions, removed after the helper exits, and its contents are not placed in process arguments.
