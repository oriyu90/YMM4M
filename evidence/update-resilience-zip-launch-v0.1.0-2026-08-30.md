# v0.1.0 update-resilience・YMM4 ZIP launch evidence

Date: 2026-08-30

## Scope

- Versioned Wine/DXMT runtime and WPF prefix activation
- Runtime-profile/prefix-schema binding
- User-supplied official YMM4 ZIP validation and versioned installation
- In-app `YMM4をMacで開く` action
- v0.1.0 development app/DMG packaging

The proprietary YMM4 ZIP and extracted binaries were not added to Git or the app/DMG.

## Inputs

- YMM4 Lite release: `4.55.1.1-Lite`
- Official ZIP SHA-256: `125860147cc33b831fc1a6d6ea996958001c2ead3b0d37f7d900251d5617db9b`
- Extracted exe SHA-256: `96d80e18c52f00f16b7568e96346e5f8dfa99b57b5a531e60ca0c645dda0a822`
- Runtime profile: `wine-11.0-dxmt-e55ad281-patchset4`

## Results

- Swift warnings-as-errors build: pass
- Swift contract tests: pass
- Contract test using the real 515,057,348-byte official ZIP: pass
- Python unit tests: 16/16 pass
- Runtime-lock validator: pass
- Compatibility registry validator: 20 features pass
- Shell syntax, Info.plist lint, `git diff --check`: pass
- Runtime fixtures: 8/8 pass; D3D11 compute 100/100
- Synthetic ZIP install/reuse/current-channel escape tests: pass
- Real ZIP archive hash, safe extraction, exe hash, version install/current switch: pass
- Release app process launch and clean quit: pass

## DMG audit

- Artifact: `/Users/user/.ymm4m-dev/audit-artifacts-2026-08-30/YMM4M-0.1.0-development-adhoc.dmg`
- Size: 607,858 bytes
- SHA-256: `9bc7987d87f967fa967382f110a1dfe0064a2a634d1130a03ee4e2e57df3e2de`
- Bundle: version `0.1.0` build `4`, thin ARM64
- Signature: explicit ad-hoc; `TeamIdentifier=not set`
- Notarization/stapling: not performed
- Read-only DMG verify/mount: pass
- Forbidden payload scan for YMM4 exe, DLLs, Wine executables, OTF/TTC: pass
- Bundled `compatibility/ymm4-releases.json` SHA-256: `27f8a6ae7209925485955e1db495e111915a1d82357727f8ac8d3bb91b43c981`

## Update behavior

New runtime/prefix/YMM4 versions are created below `versions/` and activated only after validation. Old versions remain present. A runtime/prefix binding mismatch refuses launch and can be repaired by rerunning setup. Unknown YMM4 or runtime hashes are not guessed compatible.

The design audit and remaining limitations are in `docs/UPDATE_COMPATIBILITY_AUDIT.md`. This evidence does not make the artifact release-ready: Developer ID signing, notarization, final license audit, remaining Tier A items, clean-machine and extended recovery tests are incomplete.

## Hosted draft

- Implementation commit: `db8e238939c1fec9be9f23f269e2f8f3bbf28ebd`
- CI: <https://github.com/oriyu90/YMM4M/actions/runs/33274607296> — pass
- GitHub draft prerelease ID: `379098975`; tag name reserved by draft: `v0.1.0`
- Hosted asset digest and size match the local artifact.
- Draft was not published. Draft preview URLs are intentionally not recorded because GitHub may rotate the `untagged-*` URL when draft metadata changes.
