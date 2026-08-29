# Finder integration implementation gate (2026-08-29)

## Scope

This record covers the native host's `.ymmp` handoff path, an end-to-end LaunchServices test, and development app-bundle construction. It does not claim a signed or notarized release or automatic `.ymme` installation.

The implementation is based on the documented project flow in the development specification and the already evidenced official positional `.ymmp` launch association. No YMM4 implementation was inspected or inferred.

## Implemented controls

- The app bundle registers `.ymmp` as an Editor document type and `.ymme` as a Viewer document type.
- SwiftUI receives open-URL events. Only `.ymmp` is handed to YMM4; `.ymme` currently stops with an explicit unvalidated message and is not modified.
- The user explicitly selects `YukkuriMovieMaker.exe` and a Media Root.
- The project must resolve inside Media Root. Symlink resolution is performed before containment checking, and paths containing a literal backslash are rejected as ambiguous Windows paths.
- The dedicated prefix's `dosdevices/m:` mapping is created only when absent. A different existing mapping is reported and never overwritten.
- The selected executable is SHA-256 classified. The pinned `4.55.1.1 Lite` executable is known-compatible; unknown executables require an explicit Continue choice; no build is labelled known-broken without a recorded failure.
- `tools/validate-runtime-lock.py` checks that the pinned executable hash remains present in the host compatibility policy.

## Reproducible checks

The following completed successfully:

```text
swift build
swift run YMM4MContractTests
python3 -m unittest discover tests -v
python3 tools/validate-runtime-lock.py
sh -n tools/build-app.sh
tools/build-app.sh /private/tmp/YMM4M-development-current-20260829.app
plutil -extract CFBundleDocumentTypes json ...
lipo -archs .../Contents/MacOS/YMM4M
```

The contract suite covers in-root mapping, rejection of outside/non-file paths, idempotent `M:` creation, preservation of a conflicting `M:` mapping, and unknown-executable classification. Standard Python discovery now finds all ten tests.

Development bundle results:

```text
architecture: arm64
executable SHA-256: ff4a0e00aa5ec3cd87c89c85596545b6d4567550e54db7dff7469b72dd4ede18
Info.plist SHA-256: 3d8766f8f68eef005d09d34722331b8f0cf23fe87f69ad7d635ed15aac5f7ee9
build-app.sh SHA-256: 91a4566e4415f382e5230bfa07b42a22c1a1873e0bb87bc0fde1c0d9d1274c7c
document extensions: ymmp, ymme
```

The bundle contains no Wine runtime, YMM4 binary, Microsoft runtime, font, or CrossOver component.

## LaunchServices result

The final bundle was opened with macOS `open -a ... core-japanese-noto.ymmp`, which uses LaunchServices' document-open path. The host received the URL, created the previously absent mapping

```text
M: -> /Users/user/.ymm4m-dev/test-projects
```

and launched the pinned YMM4 Lite executable. A pre-existing abnormal-termination recovery prompt appeared for a different video test project; the documented public `No` action was used so no recovery content was applied. YMM4 then reached its visible `YukkuriMovieMaker v4.55.1.1 Lite` main window. Its public settings recorded:

```text
MainWindowStates.0.ProjectPath = M:\\core-japanese-noto.ymmp
```

The app was closed through YMM4's normal main-window close. No unsaved prompt appeared. The source project SHA-256 remained `38df902010d211c3f383ed6b82aab9b5f3ebf7c3fb7324680276856cb532f5e2`, identical before and after. YMM4 and the dedicated Wine server exited, and the native host was then quit normally.

`FINDER001` therefore passes for `.ymmp`. `.ymme` automatic installation, signing, notarization, and release packaging remain separate unclaimed gates.
