# GPU expectations (B4)

YMM4M does **not** run YMM4's whole UI on the GPU. Be explicit about where Metal
is and is not used so behaviour is not over-claimed.

| Layer | Path | GPU? |
|---|---|---|
| YMM4 / WPF window, controls, menus, dialogs | WPF forced onto its software rasterizer by the required `HKCU\Software\Microsoft\Avalon.Graphics\DisableHWAcceleration=1` prefix profile | **No — software rendering, by design.** This is the correctness baseline; hardware WPF paths under Wine were not reliable. |
| Editing / preview surface, Direct2D / Direct3D 11 device work | Source-patched DXMT translating D3D11 → Metal (`winemetal.so` / `winemetal.dll`) | **Partially — Metal.** This is the `development-only source-patched DXMT` edit profile in `runtime.lock.json`. It is what lets the preview advance and accept decoded frames. |
| FFmpeg decode / encode | FFmpeg software frame-upload path | **No** for decode/encode itself; decoded frames are then uploaded through the DXMT/Metal path for preview. |
| `wined3d-vulkan` / `wined3d-opengl` UI profiles | removed in v1.0.0 | n/a — the runtime is built `--without-vulkan` and without X11, so these could never work. |

What is **not** proven: that YMM4's real editing/preview workload issues Metal
work equivalent to Windows, that there are zero Metal validation errors across a
full session, and that a redistributable (non "development-only") DXMT profile
is ready. Those are `NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md` Phase B items
and are listed as open in `STATUS.md`.

One-line summary for users: **the UI is drawn in software; the preview and parts
of encoding use Metal through a development DXMT build.**
