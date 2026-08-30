# YMM4 4.55.1.1 standard edition and settings persistence — 2026-08-30

## Scope and safety

- Official user-supplied standard ZIP: `YukkuriMovieMaker_v4.zip`
- ZIP SHA-256: `dd5a8db1d929aec72fde39d300d0de15bdfac53e9bd55bc6262942e2bcee5efe`
- Extracted EXE SHA-256: `53153b7098d40ad41d3495a57757754f1681731f2c0eaeeee7e821a92a0c33bd`
- Runtime profile: `wine-11.0-dxmt-e55ad281-patchset4`
- Separate test prefix: `/Users/user/.ymm4m-dev/normal-edition-2026-08-30/prefix`

The ZIP and executable were not committed. No proprietary implementation was
decompiled. The test used public archive metadata, public command-line output,
and visible Win32 window state only. No user project was opened or modified.

## Before-change reproduction

The real-archive contract rejected the standard ZIP because only the Lite hash
was present in the catalog. It stopped with SHA-256
`dd5a8db1d929aec72fde39d300d0de15bdfac53e9bd55bc6262942e2bcee5efe` as
an unverified archive.

## Standard-edition results

- Existing inventory and a fresh inventory agree: AMD64 Windows GUI executable,
  self-contained .NET 10.0.10, 751 ZIP entries, no unsafe members.
- `--help` completed and printed the documented command-line encoding usage.
- The first GUI run displayed the public first-run dialogs and then the enabled
  main window titled `YukkuriMovieMaker v4.55.1.1`.
- The second GUI run in the same dedicated prefix reached that main window
  directly. The already-answered file-association prompt did not return. This
  confirms that this public first-run choice survived normal close and restart
  through the persistent versioned prefix.
- The known `YukkuriMovieMaker.Win32Service.exe` Mono/native banner also appeared;
  it is not new to the standard edition and remains a separately tracked issue.

The standard edition is therefore catalogued for ZIP installation, CLI help,
and GUI startup. Broader Tier A editing/import/export claims still come from the
separately recorded Lite matrix unless explicitly retested.

## Host settings results

The contract suite now writes all five setup values to an isolated
`UserDefaults` suite and reads them back as a simulated next app launch. It also
verifies that legacy managed runtime, prefix, and version-specific YMM4 paths
normalize to existing `current` channels, while the source-ZIP path, media root,
and arbitrary custom paths remain unchanged. Missing current channels do not
cause an automatic move or overwrite; the UI asks for setup again.

After the catalog change, both real official ZIP contracts pass independently:

- standard 4.55.1.1: pass
- Lite 4.55.1.1: pass
