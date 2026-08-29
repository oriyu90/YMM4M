#!/usr/bin/env python3
"""Atomically select a pre-verified, versioned YMM4 installation."""
from __future__ import annotations

import argparse
import json
import os
import re
import tempfile
from pathlib import Path


SAFE_VERSION = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]*$")


def version_directory(store: Path, version: str) -> Path:
    if not SAFE_VERSION.fullmatch(version):
        raise ValueError(f"invalid version identifier: {version!r}")
    target = store / version
    if target.is_symlink() or not target.is_dir() or not (target / "YukkuriMovieMaker.exe").is_file():
        raise ValueError(f"verified installation is missing: {target}")
    resolved = target.resolve()
    try:
        resolved.relative_to(store.resolve())
    except ValueError as error:
        raise ValueError(f"installation escapes version store: {target}") from error
    return resolved


def current_version(link: Path, store: Path) -> str | None:
    if not link.is_symlink():
        return None
    resolved = link.resolve(strict=False)
    try:
        return str(resolved.relative_to(store.resolve()))
    except ValueError:
        return None


def activate(store: Path, channel: str, version: str) -> dict[str, object]:
    store = store.resolve()
    if not store.is_dir():
        raise ValueError(f"version store is missing: {store}")
    if not SAFE_VERSION.fullmatch(channel):
        raise ValueError(f"invalid channel identifier: {channel!r}")
    target = version_directory(store, version)
    link = store / channel
    if link.exists() and not link.is_symlink():
        raise ValueError(f"refusing to replace non-symlink channel: {link}")

    previous = current_version(link, store)
    if link.is_symlink() and previous is None:
        raise ValueError(f"refusing to replace channel outside version store: {link}")
    relative_target = os.path.relpath(target, start=store)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{channel}.", dir=store)
    os.close(descriptor)
    temporary = Path(temporary_name)
    temporary.unlink()
    try:
        temporary.symlink_to(relative_target)
        os.replace(temporary, link)
    finally:
        if temporary.exists() or temporary.is_symlink():
            temporary.unlink()

    return {
        "schema": 1,
        "channel": channel,
        "previousVersion": previous,
        "activeVersion": version,
        "preservedVersions": sorted(
            item.name for item in store.iterdir()
            if not item.is_symlink()
            and item.is_dir()
            and (item / "YukkuriMovieMaker.exe").is_file()
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--store", required=True, type=Path)
    parser.add_argument("--channel", default="current")
    parser.add_argument("--activate", required=True, metavar="VERSION")
    args = parser.parse_args()
    try:
        result = activate(args.store, args.channel, args.activate)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
