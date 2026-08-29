#!/usr/bin/env python3
"""Install a verified YMM4 archive into a user-owned runtime directory."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import stat
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validated_members(archive: zipfile.ZipFile) -> list[zipfile.ZipInfo]:
    members = []
    for member in archive.infolist():
        path = PurePosixPath(member.filename.replace("\\", "/"))
        mode = member.external_attr >> 16
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"unsafe archive path: {member.filename}")
        if stat.S_ISLNK(mode):
            raise ValueError(f"symbolic links are not allowed: {member.filename}")
        members.append(member)
    return members


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    args = parser.parse_args()

    inventory = json.loads(args.inventory.read_text())
    if not inventory.get("gate", {}).get("passed"):
        raise SystemExit("inventory gate did not pass")
    actual_hash = sha256_file(args.archive)
    expected_hash = inventory.get("archive", {}).get("sha256")
    if actual_hash != expected_hash:
        raise SystemExit("archive SHA-256 no longer matches its inventory")
    if args.destination.exists():
        raise SystemExit(f"destination already exists: {args.destination}")

    args.destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".ymm4-install-", dir=args.destination.parent))
    try:
        with zipfile.ZipFile(args.archive) as archive:
            for member in validated_members(archive):
                relative = PurePosixPath(member.filename.replace("\\", "/"))
                target = staging.joinpath(*relative.parts)
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(member) as source, target.open("wb") as output:
                    shutil.copyfileobj(source, output, length=1024 * 1024)
        executable = staging / "YukkuriMovieMaker.exe"
        if not executable.is_file():
            raise ValueError("YukkuriMovieMaker.exe is missing after extraction")
        os.replace(staging, args.destination)
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    print(f"Installed verified archive at {args.destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

