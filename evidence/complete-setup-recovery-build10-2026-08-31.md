# Complete setup and interrupted-state recovery — build 10 — 2026-08-31

## Scope

This pass verifies the normal-user setup contract: the user supplies an official
YMM4 Standard/Lite ZIP and a media/project directory; YMM4M prepares every other
managed component. Tests use isolated stores and do not modify a user project or
the active production runtime/prefix.

## Failures reproduced before the fix

1. A partial directory at the fixed runtime version destination made the
   bootstrap script refuse every retry because it correctly would not overwrite
   an existing path.
2. The same issue existed for an incomplete managed YMM4 release destination.
3. A regular directory or broken link at a managed `current` path could not be
   atomically replaced.
4. Fresh `wineboot --init` could start an interactive `winedbg` after an optional
   device-initialization exception. The orphan process retained the setup output
   pipe, so the app appeared to wait forever even after later setup work stopped.
5. A valid relative `YMM4/current -> versions/<release>` link was resolved against
   the wrong base during a repeated install and was misclassified as external.

## Implemented contract

- The main UI asks for the official YMM4 ZIP and media/project directory, then
  runs runtime, prefix, managed YMM4 copy, M: mapping, and final validation as
  one operation.
- AppStorage values are committed only after all of those checks pass.
- Invalid entries at exact YMM4M-managed version destinations and invalid
  internal channels are moved, not deleted, under the corresponding `Recovery`
  directory. Valid active/older versions are retained.
- A symlink escaping the managed `versions` directory still stops setup without
  modification.
- Setup disables only the interactive Wine debugger and always shuts down the
  prefix-scoped wineserver on success or failure. Wine command status, registry,
  WPF profile, font, marker, manifest, and binding validation remain mandatory.
- An existing M: symlink can be atomically changed to the directory explicitly
  selected in the complete-setup flow. A non-symlink conflict is still refused.

## Synthetic recovery matrix

- empty managed stores: pass
- partial runtime version destination: retained in `Runtimes/Recovery`, pass
- partial prefix version destination: retained in `Prefixes/Recovery`, pass
- regular runtime/prefix current channels: retained and repaired, pass
- external current symlink: refused and unchanged, pass
- partial known YMM4 destination: retained in `YMM4/Recovery`, copied again, pass
- regular YMM4 current channel: retained and repaired, pass
- repeated verified YMM4 install: reused, pass
- conflicting M: mapping without explicit replacement: refused, pass
- explicit complete-setup M: replacement: pass
- prefix initialization failure: wineserver `-k` and `-w` cleanup both observed

## Real isolated end-to-end result

The test created a new isolated home and deliberately placed partial runtime,
prefix, and regular `current` directories at the standard managed paths. It
reused only the pinned download/build caches and existing verified LLVM 15
toolchain; runtime staging and the Wine prefix were newly created.

- interrupted entries reported through `[repair]`: pass
- Wine/DXMT runtime stage and full host hash validation: pass
- fresh dedicated prefix, WPF profile, Noto JP font, binding: pass
- official YMM4 4.55.1.1 Standard ZIP safe validation and managed copy: pass
- selected isolated media directory mapped to `M:`: pass
- second complete setup reused the verified runtime/prefix/YMM4: pass
- active-pair validation after the second run: pass
- official YMM4 4.55.1.1 Lite ZIP install contract: pass

## Host gates

- Swift warning-as-error build: pass
- Swift contracts, normal and real recovery configurations: pass
- Python tests: 19/19
- shell syntax: pass
- compatibility registry: 20 features
- runtime lock/catalog validation: pass
- `git diff --check`: pass

This proves recovery on the current development machine and isolated stores. It
does not replace the remaining clean-machine hardware/OS matrix or final release
license gate.
