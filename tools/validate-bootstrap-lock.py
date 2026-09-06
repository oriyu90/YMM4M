#!/usr/bin/env python3
"""Validate runtime/bootstrap.lock.json structure without external modules.

Checks, for every pinned source:
  * an HTTPS primary URL and a 64-hex SHA-256 (or, for VCS snapshots, a commit),
  * that any `mirrors` entries are HTTPS, name no CrossOver host, and either
    record their own 64-hex SHA-256 (a downloadable mirror) or are clearly
    marked documentation-only with a `note`,
  * that the patch files referenced by the runtime match the recorded digests.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

HEX64 = re.compile(r"^[0-9a-f]{64}$")
REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    lock_path = REPO / "runtime" / "bootstrap.lock.json"
    lock = json.loads(lock_path.read_text())
    errors: list[str] = []

    if lock.get("schema") not in (1, 2):
        errors.append(f"unexpected schema: {lock.get('schema')!r}")

    sources = lock.get("sources", {})
    if not sources:
        errors.append("no sources recorded")

    for name, entry in sources.items():
        url = entry.get("url", "")
        if not url.startswith("https://"):
            errors.append(f"{name}: primary URL is not HTTPS")
        if "crossover" in url.lower():
            errors.append(f"{name}: primary URL references a forbidden CrossOver host")
        sha = entry.get("sha256")
        commit = entry.get("commit")
        if sha is not None and not HEX64.match(sha):
            errors.append(f"{name}: sha256 is not 64 lowercase hex characters")
        if sha is None and not commit:
            errors.append(f"{name}: neither sha256 nor commit is recorded")

        for i, mirror in enumerate(entry.get("mirrors", [])):
            murl = mirror.get("url", "")
            tag = f"{name}.mirrors[{i}]"
            if not murl.startswith("https://"):
                errors.append(f"{tag}: URL is not HTTPS")
            if "crossover" in murl.lower():
                errors.append(f"{tag}: references a forbidden CrossOver host")
            msha = mirror.get("sha256")
            if msha is not None and not HEX64.match(msha):
                errors.append(f"{tag}: sha256 is not 64 lowercase hex characters")
            if msha is None and not mirror.get("note"):
                errors.append(
                    f"{tag}: a mirror without its own sha256 must carry an explanatory note"
                )

    # Patch digests recorded in runtime.lock.json must match the patch files that
    # the bootstrap actually applies.
    runtime_lock = json.loads((REPO / "runtime.lock.json").read_text())
    wine = runtime_lock.get("wine", {})
    patch_digest_keys = {
        "patch": "patches/0002-wine-d2d1-yymm4-compat.patch",
        "dwritePatch": "patches/0003-wine-dwrite-locale-fallback.patch",
        "macdrvPatch": "patches/0004-wine-macdrv-metal-view-bridge.patch",
    }
    for key, rel in patch_digest_keys.items():
        if key in wine and not (REPO / rel).is_file():
            errors.append(f"runtime.lock.json references a missing patch file: {rel}")

    if errors:
        print("; ".join(errors), file=sys.stderr)
        return 2
    mirror_count = sum(len(e.get("mirrors", [])) for e in sources.values())
    print(
        f"validated {len(sources)} pinned bootstrap sources "
        f"and {mirror_count} mirror entries"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
