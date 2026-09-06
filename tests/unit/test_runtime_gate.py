"""Tests for tools/finalize-runtime-gate.sh (schema-2 clean-runtime gate)."""
from __future__ import annotations

import hashlib
import json
import os
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TOOL = ROOT / "tools" / "finalize-runtime-gate.sh"

RUNTIME_FILE_KEYS = [
    "bin/wine",
    "lib/wine/x86_64-unix/winemetal.so",
    "lib/wine/x86_64-windows/d3d10core.dll",
    "lib/wine/x86_64-windows/d3d11.dll",
    "lib/wine/x86_64-windows/dxgi.dll",
    "lib/wine/x86_64-windows/winemetal.dll",
    "lib/wine/x86_64-windows/d2d1.dll",
    "lib/wine/x86_64-windows/dwrite.dll",
]
WINEMAC_KEY = "lib/wine/x86_64-unix/winemac.so"
GATE_FIXTURES = [
    "d3d11-compute-pipeline-reproducer.cpp",
    "d3d11-context-state-reproducer.cpp",
    "dxgi-surface2-reproducer.cpp",
    "d2d-device6-reproducer.cpp",
    "d2d-null-effect-input-reproducer.cpp",
    "d2d-3d-transform-reproducer.cpp",
    "d2d-japanese-text-reproducer.cpp",
    "dwrite-font-fallback-reproducer.cpp",
]


def synthetic_winemac() -> bytes:
    """A minimal valid x86_64 Mach-O with a zeroed LC_UUID and a __LINKEDIT
    segment at file offset 128 (matches the Swift contract-test fixture)."""
    b = bytearray()
    b += struct.pack("<IIIIIIII", 0xFEEDFACF, 0x01000007, 3, 6, 2, 24 + 72, 0, 0)
    b += struct.pack("<II", 0x1B, 24) + b"\x00" * 16
    seg = b"__LINKEDIT".ljust(16, b"\x00")
    b += struct.pack("<II", 0x19, 72) + seg
    b += struct.pack("<QQQQ", 0, 8, 128, 8)
    b += struct.pack("<IIII", 1, 1, 0, 0)
    b += b"linkedit"
    return bytes(b)


class FinalizeRuntimeGateTests(unittest.TestCase):
    def _stage(self, tmp: Path, *, schema: int = 2, finalized: bool = False):
        runtime = tmp / "runtime"
        fixtures = tmp / "fixtures"
        fixtures.mkdir(parents=True)
        files = {}
        for i, key in enumerate(RUNTIME_FILE_KEYS):
            path = runtime / key
            path.parent.mkdir(parents=True, exist_ok=True)
            payload = f"synthetic-runtime-file-{i}".encode()
            path.write_bytes(payload)
            files[key] = hashlib.sha256(payload).hexdigest()
        winemac = synthetic_winemac()
        (runtime / WINEMAC_KEY).parent.mkdir(parents=True, exist_ok=True)
        (runtime / WINEMAC_KEY).write_bytes(winemac)
        files[WINEMAC_KEY] = hashlib.sha256(winemac).hexdigest()
        for name in GATE_FIXTURES:
            (fixtures / name).write_bytes(f"// fixture {name}\n".encode())

        results = (
            {"fixtures": "pass", "compute100": "pass"}
            if finalized
            else {"fixtures": "pending", "compute100": "pending"}
        )
        manifest = {
            "schema": schema,
            "kind": "ymm4m-clean-wine-dxmt",
            "wineVersion": "11.0",
            "architecture": "x86_64",
            "files": files,
            "provenance": {
                "sources": {"wineSource": "0" * 64},
                "patches": {"0001-dxmt-yymm4-compat.patch": "0" * 64},
                "toolchain": {"mingw": "16.2.0", "llvm": "15.0.7"},
                "gate": {
                    "producedAt": "2026-09-07T00:00:00Z",
                    "runtimeFiles": files,
                    "winemacLoadableSha256": "pending",
                    "fixtures": {},
                    "results": results,
                },
            },
        }
        (runtime / "ymm4m-runtime.json").write_text(json.dumps(manifest, indent=2))
        return runtime, fixtures, winemac

    def _run(self, runtime: Path, fixtures: Path):
        return subprocess.run(
            [str(TOOL)],
            env={
                **os.environ,
                "YMM4M_RUNTIME_ROOT": str(runtime),
                "YMM4M_FIXTURE_DIR": str(fixtures),
            },
            text=True,
            capture_output=True,
            check=False,
        )

    def test_finalizes_a_pending_schema2_manifest(self):
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            runtime, fixtures, winemac = self._stage(tmp)
            completed = self._run(runtime, fixtures)
            self.assertEqual(completed.returncode, 0, completed.stderr)

            manifest = json.loads((runtime / "ymm4m-runtime.json").read_text())
            gate = manifest["provenance"]["gate"]
            self.assertEqual(gate["results"], {"fixtures": "pass", "compute100": "pass"})
            self.assertEqual(set(gate["fixtures"]), {
                f"tests/fixtures/{name}" for name in GATE_FIXTURES
            })
            for name in GATE_FIXTURES:
                expected = hashlib.sha256(
                    (fixtures / name).read_bytes()
                ).hexdigest()
                self.assertEqual(gate["fixtures"][f"tests/fixtures/{name}"], expected)
            # winemacLoadableSha256 == SHA-256(first 128 bytes) by construction.
            self.assertEqual(
                gate["winemacLoadableSha256"],
                hashlib.sha256(winemac[:128]).hexdigest(),
            )

    def test_refuses_a_non_schema2_manifest(self):
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            runtime, fixtures, _ = self._stage(tmp, schema=1)
            completed = self._run(runtime, fixtures)
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("not schema 2", completed.stderr)

    def test_refuses_to_overwrite_a_finalized_gate(self):
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            runtime, fixtures, _ = self._stage(tmp, finalized=True)
            completed = self._run(runtime, fixtures)
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("already finalized", completed.stderr)

    def test_refuses_when_a_runtime_file_changed_since_staging(self):
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            runtime, fixtures, _ = self._stage(tmp)
            (runtime / "bin/wine").write_bytes(b"mutated after staging")
            completed = self._run(runtime, fixtures)
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("changed since staging", completed.stderr)


if __name__ == "__main__":
    unittest.main()
