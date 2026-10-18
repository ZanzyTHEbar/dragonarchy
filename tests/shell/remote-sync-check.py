#!/usr/bin/env python3
"""Isolated remote bundle/transaction checks; no SSH or Ansible execution."""
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("remote_sync", ROOT / "scripts/lib/remote-sync.py")
remote_sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(remote_sync)


class RemoteSyncTest(unittest.TestCase):
    def test_cleanup_repairs_readonly_directories_without_following_links(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            root = base / 'staging'
            readonly = root / 'readonly'
            readonly.mkdir(parents=True)
            (readonly / 'payload').write_text('owned')
            sentinel = base / 'outside'
            sentinel.mkdir()
            (sentinel / 'file').write_text('preserve')
            (root / 'external').symlink_to(sentinel)
            readonly.chmod(0o555)
            result = subprocess.run([sys.executable, '-c', remote_sync.CLEANUP_CODE, str(root)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(root.exists())
            self.assertEqual((sentinel / 'file').read_text(), 'preserve')

    def test_archive_transport_preserves_metadata(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            bundle = root / "bundle"
            bundle.mkdir()
            for name, mode in (("private", 0o700), ("readonly", 0o555), ("shared", 0o777)):
                directory = bundle / name
                directory.mkdir()
                (directory / "tool").write_text("#!/bin/sh\nexit 0\n")
                (directory / "tool").chmod(0o751)
                (directory / "link").symlink_to("tool")
                directory.chmod(mode)
                os.utime(directory, (1700000000, 1700000000))
            (root / "controller-secret").write_text("never transfer")
            archive = root / "payload.tar"
            remote_sync.create_archive(bundle, archive)
            extracted = root / "target"
            extracted.mkdir()
            subprocess.run(["tar", "--extract", "--file", str(archive), "--directory", str(extracted),
                            "--same-permissions", "--no-same-owner"], check=True,
                           env={**os.environ, "TAR_OPTIONS": ""}, umask=0o077)
            self.assertFalse((extracted / "controller-secret").exists())
            for directory in bundle.iterdir():
                target = extracted / directory.name
                self.assertEqual(target.stat().st_mode & 0o7777, directory.stat().st_mode & 0o7777)
                self.assertEqual(int(target.stat().st_mtime), 1700000000)
                self.assertEqual((target / "tool").stat().st_mode & 0o7777, 0o751)
                self.assertEqual((target / "tool").read_bytes(), (directory / "tool").read_bytes())
                self.assertEqual((target / "link").readlink(), Path("tool"))
                self.assertEqual(target.stat().st_uid, os.geteuid())

    def test_archive_rejects_escaping_symlinks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            bundle = root / "bundle"
            bundle.mkdir()
            link = bundle / "link"
            for destination in ("/etc/passwd", "../outside"):
                link.symlink_to(destination)
                with self.assertRaisesRegex(ValueError, "symlink"):
                    remote_sync.create_archive(bundle, root / "payload.tar")
                link.unlink()

    def test_transport_plan_uses_selected_user_and_cleans_staging(self):
        archive_path = None

        def bundle_fixture(repo, bundle, host):
            bundle.mkdir()
            (bundle / "payload").write_text("fixture")

        def run_mock(argv):
            nonlocal archive_path
            if argv[0] == "ansible-playbook":
                play, = json.loads(Path(argv[3]).read_text())
                self.assertTrue(play["become"])
                self.assertEqual(play["become_user"], "remoteuser")
                self.assertEqual(play["environment"], {"HOME": "/remote/home/remoteuser"})
                guard, = play["pre_tasks"]
                self.assertEqual(guard["ansible.builtin.command"]["argv"], [
                    "python3", "-c", "import os, sys; sys.exit(os.geteuid() == 0)"])
                for uid in (0, 1000):
                    with patch.object(os, "geteuid", return_value=uid):
                        with self.assertRaises(SystemExit) as guarded:
                            exec(guard["ansible.builtin.command"]["argv"][-1], {})
                    self.assertEqual(guarded.exception.code, uid == 0)
                stage, transaction = play["tasks"]
                self.assertEqual(stage["ansible.builtin.tempfile"]["state"], "directory")
                extract = transaction["block"][0]["ansible.builtin.unarchive"]
                self.assertEqual(extract["extra_opts"], ["--same-permissions", "--no-same-owner"])
                self.assertFalse(extract["remote_src"])
                self.assertNotIn("mode", extract)
                archive_path = Path(extract["src"])
                self.assertTrue(archive_path.is_file())
                cleanup, = transaction["always"]
                self.assertEqual(cleanup["ansible.builtin.command"]["argv"], [
                    "python3", "-c", remote_sync.CLEANUP_CODE, "{{ dotfiles_remote_stage.path }}"])
                return subprocess.CompletedProcess(argv, 42)
            return subprocess.CompletedProcess(argv, 0)

        argv = ["remote-sync.py", "--inventory", "fixture.yml", "--host", "fixture",
                "--user", "remoteuser", "--home", "/remote/home/remoteuser",
                "--source", "/remote/home/remoteuser/.local/share/chezmoi"]
        with patch.object(sys, "argv", argv), patch.object(remote_sync, "build_bundle", bundle_fixture), \
                patch.object(remote_sync.subprocess, "run", run_mock):
            with self.assertRaises(SystemExit) as result:
                remote_sync.main()
        self.assertEqual(result.exception.code, 42)
        self.assertIsNotNone(archive_path)
        self.assertFalse(archive_path.parent.exists())

        argv[argv.index("remoteuser")] = "root"
        with patch.object(sys, "argv", argv), patch.object(sys, "stderr"), \
                patch.object(remote_sync, "build_bundle") as build:
            with self.assertRaises(SystemExit) as result:
                remote_sync.main()
            self.assertEqual(result.exception.code, 2)
            build.assert_not_called()

    def test_bundle_and_target_transaction(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = root / "repo"
            manifests = repo / "infra/chezmoi/manifests"
            manifests.mkdir(parents=True)
            (repo / "infra/chezmoi/bin").mkdir()
            (repo / "scripts/lib").mkdir(parents=True)
            for name in ("target-tuple.py",):
                (repo / "scripts/lib" / name).write_bytes((ROOT / "scripts/lib" / name).read_bytes())
            engine = repo / "infra/chezmoi/bin/chezmoi-sync"
            engine.write_bytes((ROOT / "infra/chezmoi/bin/chezmoi-sync").read_bytes())
            engine.chmod(0o755)
            shutil.copytree(ROOT / "infra/chezmoi/lib", repo / "infra/chezmoi/lib",
                            ignore=shutil.ignore_patterns("__pycache__"))
            payload = repo / "packages/test/config"
            payload.mkdir(parents=True)
            (payload / "owned").write_text("old")
            (payload / "secret").write_text("never transfer")
            (repo / "controller-secret").write_text("never transfer")
            (payload / "link").symlink_to("owned")
            (payload / "tool").write_text("#!/bin/sh\nexit 0\n")
            (payload / "tool").chmod(0o755)
            manifest = manifests / "test.manifest"
            manifest.write_text("required|packages/test/config|dot_config/test\nexclude||dot_config/test/secret\n")
            home = root / "home"
            source = home / ".local/share/chezmoi"
            source.mkdir(parents=True)
            (source / "neighbor").write_text("keep")

            def sync(bundle):
                remote_sync.build_bundle(repo, bundle, "fixture")
                self.assertFalse((bundle / "controller-secret").exists())
                self.assertFalse((bundle / "packages/test/config/secret").exists())
                self.assertTrue((bundle / "packages/test/config/link").is_symlink())
                archive = bundle.with_suffix(".tar")
                remote_sync.create_archive(bundle, archive)
                extracted = bundle.with_name(bundle.name + "-remote")
                extracted.mkdir()
                subprocess.run(["tar", "--extract", "--file", str(archive), "--directory", str(extracted),
                                "--same-permissions", "--no-same-owner"], check=True)
                result = subprocess.run(["bash", str(extracted / "infra/chezmoi/bin/chezmoi-sync"),
                                         "--host", "fixture", "--source-dir", str(source)],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

            sync(root / "bundle1")
            self.assertEqual((source / "dot_config/test/symlink_link").read_text(), "owned")
            self.assertTrue((source / "dot_config/test/executable_tool").stat().st_mode & 0o111)
            (source / "dot_config/test/unowned").write_text("keep too")
            (payload / "owned").unlink()
            (payload / "new").write_text("new")
            sync(root / "bundle2")
            self.assertFalse((source / "dot_config/test/owned").exists())
            self.assertEqual((source / "dot_config/test/unowned").read_text(), "keep too")
            self.assertEqual((source / "neighbor").read_text(), "keep")
            (payload / "new").write_text("changed")
            bundle = root / "bundle3"
            remote_sync.build_bundle(repo, bundle, "fixture")
            result = subprocess.run(["bash", str(bundle / "infra/chezmoi/bin/chezmoi-sync"),
                                     "--host", "fixture", "--source-dir", str(source)],
                                    env={**os.environ, "CHEZMOI_SYNC_FAILPOINT": "copy:1"},
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((source / "dot_config/test/new").read_text(), "new")
            sync(root / "bundle4")
            self.assertEqual((source / "dot_config/test/new").read_text(), "changed")
            result = subprocess.run(["bash", str(bundle / "infra/chezmoi/bin/chezmoi-sync"),
                                     "--host", "fixture", "--source-dir", str(source)],
                                    env={**os.environ, "CHEZMOI_SYNC_FAILPOINT": "promote:after-park"},
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(Path(str(source) + ".chezmoi-sync-backup").is_dir())
            sync(root / "bundle5")
            self.assertEqual((source / "neighbor").read_text(), "keep")
            self.assertEqual((source / "dot_config/test/unowned").read_text(), "keep too")
            self.assertFalse(Path(str(source) + ".chezmoi-sync-backup").exists())
            self.assertTrue(Path(str(source) + ".chezmoi-sync-lock").is_file())
            (payload / "id_ed25519").write_text("not a distributable")
            unsafe = root / "unsafe-content"
            remote_sync.build_bundle(repo, unsafe, "fixture")
            result = subprocess.run(["bash", str(unsafe / "infra/chezmoi/bin/chezmoi-sync"),
                                     "--host", "fixture", "--source-dir", str(root / "isolated-preflight")],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Unsafe distributable artifact", result.stderr)
            self.assertFalse((root / "isolated-preflight").exists())
            package = repo / "packages/test"
            package.rename(root / "outside-package")
            package.symlink_to(root / "outside-package")
            with self.assertRaisesRegex(ValueError, "ancestor is a symlink"):
                remote_sync.build_bundle(repo, root / "unsafe-bundle", "fixture")

    def test_target_path_check_rejects_symlinks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            home = root / "home"
            home.mkdir()
            link = root / "link"
            link.symlink_to(home)
            result = subprocess.run(["python3", str(ROOT / "scripts/lib/target-tuple.py"),
                                     "check-paths", str(link), str(link / ".local/share/chezmoi")],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("symlink", result.stderr)
            result = subprocess.run(["python3", str(ROOT / "scripts/lib/target-tuple.py"),
                                     "check-paths", "/" + str(home), "/" + str(home / ".local/share/chezmoi")],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("lexically canonical", result.stderr)
            source = home / ".local/share/chezmoi"
            source.parent.mkdir(parents=True)
            source.symlink_to(root / "elsewhere")
            result = subprocess.run(["python3", str(ROOT / "scripts/lib/target-tuple.py"),
                                     "check-paths", str(home), str(source)],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("symlink", result.stderr)


if __name__ == "__main__":
    unittest.main()
