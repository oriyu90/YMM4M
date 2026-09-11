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
                "test \"${WINEDEBUG:-}\" = -all || exit 94\n"
                "test \"${WINEDLLOVERRIDES:-}\" = winedbg.exe=d || exit 95\n"
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

    def test_create_prefix_stops_wine_processes_after_initialization_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            prefix = root / "prefix"
            fake_wine = root / "wine"
            fake_wine.write_text("#!/bin/sh\nexit 7\n")
            fake_wine.chmod(0o755)
            cleanup_marker = root / "wineserver-cleanup"
            fake_wineserver = root / "wineserver"
            fake_wineserver.write_text(
                f"#!/bin/sh\nprintf '%s\\n' \"$*\" >> '{cleanup_marker}'\nexit 0\n"
            )
            fake_wineserver.chmod(0o755)
            environment = os.environ.copy()
            environment.update({
                "YMM4M_WINE": str(fake_wine),
                "YMM4M_PREFIX": str(prefix),
            })

            completed = subprocess.run(
                [str(TOOLS / "create-prefix.sh")],
                env=environment, text=True, capture_output=True, check=False,
            )
            self.assertEqual(completed.returncode, 7)
            cleanup_calls = cleanup_marker.read_text()
            self.assertIn("-k", cleanup_calls)
            self.assertIn("-w", cleanup_calls)


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
        self.assertEqual(lock["schema"], 2)
        self.assertEqual(set(lock["sources"]), {
            "wineSource", "wineMacBase", "freetypeSource", "dxmt", "nvapi",
            "directxHeaders", "notoSansCJKJP", "llvm15Toolchain",
        })
        for source in lock["sources"].values():
            self.assertTrue(source["url"].startswith("https://"))
            self.assertRegex(source["sha256"], r"^[0-9a-f]{64}$")
            # Mirrors are alternate hosts for the SAME artifact. Each must be
            # HTTPS, must not reference CrossOver, and must either record its own
            # SHA-256 (a mirror the bootstrap may actually download from) or be
            # explicitly documentation-only via a note.
            for mirror in source.get("mirrors", []):
                self.assertTrue(mirror["url"].startswith("https://"))
                self.assertNotIn("crossover", mirror["url"].lower())
                if "sha256" in mirror:
                    self.assertRegex(mirror["sha256"], r"^[0-9a-f]{64}$")
                else:
                    self.assertIn("note", mirror)

        # The x86_64 LLVM 15 toolchain is a pinned build tool, not a runtime
        # component: it must never be staged into or shipped with the runtime.
        llvm = lock["sources"]["llvm15Toolchain"]
        self.assertEqual(llvm["version"], "15.0.7")
        self.assertIn("llvmorg-15.0.7", llvm["url"])
        self.assertEqual(llvm["archiveRoot"], "clang+llvm-15.0.7-x86_64-apple-darwin21.0")

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

    def test_bootstrap_accepts_a_mingw_version_range_not_an_exact_pin(self):
        # A1 / §4.1 案3: the runtime is accepted by a recorded compatibility
        # fixture gate (RosettaWineBackend schema 2), not by matching one of a
        # few audited whole-file PE hashes, so the cross toolchain is no longer
        # pinned to an exact patch level. The bootstrap still fails fast on a
        # toolchain too old to build Wine 11.0 and warns outside the tested range.
        script = (TOOLS / "bootstrap-wine-dxmt-runtime.sh").read_text()
        self.assertNotIn('15.2.0|16.2.0)', script)
        self.assertIn('mingw_major', script)
        self.assertIn('too old to build Wine 11.0', script)
        self.assertIn('outside the tested range', script)

    def test_bootstrap_preflights_rosetta_before_downloading(self):
        script = (TOOLS / "bootstrap-wine-dxmt-runtime.sh").read_text()
        self.assertIn("/usr/libexec/rosetta/oahd", script)
        self.assertIn("softwareupdate --install-rosetta", script)
        # The check must sit before the first download call.
        self.assertLess(
            script.index("/usr/libexec/rosetta/oahd"),
            script.index("download wineSource"),
        )

    def test_bootstrap_auto_fetches_pinned_llvm15_toolchain(self):
        script = (TOOLS / "bootstrap-wine-dxmt-runtime.sh").read_text()
        self.assertIn("download llvm15Toolchain", script)
        # The old dead-end error (no acquisition path) must be gone.
        self.assertNotIn(
            "Install the documented LLVM 15 toolchain before building DXMT.", script
        )

    def test_bootstrap_preflights_flex_and_missing_homebrew(self):
        # Wine's configure needs flex as well as bison; a fresh Mac without
        # either must stop before downloading, with a Homebrew-first remedy
        # when brew itself is absent.
        script = (TOOLS / "bootstrap-wine-dxmt-runtime.sh").read_text()
        self.assertIn("clang flex meson", script)
        self.assertIn("Install Homebrew first", script)
        # The one-pass remedy must point at a Brewfile the user actually has:
        # the copy shipped next to the script inside YMM4M.app, else the repo
        # root copy.
        self.assertIn("$tool_resources/Brewfile", script)
        self.assertIn("$repository_root/Brewfile", script)

    def test_bootstrap_fails_fast_without_free_space(self):
        # A ~10 GB build must not discover a full disk hours into the compile;
        # the lighter prefix-only path carries its own smaller gate.
        bootstrap = (TOOLS / "bootstrap-wine-dxmt-runtime.sh").read_text()
        self.assertIn("10 * 1024 * 1024", bootstrap)
        self.assertIn("Not enough free space for the compatibility build", bootstrap)
        setup_prefix = (TOOLS / "setup-prefix-from-runtime.sh").read_text()
        self.assertIn("2 * 1024 * 1024", setup_prefix)
        self.assertIn("Not enough free space for the Wine prefix", setup_prefix)

    def test_long_steps_report_liveness(self):
        # Multi-minute silent steps (downloads, compiles, wineboot) must keep
        # the host UI alive with bracketed phase lines the app forwards.
        for name in ("bootstrap-wine-dxmt-runtime.sh", "setup-prefix-from-runtime.sh"):
            script = (TOOLS / name).read_text()
            self.assertIn("ymm4m_heartbeat", script, name)
            self.assertIn("trap ymm4m_stop_heartbeat EXIT", script, name)
            self.assertIn("still working", script, name)

    def test_build_app_bundles_brewfile(self):
        # The DMG setup references `brew bundle --file=Brewfile`; the file
        # must actually ship inside YMM4M.app next to the bootstrap script.
        build_app = (TOOLS / "build-app.sh").read_text()
        self.assertIn('Brewfile "$bootstrap_resources/Brewfile"', build_app)

    def test_bootstrap_check_urls_probes_only_effective_download_candidates(self):
        # Mirrors without their own SHA-256 are documentation-only and are
        # never downloaded (see source_urls); probing them as failures broke
        # the scheduled availability gate for dead documentation links.
        script = (TOOLS / "bootstrap-wine-dxmt-runtime.sh").read_text()
        check_block = script[script.index('if test "$check_urls" = 1'):script.index('if test "$plan" = 1')]
        self.assertIn('source_urls "$key" | while', check_block)
        self.assertNotIn("mirrors.0.url", check_block)
        self.assertNotIn("mirrors.1.url", check_block)

    def test_unverified_archive_mirrors_are_documentation_only(self):
        # A mirror that asserts a Wayback snapshot must carry no SHA-256
        # until a status-200 capture is verified out-of-band; otherwise
        # download() would attempt a dead host and --check-urls would fail.
        lock = json.loads((ROOT / "runtime/bootstrap.lock.json").read_text())
        for name, source in lock["sources"].items():
            for mirror in source.get("mirrors", []):
                if "web.archive.org" in mirror["url"]:
                    self.assertNotIn(
                        "sha256", mirror,
                        f"{name}: unverified archive mirror must not carry a SHA-256",
                    )
                    self.assertIn("note", mirror)


if __name__ == "__main__":
    unittest.main()
