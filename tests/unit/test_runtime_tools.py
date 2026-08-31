from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"


class RuntimeLockTests(unittest.TestCase):
    def test_validator_accepts_matching_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock = root / "runtime.lock.json"
            inventory = root / "inventory.json"
            catalog = root / "ymm4-releases.json"
            lock.write_text(json.dumps({"ymm4": {
                "archiveSha256": "archive",
                "executableSha256": "a" * 64,
            }}))
            inventory.write_text(json.dumps({
                "archive": {"sha256": "archive"},
                "primaryExecutable": {"sha256": "a" * 64},
                "gate": {"passed": True},
            }))
            catalog.write_text(json.dumps({"releases": [{
                "archiveSha256": "archive",
                "executableSha256": "a" * 64,
                "classification": "knownCompatible",
            }]}))
            completed = subprocess.run(
                [sys.executable, str(TOOLS / "validate-runtime-lock.py"),
                 "--lock", str(lock), "--inventory", str(inventory),
                 "--catalog", str(catalog)],
                text=True, capture_output=True, check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_validator_rejects_executable_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lock = root / "runtime.lock.json"
            inventory = root / "inventory.json"
            catalog = root / "ymm4-releases.json"
            lock.write_text(json.dumps({"ymm4": {
                "archiveSha256": "archive",
                "executableSha256": "wrong",
            }}))
            inventory.write_text(json.dumps({
                "archive": {"sha256": "archive"},
                "primaryExecutable": {"sha256": "executable"},
                "gate": {"passed": True},
            }))
            catalog.write_text(json.dumps({"releases": [{
                "archiveSha256": "archive",
                "executableSha256": "a" * 64,
                "classification": "knownCompatible",
            }]}))
            completed = subprocess.run(
                [sys.executable, str(TOOLS / "validate-runtime-lock.py"),
                 "--lock", str(lock), "--inventory", str(inventory),
                 "--catalog", str(catalog)],
                text=True, capture_output=True, check=False,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("executable SHA-256 mismatch", completed.stderr)


class PrefixEnvironmentTests(unittest.TestCase):
    def test_create_prefix_does_not_forward_secret_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            prefix = root / "prefix"
            fake_wine = root / "wine"
            fake_wine.write_text(
                "#!/bin/sh\n"
                "test -z \"${AWS_SECRET_ACCESS_KEY:-}\" || exit 91\n"
                "test -z \"${YMM4M_TEST_SENTINEL:-}\" || exit 92\n"
                "test \"${YMM4M_ENV_SANITIZED:-}\" = 1 || exit 93\n"
                "if test \"${1:-}\" = reg; then\n"
                "  printf '%s\\n' '[Software\\\\Microsoft\\\\Avalon.Graphics] 1' '\"DisableHWAcceleration\"=dword:00000001' > \"$WINEPREFIX/user.reg\"\n"
                "fi\n"
                "exit 0\n"
            )
            fake_wine.chmod(0o755)
            fake_wineserver = root / "wineserver"
            fake_wineserver.write_text("#!/bin/sh\nexit 0\n")
            fake_wineserver.chmod(0o755)
            environment = os.environ.copy()
            environment.update({
                "YMM4M_WINE": str(fake_wine),
                "YMM4M_PREFIX": str(prefix),
                "YMM4M_TEST_SENTINEL": "must-not-leak",
                "AWS_SECRET_ACCESS_KEY": "must-not-leak",
            })

            completed = subprocess.run(
                [str(TOOLS / "create-prefix.sh")],
                env=environment, text=True, capture_output=True, check=False,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertTrue((prefix / "ymm4m-prefix.json").is_file())


class RuntimeBootstrapTests(unittest.TestCase):
    def test_bootstrap_requires_explicit_consent(self):
        completed = subprocess.run(
            [str(TOOLS / "bootstrap-wine-dxmt-runtime.sh"), "--plan"],
            text=True, capture_output=True, check=False,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("explicit --accept-third-party", completed.stderr)

    def test_bootstrap_plan_uses_only_pinned_https_sources(self):
        lock = json.loads((ROOT / "runtime/bootstrap.lock.json").read_text())
        self.assertEqual(lock["schema"], 1)
        self.assertEqual(set(lock["sources"]), {
            "wineSource", "wineMacBase", "freetypeSource", "dxmt", "nvapi",
            "directxHeaders", "notoSansCJKJP",
        })
        for source in lock["sources"].values():
            self.assertTrue(source["url"].startswith("https://"))
            self.assertRegex(source["sha256"], r"^[0-9a-f]{64}$")

        completed = subprocess.run(
            [str(TOOLS / "bootstrap-wine-dxmt-runtime.sh"),
             "--accept-third-party", "--plan",
             "--runtime", "/tmp/ymm4m-plan-runtime",
             "--prefix", "/tmp/ymm4m-plan-prefix"],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn(lock["sources"]["wineSource"]["url"], completed.stdout)
        self.assertIn(lock["sources"]["freetypeSource"]["url"], completed.stdout)
        self.assertIn(lock["sources"]["dxmt"]["url"], completed.stdout)
        self.assertIn("No YMM4", completed.stdout)

    def test_bootstrap_rejects_whitespace_in_compile_paths(self):
        environment = os.environ.copy()
        environment["YMM4M_SOURCE_ROOT"] = "/tmp/ymm4m source"
        environment["YMM4M_BUILD_ROOT"] = "/tmp/ymm4m-build"
        completed = subprocess.run(
            [str(TOOLS / "bootstrap-wine-dxmt-runtime.sh"),
             "--accept-third-party", "--plan",
             "--runtime", "/tmp/ymm4m-plan-runtime"],
            env=environment, text=True, capture_output=True, check=False,
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("must not contain whitespace", completed.stderr)

    def test_bootstrap_pins_verified_mingw_versions(self):
        script = (TOOLS / "bootstrap-wine-dxmt-runtime.sh").read_text()
        self.assertIn('15.2.0|16.2.0)', script)
        self.assertIn("Refusing to publish an unverified runtime hash variant.", script)


if __name__ == "__main__":
    unittest.main()
