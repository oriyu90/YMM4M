#!/usr/bin/env python3
"""Cross-check pinned YMM4 identity against the recorded public inventory."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lock", type=Path, default=Path("runtime.lock.json"))
    parser.add_argument(
        "--inventory",
        type=Path,
        default=Path("evidence/ymm4-lite-inventory.json"),
    )
    parser.add_argument("--catalog", type=Path, default=Path("compatibility/ymm4-releases.json"))
    args = parser.parse_args()

    lock = json.loads(args.lock.read_text())
    inventory = json.loads(args.inventory.read_text())
    expected = lock.get("ymm4", {})
    archive = inventory.get("archive", {})
    executable = inventory.get("primaryExecutable") or {}
    catalog = json.loads(args.catalog.read_text())

    comparisons = {
        "YMM4 archive SHA-256": (expected.get("archiveSha256"), archive.get("sha256")),
        "YMM4 executable SHA-256": (
            expected.get("executableSha256"),
            executable.get("sha256"),
        ),
    }
    errors = [
        f"{label} mismatch: lock={locked!r}, inventory={recorded!r}"
        for label, (locked, recorded) in comparisons.items()
        if not locked or locked != recorded
    ]
    if not inventory.get("gate", {}).get("passed"):
        errors.append("YMM4 inventory gate is not passed")
    locked_executable_hash = expected.get("executableSha256")
    catalog_entries = catalog.get("releases", [])
    catalog_hashes = {
        item.get("executableSha256") for item in catalog_entries
        if item.get("classification") == "knownCompatible"
    }
    archive_hashes = {item.get("archiveSha256") for item in catalog_entries}
    if locked_executable_hash not in catalog_hashes:
        errors.append("pinned YMM4 executable hash is missing from compatibility catalog")
    if expected.get("archiveSha256") not in archive_hashes:
        errors.append("pinned YMM4 archive hash is missing from compatibility catalog")
    if errors:
        raise SystemExit("; ".join(errors))

    print("validated pinned YMM4 archive and executable hashes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
