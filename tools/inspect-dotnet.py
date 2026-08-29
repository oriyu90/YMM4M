#!/usr/bin/env python3
"""Report the deployment decision from an inspect-ymm4 inventory."""
from __future__ import annotations
import argparse, json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("inventory", type=Path)
args = parser.parse_args()
data = json.loads(args.inventory.read_text())
print(json.dumps({"dotnetDeployment": data.get("dotnetDeployment"), "runtimeConfigs": data.get("runtimeConfigs", [])}, ensure_ascii=False, indent=2))
raise SystemExit(0 if data.get("dotnetDeployment") in {"SELF_CONTAINED", "FRAMEWORK_DEPENDENT"} else 2)

