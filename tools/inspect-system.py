#!/usr/bin/env python3
"""Capture a redacted, reproducible development-host inventory."""
from __future__ import annotations

import argparse
import json
import platform
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def command(*args: str) -> dict[str, object]:
    executable = shutil.which(args[0])
    if executable is None:
        return {"available": False, "output": None}
    completed = subprocess.run(
        [executable, *args[1:]], text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=30, check=False,
    )
    return {
        "available": True,
        "exitCode": completed.returncode,
        "output": completed.stdout.strip(),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    evidence = {
        "schema": 1,
        "collectedAt": datetime.now(timezone.utc).isoformat(),
        "machine": platform.machine(),
        "platform": platform.platform(),
        "commands": {
            "swVers": command("sw_vers"),
            "uname": command("uname", "-srm"),
            "xcodebuild": command("xcodebuild", "-version"),
            "swift": command("swift", "--version"),
            "clang": command("clang", "--version"),
            "git": command("git", "--version"),
            "gh": command("gh", "--version"),
            "wine": command("wine", "--version"),
            "wine64": command("wine64", "--version"),
            "ffmpeg": command("ffmpeg", "-version"),
        },
        "privacy": "Serial numbers, UUIDs, account names, environment variables, and tokens are intentionally omitted.",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
