"""Run with python3 tests/shell/mobile-safety-check.py; no phone required."""
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest
import tomllib
import json
import stat

ROOT = Path(__file__).resolve().parents[2]


class MobileSafety(unittest.TestCase):
    def test_snapshot_restore_preserves_contents_modes_links_and_absence(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            home = base / "home"
            widgets = home / ".config/omalauncher/widgets"
            widgets.mkdir(parents=True)
            original = widgets / "01-device-status.owl"
            original.write_text("original")
            original.chmod(0o640)
            link = widgets / "02-dev-launcher.owl"
            link.symlink_to("01-device-status.owl")
            neighbor = widgets / "personal.owl"
            neighbor.write_text("unmanaged")
            backup = base / "snapshot.json"

            def run(script, *args):
                return subprocess.run(
                    ["bash", str(ROOT / "scripts/mobile" / script),
                     "--home", str(home), "--backup", str(backup), *args],
                    capture_output=True, text=True)

            result = run("snapshot.sh")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(stat.S_IMODE(backup.stat().st_mode), 0o600)
            saved = backup.read_text()
            self.assertNotEqual(run("snapshot.sh").returncode, 0, "Never overwrite a backup")
            original.write_text("new")
            original.chmod(0o600)
            link.unlink()
            link.write_text("replaced link")
            added = widgets / "03-agent-status.owl"
            added.write_text("newly deployed")
            result = run("rollback.sh")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(original.read_text(), "new", "Plan must not mutate")
            result = run("rollback.sh", "--mode", "apply")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(original.read_text(), "original")
            self.assertEqual(stat.S_IMODE(original.stat().st_mode), 0o640)
            self.assertEqual(os.readlink(link), "01-device-status.owl")
            self.assertFalse(added.exists())
            self.assertEqual(neighbor.read_text(), "unmanaged")
            result = run("rollback.sh", "--mode", "apply")
            self.assertEqual(result.returncode, 0, result.stderr)

            data = json.loads(backup.read_text())
            data["files"]["../../outside"] = {"kind": "absent"}
            backup.write_text(json.dumps(data))
            result = run("rollback.sh", "--mode", "apply")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(original.read_text(), "original")

            data = json.loads(saved)
            data["files"][".config/omalauncher/widgets/01-device-status.owl"]["sha256"] = "corrupt"
            backup.write_text(json.dumps(data))
            self.assertNotEqual(run("rollback.sh", "--mode", "apply").returncode, 0)
            self.assertEqual(original.read_text(), "original")
            backup.write_text(saved)
            original.unlink()
            original.mkdir()
            self.assertNotEqual(run("rollback.sh", "--mode", "apply").returncode, 0,
                                "Unexpected directories must never be removed")
            self.assertTrue(original.is_dir())
            original.rmdir()
            original.write_text("original")
            (home / ".config").rename(base / "config")
            outside = base / "outside"
            outside.mkdir()
            (home / ".config").symlink_to(outside, target_is_directory=True)
            self.assertNotEqual(run("rollback.sh", "--mode", "apply").returncode, 0)
            self.assertEqual(list(outside.iterdir()), [])

    def test_real_profile_defaults_to_canonical_gruvbox(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source"
            result = subprocess.run(
                ["bash", str(ROOT / "infra/chezmoi/bin/chezmoi-sync"),
                 "--host", "poco-x3-pro", "--profile", "mobile",
                 "--source-dir", str(source)], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            style = source / "dot_config/omalauncher/style/style.toml"
            self.assertTrue(style.is_file(), "Profile must select a default theme, not only copy colors")
            self.assertEqual(tomllib.loads(style.read_text())["theme"], "gruvbox")
            palette = source / "dot_config/omarchy/themes/gruvbox/alacritty.toml"
            self.assertEqual(palette.read_bytes(),
                             (ROOT / "packages/themes/.config/themes/gruvbox/alacritty.toml").read_bytes())
            self.assertFalse((source / "dot_config/hypr").exists())

    def test_mobile_profile_is_host_bound_and_isolated(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            repo = base / "repo"
            script = repo / "infra/chezmoi/bin/chezmoi-sync"
            script.parent.mkdir(parents=True)
            shutil.copy2(ROOT / "infra/chezmoi/bin/chezmoi-sync", script)
            shutil.copytree(ROOT / "infra/chezmoi/lib", repo / "infra/chezmoi/lib")
            manifests = repo / "infra/chezmoi/manifests"
            (manifests / "mobile").mkdir(parents=True)
            package = repo / "packages/fixture"
            package.mkdir(parents=True)
            (package / "file").write_text("fixture\n")
            (repo / "infra/chezmoi/host-selection.json").write_text(json.dumps({
                "inventory_hostname": "desktop", "host_desktop_stack": "none"}))
            for name in ("git-ssh", "session-zsh"):
                (manifests / (name + ".manifest")).touch()
            (manifests / "devtools-core.manifest").write_text(
                "required|packages/fixture/file|dot_desktop\n")
            (manifests / "mobile/common.manifest").write_text(
                "required|packages/fixture/file|dot_mobile_common\n")
            (manifests / "mobile/mobile.manifest").write_text(
                "required|packages/fixture/file|dot_launcher\n")
            source = base / "source"
            command = ["bash", str(script), "--host", "poco-x3-pro",
                       "--source-dir", str(source)]
            result = subprocess.run(command + ["--profile", "mobile"], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual({p.name for p in source.iterdir()},
                             {"dot_mobile_common", "dot_launcher"})
            home = base / "home"
            legacy_source = home / ".local/share/chezmoi"
            legacy_source.mkdir(parents=True)
            (legacy_source / "sentinel").write_text("untouched")
            result = subprocess.run(
                ["bash", str(script), "--host", "poco-x3-pro", "--profile", "mobile"],
                env={**os.environ, "HOME": str(home)}, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual({p.name for p in legacy_source.iterdir()}, {"sentinel"})
            self.assertTrue((home / ".local/share/dragonarchy/poco-x3-pro/omalauncher/chezmoi/dot_launcher").is_file())
            for host, profile in [("desktop", "mobile"), ("poco-x3-pro", "common"),
                                  ("poco-x3-pro", "../mobile"), ("poco-x3-pro", "")]:
                result = subprocess.run(
                    ["bash", str(script), "--host", host, "--profile", profile,
                     "--source-dir", str(base / "rejected")], capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((base / "rejected").exists())
            legacy = base / "legacy"
            result = subprocess.run(
                ["bash", str(script), "--host", "desktop", "--source-dir", str(legacy)],
                capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual({p.name for p in legacy.iterdir()}, {"dot_desktop"})

    def test_unfinished_mutators_fail_without_writing_home(self):
        cases = [
            ("deploy.sh", "--target", "poco-x3-pro", "--runtime", "omalauncher",
             "--mode", "apply", "--revision", "unapproved"),
            ("bootstrap.sh", "--runtime", "omalauncher"),
        ]
        with tempfile.TemporaryDirectory() as home:
            for script, *args in cases:
                with self.subTest(script=script):
                    result = subprocess.run(
                        ["bash", str(ROOT / "scripts/mobile" / script), *args],
                        env={**os.environ, "HOME": home}, capture_output=True, text=True,
                    )
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("disabled", result.stderr.lower())
                    self.assertEqual(list(Path(home).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
