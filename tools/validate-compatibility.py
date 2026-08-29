#!/usr/bin/env python3
"""Validate the deliberately simple compatibility YAML without external modules."""
from pathlib import Path
import re
import sys

path = Path(sys.argv[1] if len(sys.argv) > 1 else "compatibility/features.yaml")
text = path.read_text()
allowed = {"untested", "pass", "pass_with_workaround", "partial", "fail", "crash", "unsupported"}
statuses = re.findall(r"^\s+status:\s*(\S+)\s*$", text, re.MULTILINE)
identifiers = re.findall(r"^\s+- id:\s*(\S+)\s*$", text, re.MULTILINE)
tiers = re.findall(r"^\s+tier:\s*(\S+)\s*$", text, re.MULTILINE)
errors = []
if not identifiers: errors.append("no features")
if len(identifiers) != len(set(identifiers)): errors.append("duplicate feature ids")
if len(statuses) != len(identifiers): errors.append("each feature needs one status")
if len(tiers) != len(identifiers): errors.append("each feature needs one tier")
if set(statuses) - allowed: errors.append(f"invalid statuses: {sorted(set(statuses) - allowed)}")
if set(tiers) - {"A", "B", "C", "D"}: errors.append(f"invalid tiers: {sorted(set(tiers) - {'A','B','C','D'})}")
if errors:
    print("; ".join(errors), file=sys.stderr)
    raise SystemExit(2)
print(f"validated {len(identifiers)} compatibility features")

