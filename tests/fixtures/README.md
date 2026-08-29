# Black-box Windows diagnostic fixtures

`wpf-ime-reproducer/` is a standalone public-WPF input field that records committed
text and WPF text-composition events. It contains no YMM4 references and is used to
separate a Wine/WPF IME problem from YMM4-specific behavior. Publish output is kept
outside the repository because a self-contained test build includes Microsoft .NET
runtime files that are not project distribution artifacts.

For the YMM4 Lite 4.55.1.1 comparison, publish the fixture for `win-x64` as
self-contained. The project pins .NET 10.0.10 so its `PresentationCore.dll` and
`PresentationFramework.dll` match the corresponding YMM4-provided runtime files.
Keep the publish directory under the isolated development area, never under the
release staging root.

```sh
dotnet publish tests/fixtures/wpf-ime-reproducer/WpfImeReproducer.csproj \
  -c Release -r win-x64 --self-contained true \
  -o /Users/user/.ymm4m-dev/wpf-ime-reproducer-net10.0.10
```

These small programs exercise documented Windows APIs only. They do not link to, inspect, or decompile YMM4 implementation code.

Run the complete eight-fixture runtime regression with `tools/run-runtime-fixtures.sh`.
The runner requires explicit `YMM4M_WINE` and `YMM4M_PREFIX` paths, builds only
in a private temporary directory, and starts Wine from an allow-listed empty
environment.

- `d2d-device6-reproducer.cpp` isolates the preview-blocking `ID2D1Device6.CreateDeviceContext` call.
- `dxgi-surface2-reproducer.cpp` isolates the DXMT `IDXGISwapChain.GetBuffer(IDXGISurface2)` failure with the same two-buffer flip-sequential swap-chain shape observed in the runtime log, for both a top-level HWND and a visible child HWND.
- `d3d11-context-state-reproducer.cpp` verifies that DXMT can swap to a new D3D11 context state, return the previous state, restore it, and handle a null-state no-op.
- `d3d11-compute-pipeline-reproducer.cpp` repeatedly creates a D3D11 device and compute pipeline, dispatches a documented compute shader, and verifies CPU-readback values.
- `d2d-null-effect-input-reproducer.cpp` verifies that Wine Direct2D accepts the documented null effect input used to disconnect an input image without dereferencing it.
- `d2d-3d-transform-reproducer.cpp` verifies 3D-transform properties, effect and nested command-list bounds, command-list target offsets, transparent-Clear composition, non-bitmap image brushes, and CPU-readback pixels.
- `d2d-japanese-text-reproducer.cpp` renders Japanese through a DirectWrite layout, Direct2D command list, and GPU-backed target, matching the YMM4 text path.
- `win32-msaa-dump.cpp` probes the public Microsoft Active Accessibility tree for repeatable UI validation when WPF UI Automation is unavailable.
- `win32-save-shortcut.c` sends the documented Ctrl+S shortcut to the YMM4 main window so the save/reopen path can be validated without relying on macOS screen capture.
- `win32-open-shortcut.c` sends the documented Ctrl+O shortcut to the YMM4 main window so an isolated project can be selected through YMM4's public file-open workflow.
- `win32-save-dialog-submit.c` enters a caller-supplied isolated test path into the native save dialog and submits its localized Save button.
- `win32-add-text-item.c` clicks the standard text-item toolbar position relative to the YMM4 client area for a black-box editing probe.
- `win32-enter-dialogue.c` enters a fixed Japanese/ASCII string into the visible dialogue field using documented Unicode input events and clicks the visible Add button; `--focus-only` and `--add-only` split those actions for IME probes.
- `win32-add-media-item.c` clicks the visible video, image, or audio toolbar button relative to the YMM4 client area.
- `win32-file-dialog-submit.c` enters a caller-supplied isolated test-media path into the visible standard open-dialog edit control and clicks its localized Open button; `--cancel` closes a rejected-format dialog.
- `win32-preview-play.c` clicks the visible preview play control and leaves playback running long enough to exercise video and audio.
- `win32-preview-home.c` sends the documented Home key to seek the visible preview to frame zero.
- `win32-close-main-window.c` requests a normal main-window close so save/reopen tests do not terminate YMM4 through the runtime server.
- `win32-confirm-save.c` clicks the standard Yes button on the visible unsaved-project confirmation dialog.
- `win32-decline-recovery.c` clicks the standard No button on the visible crash-recovery confirmation dialog.
- `win32-submit-wpf-confirmation.c` accepts the selected option in YMM4's WPF confirmation window with the documented Enter key.
- `win32-close-aquestalk.c` closes the visible optional AquesTalk1 installation notice without changing voice settings.
- `win32-environment-probe.c` reports only the names of sensitive host variables inherited by Wine, never their values.
- `win32-ime-state-probe.c` records the public Win32 foreground/focus/caret windows and IMM context, open, conversion, composition, and candidate-window state for black-box comparison.
- `win32-dwrite-font-probe.cpp` verifies that the isolated DirectWrite system collection resolves the Japanese fallback and the `Meiryo` alias to non-missing Japanese glyphs.
- `dwrite-font-fallback-reproducer.cpp` calls the documented system `MapCharacters` path with an Arial base family and verifies that Japanese is mapped to a font containing non-missing glyphs.
- `win32-window-dump.c` records public top-level and child window metadata.
- `win32-dialog-probe.c` dismisses the clean-prefix file-association prompt without registering associations.
- `win32-window-capture.c` evaluates `PrintWindow` behavior for WPF windows.
- `win32-uia-dump.cpp` probes whether Wine exposes the YMM4 UI Automation tree and records the unavailable tree-walker HRESULT; passing `exception` targets YMM4's exception window.
- `win32-open-project-command.c` sends a caller-supplied project path through the visible public Open command path.
- `win32-maximize-main.c` maximizes the public main window for coordinate-relative timeline probes.
- `win32-ctrl-middle-main.c` performs the officially documented Ctrl-middle-click split at a caller-supplied main-client coordinate.
- `win32-cancel-confirmation.c` cancels the visible unsaved-project prompt so an isolated source project remains unchanged.
- `win32-save-as-shortcut.c`, `win32-dialog-key.c`, and `win32-type-blank-window.c` isolate the public Save As shortcut and the current blank custom WPF picker behavior.
- `win32-click-main-client.c`, `win32-click-screen.c`, `win32-close-titled-window.c`, and `win32-accept-confirmation.c` are generic black-box window interaction probes; callers must record the exact visible target and must not use them to infer undocumented behavior.

Example build for the Direct2D reproducer:

```sh
x86_64-w64-mingw32-g++ -std=c++17 -O2 -Wall -Wextra -Werror \
  tests/fixtures/d2d-device6-reproducer.cpp \
  -o runtime/build/d2d-device6-reproducer.exe \
  -ld3d11 -ld2d1 -ldxgi -lole32 -static-libgcc -static-libstdc++
```
