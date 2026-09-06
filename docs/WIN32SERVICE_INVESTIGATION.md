# Win32Service.exe / WmiNetUtilsHelper crash banner — investigation (B1)

Status: **static analysis complete; runtime disabling deferred to hardware
verification.** No launch-path behaviour was changed for v1.0.0.

## Symptom

When YMM4 starts under the clean Wine 11.0 + source-patched DXMT runtime, the
YMM4 log records, repeatedly:

```
YukkuriMovieMaker.Win32Service ... WmiNetUtilsHelper ... 初期化に失敗
```

and a Mono/.NET native-crash banner is printed for
`YukkuriMovieMaker.Win32Service.exe`. YMM4's main window still opens, the 8
runtime fixtures pass, and the recorded Tier A results (`compatibility/
features.yaml`) were all produced with this banner present.

## What is actually happening

- `WmiNetUtilsHelper` is the interop shim `System.Management` uses to reach
  WMI (`winmgmt` / `wbemprox` in Wine). YMM4's `Win32Service` helper process
  queries WMI at startup — almost certainly for hardware / GPU / codec
  enumeration and update/telemetry housekeeping, none of which is on the
  critical path for opening a project, previewing, or exporting.
- Wine's WMI providers are partial. `Win32_VideoController`,
  `Win32_Processor` and similar classes are commonly incomplete, so the
  managed initializer throws, `Win32Service.exe` faults, and .NET prints the
  native banner. The parent YMM4 process catches the missing service and
  continues.
- The banner is therefore **noise from a non-essential companion process**, not
  a fault in the compatibility runtime. It is loud because the default
  `WINEDEBUG` used to force `+seh` (fixed in v1.0.0: the default is now `-all`,
  so the banner is far quieter already).

## Options considered

1. **Disable the service by default** via
   `WINEDLLOVERRIDES="…;winemgmt=d;wbemprox=d"` or by refusing to launch
   `Win32Service.exe`. Risk: YMM4 may use WMI results for GPU-capability
   decisions or codec discovery; suppressing them globally could silently
   change encoder/preview behaviour. This cannot be confirmed safe without a
   Windows reference machine and the full Tier A matrix, which are the open
   `NEXT_SESSION_FULL_AUDIT_RELEASE_RUNBOOK.md` Phase C/D items.
2. **Upstream Wine WMI patch** to make the queried classes return benign
   values. Larger surface; only worth it if option 1 shows a real feature
   dependency.
3. **Do nothing to the launch path, quiet the logs, document it.** Chosen for
   v1.0.0.

## Decision for v1.0.0

- Launch environment unchanged apart from the `WINEDEBUG` default, which already
  removes the `+seh` banner spam in normal use.
- No feature in `compatibility/features.yaml` is currently blocked *by* this
  banner: every recorded Tier A `pass` / `partial` result was obtained with it
  present.
- Tracked follow-up (see `YMM4M.md` rule 6 / runbook Phase C):
  1. On a Windows reference machine, capture which WMI classes
     `Win32Service.exe` queries and what YMM4 does with the results.
  2. If nothing user-visible depends on them, add
     `winmgmt=d,wbemprox=d` to `RosettaWineBackend.launchEnvironment`'s
     `WINEDLLOVERRIDES` behind a contract test, with `YMM4M_KEEP_WIN32SERVICE`
     as an escape hatch.
  3. Otherwise, carry a minimal Wine WMI patch as `patches/0005-*`.

## Reproduction

```bash
YMM4M_WINEDEBUG='+seh,+tid' tools/run-ymm4.sh   # banner returns with verbose tracing
tools/collect-wine-log.sh                        # capture the WmiNetUtilsHelper lines
```
