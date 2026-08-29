from __future__ import annotations

import importlib.util
import struct
import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))
from pe_inventory import inspect_bytes


def minimal_pe(machine: int = 0x8664, managed: bool = True) -> bytes:
    data = bytearray(512)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x80)
    data[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<HHIIIHH", data, 0x84, machine, 0, 0, 0, 0, 240, 0)
    optional = 0x98
    struct.pack_into("<H", data, optional, 0x20B)
    struct.pack_into("<H", data, optional + 68, 2)
    if managed:
        struct.pack_into("<II", data, optional + 112 + 14 * 8, 0x2000, 72)
    return bytes(data)


class PEInventoryTests(unittest.TestCase):
    def test_amd64_managed_gui(self):
        result = inspect_bytes(minimal_pe())
        self.assertEqual(result.machine, "AMD64")
        self.assertEqual(result.subsystem, "WINDOWS_GUI")
        self.assertTrue(result.managed)

    def test_rejects_non_pe(self):
        with self.assertRaises(ValueError):
            inspect_bytes(b"not executable")


class YMM4ArchiveTests(unittest.TestCase):
    def test_framework_dependent_inventory_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "YMM4.zip"
            output = root / "inventory.json"
            with zipfile.ZipFile(archive, "w") as target:
                target.writestr("YukkuriMovieMaker.exe", minimal_pe())
                target.writestr("YukkuriMovieMaker.runtimeconfig.json", json.dumps({
                    "runtimeOptions": {"framework": {"name": "Microsoft.WindowsDesktop.App", "version": "10.0.11"}}
                }))
            completed = subprocess.run(
                [sys.executable, str(TOOLS / "inspect-ymm4.py"), str(archive), "--output", str(output)],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            result = json.loads(output.read_text())
            self.assertEqual(result["dotnetDeployment"], "FRAMEWORK_DEPENDENT")
            self.assertEqual(result["primaryExecutable"]["machine"], "AMD64")
            self.assertTrue(result["gate"]["passed"])

    def test_unsafe_archive_stops_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "unsafe.zip"
            output = root / "inventory.json"
            with zipfile.ZipFile(archive, "w") as target:
                target.writestr("../YukkuriMovieMaker.exe", minimal_pe())
            completed = subprocess.run(
                [sys.executable, str(TOOLS / "inspect-ymm4.py"), str(archive), "--output", str(output)],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(completed.returncode, 2)
            self.assertFalse(json.loads(output.read_text())["gate"]["passed"])

    def test_installer_rechecks_hash_and_extracts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "YMM4.zip"
            inventory = root / "inventory.json"
            destination = root / "installed"
            with zipfile.ZipFile(archive, "w") as target:
                target.writestr("YukkuriMovieMaker.exe", minimal_pe())
                target.writestr("YukkuriMovieMaker.runtimeconfig.json", "{}")
            inspect = subprocess.run(
                [sys.executable, str(TOOLS / "inspect-ymm4.py"), str(archive), "--output", str(inventory)],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(inspect.returncode, 0, inspect.stderr)
            install = subprocess.run(
                [sys.executable, str(TOOLS / "install-ymm4.py"), str(archive), "--inventory", str(inventory), "--destination", str(destination)],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(install.returncode, 0, install.stderr)
            self.assertTrue((destination / "YukkuriMovieMaker.exe").is_file())

    def test_version_switch_preserves_installs_and_rolls_back(self):
        with tempfile.TemporaryDirectory() as directory:
            store = Path(directory)
            for version in ("4.55.1.1-Lite", "4.56.0.0-Lite"):
                installed = store / version
                installed.mkdir()
                (installed / "YukkuriMovieMaker.exe").write_bytes(minimal_pe())

            first = subprocess.run(
                [sys.executable, str(TOOLS / "manage-ymm4-version.py"),
                 "--store", str(store), "--activate", "4.55.1.1-Lite"],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            second = subprocess.run(
                [sys.executable, str(TOOLS / "manage-ymm4-version.py"),
                 "--store", str(store), "--activate", "4.56.0.0-Lite"],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(second.returncode, 0, second.stderr)
            switched = json.loads(second.stdout)
            self.assertEqual(switched["previousVersion"], "4.55.1.1-Lite")
            self.assertEqual((store / "current").resolve(), (store / "4.56.0.0-Lite").resolve())

            rollback = subprocess.run(
                [sys.executable, str(TOOLS / "manage-ymm4-version.py"),
                 "--store", str(store), "--activate", "4.55.1.1-Lite"],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(rollback.returncode, 0, rollback.stderr)
            self.assertEqual((store / "current").resolve(), (store / "4.55.1.1-Lite").resolve())
            self.assertTrue((store / "4.56.0.0-Lite/YukkuriMovieMaker.exe").is_file())

    def test_version_switch_refuses_existing_directory_channel(self):
        with tempfile.TemporaryDirectory() as directory:
            store = Path(directory)
            installed = store / "4.55.1.1-Lite"
            installed.mkdir()
            (installed / "YukkuriMovieMaker.exe").write_bytes(minimal_pe())
            (store / "current").mkdir()
            completed = subprocess.run(
                [sys.executable, str(TOOLS / "manage-ymm4-version.py"),
                 "--store", str(store), "--activate", "4.55.1.1-Lite"],
                text=True, capture_output=True, check=False,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertTrue((store / "current").is_dir())

    def test_version_switch_refuses_symlinked_install(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as outside:
            store = Path(directory)
            external = Path(outside) / "4.55.1.1-Lite"
            external.mkdir()
            (external / "YukkuriMovieMaker.exe").write_bytes(minimal_pe())
            (store / "4.55.1.1-Lite").symlink_to(external, target_is_directory=True)
            completed = subprocess.run(
                [sys.executable, str(TOOLS / "manage-ymm4-version.py"),
                 "--store", str(store), "--activate", "4.55.1.1-Lite"],
                text=True, capture_output=True, check=False,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertFalse((store / "current").exists())

    def test_version_switch_refuses_external_channel(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as outside:
            store = Path(directory)
            installed = store / "4.55.1.1-Lite"
            installed.mkdir()
            (installed / "YukkuriMovieMaker.exe").write_bytes(minimal_pe())
            external = Path(outside) / "external"
            external.mkdir()
            (store / "current").symlink_to(external, target_is_directory=True)
            completed = subprocess.run(
                [sys.executable, str(TOOLS / "manage-ymm4-version.py"),
                 "--store", str(store), "--activate", "4.55.1.1-Lite"],
                text=True, capture_output=True, check=False,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertEqual((store / "current").resolve(), external.resolve())


if __name__ == "__main__":
    unittest.main()
