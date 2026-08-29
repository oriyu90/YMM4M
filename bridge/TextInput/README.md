# Native text-input bridge

`win32-text-commit.c` is a narrowly version-scoped workaround for the tested
YMM4 Lite v4.55.1.1 dialogue field. The native ARM64 host receives macOS text
input, writes only the committed UTF-8 text to a private temporary file, and
launches this helper in the already validated Wine prefix. The helper reads the
file, activates the visible tested YMM4 window, clicks the evidence-backed
dialogue-field position, and sends UTF-16 code units with documented Win32
`SendInput`/`KEYEVENTF_UNICODE` events.

It does not inspect or patch YMM4, does not press the Add button, and does not
claim compatibility with a different YMM4 version or layout. The executable is
a generated build artifact and must not be committed.

Local build example:

```sh
x86_64-w64-mingw32-gcc -municode -O2 -Wall -Wextra -Werror \
  -Wl,--no-insert-timestamp \
  -o runtime/build/ymm4m-text-commit.exe bridge/TextInput/win32-text-commit.c
```
