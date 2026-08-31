# Automatic setup debug / development build 9 — 2026-08-31

## Reported symptom

After pressing `互換環境を自動セットアップ`, the runtime directory remained empty and
opening it produced a missing `ymm4m-runtime.json` message.

## Reproduced causes

1. The app waited with `readDataToEndOfFile()`, so no download/build output was
   shown until the child process exited. The runtime is intentionally staged
   only after all downloads, Wine/DXMT builds, and validation, so an empty
   destination looked like a hang.
2. The standard source/build roots were under `Application Support`. Wine's
   `CROSSCFLAGS` split its reproducibility mappings at that whitespace and
   configure reported `x86_64 PE cross-compiler not found` even though the
   compiler existed.
3. GitHub's DXMT source archive retained empty submodule directories. Moving the
   pinned NVAPI and DirectX-header archive roots onto them nested each dependency
   one level too deep, and Meson stopped at its submodule check.
4. Homebrew MinGW GCC 16.2 produces a different complete runtime hash set than
   the prior GCC 15.2 audit. The new set and its `winemac.so` loadable-image hash
   were recorded as a separate all-or-nothing verified variant.
5. The Japanese text fixture used an undeclared developer-only `Y:` mapping.
   Standard prefixes correctly lacked it, so BMP output failed independently of
   rendering. The fixture now writes into its temporary directory through `Z:`.

## Implemented corrections

- Stream phase markers to the UI and save full subprocess output to
  `~/Library/Application Support/YMM4M/Logs/automatic-setup.log`.
- Explain that the runtime destination stays empty until final validation.
- Store disposable source/build trees under `~/Library/Caches/YMM4M` and reject
  whitespace-containing custom compile roots before configure.
- Replace DXMT empty submodule placeholders before moving pinned dependency
  roots; repair the layout idempotently on retry.
- Add curl connect/low-speed timeouts and retry transient errors.
- Accept only the complete audited GCC 15.2 or reproduced GCC 16.2 hash variant;
  reject other compiler versions before build and reject mixed hash sets.
- Advance managed runtime/prefix activation to patchset5.

## End-to-end result

- Fixed archives downloaded and SHA-256 checked: pass
- Wine 11.0 source configure/build with MinGW GCC 16.2: pass
- DXMT configure/build with pinned NVAPI/DirectX headers: pass
- Runtime stage and manifest generation: pass
- Dedicated prefix, WPF software profile, and Japanese fallback font: pass
- Host whole-file/loadable-image validation: pass
- Atomic activation:
  - `Runtimes/current -> versions/wine-11.0-dxmt-e55ad281-patchset5`
  - `Prefixes/current -> versions/wine-11.0-dxmt-e55ad281-patchset5-prefix-v2`
- Active runtime reports `wine-11.0`: pass
- Swift warning-as-error build and contracts with active runtime/prefix: pass
- Synthetic streamed-progress/failure-log/no-partial-runtime contract: pass
- Python unit tests: 18/18
- Runtime fixtures: 8/8; D3D11 compute iterations: 100/100
- Runtime lock and compatibility registry validation: pass

The known Wine prefix setup diagnostics (`fixme`, selected `setupapi` errors,
and MoltenVK capability output) did not make the setup command fail; required
prefix completion markers and host validation passed.
