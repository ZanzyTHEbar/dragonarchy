"""Run with python3 tests/shell/host-scope-check.py; no live tools or hosts."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]
ACTIVE = {"firedragon", "microdragon", "opencode-runtime", "ubuntu-mobile-dev"}
ARCHIVED = {"dragon", "goldendragon"}


class HostScope(unittest.TestCase):
    def test_inventory_and_archived_payload_boundary(self):
        inventory = yaml.safe_load((ROOT / "infra/ansible/inventory/hosts.yml").read_text())
        hosts = set()

        def collect(group):
            hosts.update(group.get("hosts") or {})
            for child in (group.get("children") or {}).values():
                collect(child)

        collect(inventory["all"])
        self.assertEqual(hosts, ACTIVE)
        for host in ACTIVE:
            self.assertTrue((ROOT / "infra/ansible/inventory/host_vars" / f"{host}.yml").is_file())
        for host in ARCHIVED:
            archive = ROOT / "hosts/legacy" / host
            for payload in ("setup.sh", ".traits", "host_vars.yml",
                            f"dotfiles/.config/zsh/hosts/{host}.zsh"):
                self.assertTrue((archive / payload).is_file(), archive / payload)
            self.assertTrue((archive / "etc").is_dir())
            self.assertFalse((ROOT / "hosts" / host).exists())
            # Ansible accepts host_vars as YAML/JSON files or per-host directories.
            host_vars = ROOT / "infra/ansible/inventory/host_vars"
            self.assertFalse(any(path.name.split(".")[0] == host for path in host_vars.iterdir()))

    def test_shared_manifest_has_no_archived_watchdog(self):
        manifest = (ROOT / "infra/chezmoi/manifests/session-shell.manifest").read_text()
        self.assertNotIn("fprintd-watchdog", manifest)

    def test_parity_requires_membership_not_successful_host_query(self):
        with tempfile.TemporaryDirectory() as directory:
            mock = Path(directory) / "ansible-inventory"
            inventory = json.dumps({"all": {"children": ["active"]},
                                    "active": {"hosts": sorted(ACTIVE)},
                                    "_meta": {"hostvars": {}}})
            # Real Ansible can return {} and success for --host on a nonmember.
            mock.write_text("#!/bin/sh\ncase \"$*\" in\n"
                            f"  *--list*) printf '%s\\n' '{inventory}' ;;\n"
                            "  *) printf '%s\\n' '{}' ;;\nesac\n")
            mock.chmod(0o755)
            env = dict(os.environ, PATH=f"{directory}:{os.environ['PATH']}")
            for host in sorted(ACTIVE | ARCHIVED | {"unknown-host"}):
                with self.subTest(host=host):
                    result = subprocess.run(
                        ["bash", str(ROOT / "infra/validate-parity.sh"), "--host", host],
                        env=env, capture_output=True, text=True, timeout=30)
                    if host in ACTIVE:
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    else:
                        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertIn("not found in inventory", result.stderr)
                        self.assertNotIn("==> Chezmoi manifest parity", result.stdout)


if __name__ == "__main__":
    unittest.main()
