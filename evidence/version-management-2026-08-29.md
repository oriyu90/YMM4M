# Version switching and rollback implementation gate (2026-08-29)

The development specification requires YMM4M runtime updates and YMM4 application updates to remain separate, old YMM4 versions to be preserved, and rollback to remain possible. This record covers only the local YMM4 version-selection primitive; it does not claim that YMM4's official updater works under Wine or that automatic update UI is complete.

`tools/manage-ymm4-version.py` selects a previously inspected and installed version directory by atomically replacing a `current` symlink. It:

- requires an explicit store and version identifier;
- requires a real, non-symlink version directory containing `YukkuriMovieMaker.exe`;
- rejects identifiers that could escape the store;
- refuses to replace an existing non-symlink channel or a channel pointing outside the store;
- never deletes a version directory;
- reports the previous and active versions plus the preserved version set.

Unit tests create two synthetic public-PE fixture installations, switch forward, switch back, verify both installations remain, refuse an existing directory named `current`, reject a version-directory symlink, and preserve a `current` link pointing outside the store. The real local YMM4 installation was not changed during this test.

Result: the atomic selection/rollback primitive passes. Product UI, official-updater behavior under Wine, download authenticity, interrupted-update recovery, and the independent YMM4M runtime-update state machine remain open.
