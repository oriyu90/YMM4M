#!/usr/bin/env python3
"""Compare two decoded RGB24 frames without third-party Python packages."""
from __future__ import annotations
import argparse, json, math
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("reference", type=Path)
parser.add_argument("candidate", type=Path)
args = parser.parse_args()
a, b = args.reference.read_bytes(), args.candidate.read_bytes()
if len(a) != len(b) or not a:
    raise SystemExit("Frames must be non-empty and have identical decoded RGB24 sizes")
differences = [abs(x - y) for x, y in zip(a, b)]
mse = sum(value * value for value in differences) / len(differences)
result = {
    "bytes": len(a), "meanAbsoluteError": sum(differences) / len(differences),
    "maximumDifference": max(differences), "psnr": None if mse == 0 else 20 * math.log10(255 / math.sqrt(mse)),
    "identical": mse == 0,
}
print(json.dumps(result, indent=2))

