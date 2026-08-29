#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from pe_inventory import inspect_bytes


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect a PE file without executing it")
    parser.add_argument("file", type=Path)
    args = parser.parse_args()
    result = {"path": args.file.name, **inspect_bytes(args.file.read_bytes()).as_dict()}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

