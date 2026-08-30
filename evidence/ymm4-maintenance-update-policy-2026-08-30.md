# YMM4 maintenance-update policy evidence — 2026-08-30

## Scope and rules

This audit uses only official release metadata, release notes, ZIP members, file hashes,
PE headers, and public runtime configuration. It does not decompile or inspect proprietary
implementation details. The deferred final release-license document was not opened.

## Official-source evidence

The public `manju-summoner/YukkuriMovieMaker4` GitHub Releases API exposes each release
asset's name, byte size, download URL, and SHA-256 `digest`.

- API: <https://api.github.com/repos/manju-summoner/YukkuriMovieMaker4/releases>
- Official release history: <https://manjubox.net/ymm4/release/>
- 4.55.1.1 notes: <https://manjubox.net/ymm4/release/4.55.1.1/>
- 4.55.1.0 notes: <https://manjubox.net/ymm4/release/4.55.1.0/>
- 4.55.0.1 notes: <https://manjubox.net/ymm4/release/4.55.0.1/>
- 4.55.0.0 notes: <https://manjubox.net/ymm4/release/4.55.0.0/>

- `v4.55.1.1` Standard ZIP: `dd5a8db1d929aec72fde39d300d0de15bdfac53e9bd55bc6262942e2bcee5efe`
- `v4.55.1.1` Lite ZIP: `125860147cc33b831fc1a6d6ea996958001c2ead3b0d37f7d900251d5617db9b`
- `v4.55.1.0` Lite ZIP: `a9fd61fa765a2efca37e464f1af7fac46e2d21d069dbc4a65f24e4bcb24f3c3a`

The locally downloaded 4.55.1.0 Lite and 4.55.1.1 Standard files matched the official
API digests exactly. YMM4M still treats the API as proof of asset identity only, not proof
that Wine/DXMT behavior is compatible.

Official release history shows that maintenance-looking releases can change UI scaling,
IME-related behavior, drawing, updater comparison, effects, plug-ins, and startup behavior.
Therefore the fourth version component is not used as a standalone compatibility claim.

## Public package comparison

Compared official 4.55.1.0 Lite with the previously verified 4.55.1.1 Lite installation:

- package files excluding generated `user/`: 702 vs 702
- added package paths: 0
- removed package paths: 0
- changed package files: 87
- primary executable: AMD64 Windows GUI PE in both versions
- deployment: self-contained .NET 10.0.10 in both versions

The following runtime boundary files were byte-identical across 4.55.1.0 Lite,
4.55.1.1 Lite, and official 4.55.1.1 Standard:

| File | SHA-256 |
|---|---|
| `YukkuriMovieMaker.runtimeconfig.json` | `8fbaa036e9045139020ecf1f69c31bd12dfcff4f839a86355f56e8645981deb7` |
| `coreclr.dll` | `58859f85a30cc71313b281898e7cfbdbb9eccb95ae2a3f865329efd47ebf31bb` |
| `hostfxr.dll` | `d1012d5b8ff1329d5baa6d58aa02c4277acbe58cfd1dc5f10d7e6bb8e9a0d94a` |
| `hostpolicy.dll` | `e9c723bf674ef7f6e6c1cc5d4ee694715b864f480c56baaf354b8cf7c9b40b87` |
| `PresentationCore.dll` | `b8fbf245f2868dc992c329e67f1277119dc3a3914048ec73ee88fa45acf7e0ec` |
| `PresentationFramework.dll` | `3a22e5bd32d90b034a5ec19657b506cac2647b46cdaef5d33e134b09585de5d2` |
| `WindowsBase.dll` | `0367e9e3f0d7c44deefaef9fa39e8c93cafa89900b6d0e7602202837c6d83f55` |
| `System.Private.CoreLib.dll` | `76a49f17e83f613bc8a5b55fc98830b764e7838265aacbdbcc8f46707f80a3c9` |
| `d3dcompiler_47_cor3.dll` | `a05f99734f7c4822fefc12b367af21fd0976ed6608752fb1e1e80b6ece7ecbbb` |

This supports a narrow 4.55.1.x runtime-boundary policy for both editions. It does not
prove that a future app-layer change behaves correctly.

## Implemented policy

An unknown ZIP can enter the maintenance path only when all of these pass:

1. unchanged official filename for Standard or Lite;
2. stable, non-draft, non-prerelease release from the fixed official GitHub repository;
3. exact official asset name, byte size, and SHA-256 digest;
4. same configured 4.55.1.x maintenance family and a version newer than 4.55.1.1;
5. existing ZIP traversal, size, entry-count, encryption, duplicate, header, and symlink gates;
6. AMD64 Windows GUI PE executable;
7. all nine runtime-boundary hashes above;
8. explicit user confirmation.

The result is classified `maintenanceCandidate`, never `knownCompatible`. The prior
version remains under `previous`; rollback swaps the channels atomically. Official assets
outside the configured family, pre-releases, altered packages, runtime servicing changes,
and offline metadata failures stop without changing `current`.

## Settings and user-data persistence

Observed YMM4 data under `user/setting/<version>`, with logs and backups under the same
`user` root. Fully isolated version directories would hide that data after a version switch.
The installer now keeps separate shared roots for Standard and Lite and links every managed
version's `user` path to its edition root. A legacy `lite-current/user` is copied once into
shared storage; the source is retained. Conflicting populated roots are not merged silently.

Contract coverage writes a setting through the known version, reads it through a maintenance
candidate, rolls back, and verifies the prior executable and shared data remain intact.

## Verification

- `swift build -Xswiftc -warnings-as-errors`: pass
- `swift run YMM4MContractTests`: pass
- real official 4.55.1.1 Standard ZIP install contract: pass
- `python3 -m unittest discover -s tests/unit -p 'test_*.py'`: 16/16 pass
- catalog JSON parse: pass

## Remaining concerns

- Structural equality cannot prove UI, editing, IME, plugin, WebView2, audio, preview, or
  export behavior. A maintenance candidate remains provisional until the normal evidence
  matrix promotes its exact hashes.
- GitHub/API availability is required only for an unknown candidate. Already cataloged and
  installed versions remain usable offline.
- If upstream services the self-contained .NET/WPF runtime inside 4.55.1.x, the strict
  boundary rejects it until YMM4M tests and updates the policy.
- Rollback is user-triggered and retains one previous active channel; automatic crash-loop
  detection is not implemented.
- YMM4's own per-version setting migration remains upstream behavior. YMM4M preserves the
  shared edition data and does not rewrite proprietary settings formats.
