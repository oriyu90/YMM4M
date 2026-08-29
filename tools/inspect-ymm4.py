#!/usr/bin/env python3
"""Safely inventory an official YMM4 ZIP without extracting or executing it."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pe_inventory import inspect_bytes  # noqa: E402

MAX_MEMBER_SIZE = 512 * 1024 * 1024


def safe_name(name: str) -> bool:
    path = PurePosixPath(name.replace("\\", "/"))
    return not path.is_absolute() and ".." not in path.parts


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def deployment_model(names: set[str], configs: list[dict[str, object]]) -> str:
    basenames = {PurePosixPath(name).name.lower() for name in names}
    has_runtime = {"coreclr.dll", "hostfxr.dll", "hostpolicy.dll"}.issubset(basenames)
    if has_runtime:
        return "SELF_CONTAINED"
    if configs:
        return "FRAMEWORK_DEPENDENT"
    return "UNKNOWN"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("zip", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-version", default="4.55.1.1")
    args = parser.parse_args()
    archive_hash = sha256_file(args.zip)
    binaries: list[dict[str, object]] = []
    runtime_configs: list[dict[str, object]] = []
    names: set[str] = set()
    unsafe: list[str] = []

    with zipfile.ZipFile(args.zip) as archive:
        for member in archive.infolist():
            if not safe_name(member.filename) or member.file_size > MAX_MEMBER_SIZE:
                unsafe.append(member.filename)
                continue
            names.add(member.filename)
            lower = member.filename.lower()
            if lower.endswith((".exe", ".dll")):
                try:
                    info = inspect_bytes(archive.read(member)).as_dict()
                    binaries.append({"path": member.filename, **info})
                except ValueError as error:
                    binaries.append({"path": member.filename, "error": str(error), "size": member.file_size})
            elif lower.endswith(".runtimeconfig.json"):
                try:
                    runtime_configs.append({"path": member.filename, "content": json.loads(archive.read(member))})
                except (UnicodeDecodeError, json.JSONDecodeError) as error:
                    runtime_configs.append({"path": member.filename, "error": str(error)})

    primary = next((item for item in binaries if PurePosixPath(str(item["path"])).name.lower() == "yukkurimoviemaker.exe"), None)
    model = deployment_model(names, runtime_configs)
    result = {
        "schema": 1,
        "collectedAt": datetime.now(timezone.utc).isoformat(),
        "source": "user-selected-official-zip",
        "expectedVersion": args.expected_version,
        "archive": {"fileName": args.zip.name, "size": args.zip.stat().st_size, "sha256": archive_hash},
        "primaryExecutable": primary,
        "dotnetDeployment": model,
        "runtimeConfigs": runtime_configs,
        "binaries": sorted(binaries, key=lambda item: str(item["path"]).lower()),
        "unsafeMembers": unsafe,
        "gate": {
            "passed": primary is not None and model != "UNKNOWN" and not unsafe,
            "reasons": (["YukkuriMovieMaker.exe was not found"] if primary is None else [])
            + ([".NET deployment model is unknown"] if model == "UNKNOWN" else [])
            + (["unsafe ZIP members were rejected"] if unsafe else []),
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"Inventory written to {args.output}; gate={'PASS' if result['gate']['passed'] else 'STOP'}")
    return 0 if result["gate"]["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
