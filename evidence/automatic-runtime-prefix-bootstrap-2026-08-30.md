# Automatic runtime and prefix bootstrap evidence — 2026-08-30

## Scope

This record covers a clean, user-confirmed bootstrap of the YMM4M Wine/DXMT
runtime and a new dedicated Wine prefix. No YMM4 binary, Microsoft proprietary
runtime/font, CrossOver file, or user project was used as a build input.

## Pinned network inputs

The machine-readable source of truth is `runtime/bootstrap.lock.json`.

| Input | Revision | SHA-256 |
|---|---|---|
| Wine source | 11.0 / `db11d0fe6a169c457e23d007e20404643d067aa8` | `f09e8153aa46a581d2b56a5b1363b04832070b9409d9244a68cf482b243ff14a` |
| Gcenx Wine macOS base | 11.0_1 | `b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388` |
| FreeType source headers | 2.14.3 | `36bc4f1cc413335368ee656c42afca65c5a3987e8768cc28cf11ba775e785a5f` |
| DXMT | `e55ad281c60be97f8815b5848e57cfd9f967d759` | `bc8015eb558ccbc3af8ffb391583ff7362ddac87980a87a65db481b9f360efa3` |
| NVIDIA NVAPI | `d08488fcc82eef313b0464db37d2955709691e94` | `436936c965f711f743c8606cb7c2621736cecf41e0fd6557555b2f1903b0350f` |
| mingw-directx-headers | `9df86f2341616ef1888ae59919feaa6d4fad693d` | `9c1b8bbfd2d6c758fac4d93c2808a46bc1eee429fe656b4f21b29e02615aa8aa` |
| Noto Sans CJK Regular TTC | `f8d157532fbfaeda587e826d4cd5b21a49186f7c` | `b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a` |

Every archive was fetched over HTTPS, verified before extraction, checked for
unsafe member paths, and extracted outside the final runtime. The bootstrap
refuses CrossOver-named inputs and refuses to overwrite an existing runtime.

## Findings and fixes

1. A fresh prefix initially failed the Japanese pixel fixture. The previous
   successful prefix could see a user-installed host font, and the Wine build
   had disabled FreeType. Wine is now compiled with the Gcenx base's FreeType
   library and headers from the pinned official FreeType source. The pinned TTC
   is converted with `hb-subset` to a prefix-local Japanese OTF; no host font is
   required.
2. The first fresh rebuild exposed `CreateEffect(Premultiply) = 0x88990028`.
   Comparison with the earlier tested source showed that the Premultiply
   implementation had not been included in the recorded Wine patch. The
   evidence-backed implementation and registration are now part of
   `patches/0002-wine-d2d1-yymm4-compat.patch`, and the cumulative patch passes a
   clean-source dry run.
3. `wineserver -w` could wait indefinitely for prefix services. Prefix setup now
   requests a clean server shutdown with `wineserver -k` and then waits.
4. Wine PE debug data embedded disposable source/build paths, producing different
   whole-file hashes for equivalent builds. `CROSSCFLAGS` now maps those paths to
   `/usr/src/wine-11.0` and `/usr/src/wine-build`. Two independent build roots
   produced byte-identical DLLs: `d2d1.dll`
   `bfd7d57f6cb286639adaa575ace42cc3a9e75574d2f93398d159cd356218e77d`
   and `dwrite.dll`
   `83411068ee8b7e3c009a4fd54900a2f1d696e525fee622a2105c5ea6d52e665c`.
   Strict whole-file runtime verification is therefore retained.
5. Removing Mach-O UUID/link-edit data from `winemac.so` caused a compute
   regression in an earlier controlled attempt, so staged binaries remain
   unmodified. Placement integrity uses the manifest's full SHA-256; runtime
   identity separately uses the established loadable-image hash.

The Japanese fixture writes its diagnostic image through `Y:`. A test-only
`Y:` mapping to the home directory was added after prefix creation solely for
that fixture. Product prefixes do not receive this broad mapping; normal media
access remains constrained to `M:`.

## Final isolated result

- Runtime: `/Users/user/.ymm4m-dev/bootstrap-e2e-runtime-repro-2026-08-30`
- Prefix: `/Users/user/.ymm4m-dev/bootstrap-e2e-prefix-repro-2026-08-30`
- Fixture log: `/Users/user/.ymm4m-dev/runtime-fixtures-e2e-repro-2026-08-30.log`
- Host: Apple M3 Ultra, native ARM64 host, x86_64 Wine under Rosetta

The new prefix contains the WPF software profile and the prefix-local Noto font.
All eight public fixtures passed: D3D11 compute (100 iterations), context state,
DXGI surface, D2D device6, null effect input, 3D transform plus Premultiply,
Japanese pixel output (`wrote=1`), and DirectWrite fallback for isolated/shared
factories with empty and `ja-JP` locales.

This proves the local automatic bootstrap path. It does not authorize public
redistribution of the generated runtime and does not close the remaining YMM4
Tier A or final release-license gates.
