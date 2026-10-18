#!/usr/bin/env python3
"""Ship only manifest inputs and run the existing transaction engine on the target."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tarfile
import tempfile


# The tempfile is owned by the selected user. Repair only directory permissions,
# without traversing symlinks, before removing read-only payloads from staging.
CLEANUP_CODE = '''import os, shutil, stat, sys
root = sys.argv[1]
if os.path.lexists(root):
    if os.path.islink(root) or not os.path.isdir(root):
        raise ValueError("remote staging root is not a real directory")
    for directory, dirs, files in os.walk(root, topdown=True, followlinks=False):
        os.chmod(directory, stat.S_IMODE(os.stat(directory).st_mode) | 0o700)
    shutil.rmtree(root)
'''


def relative_path(value):
    if not value or value.startswith("/") or any(p in {"", ".", ".."} for p in value.split("/")):
        raise ValueError(f"Invalid manifest path: {value}")
    return value


def encoded_name(name):
    # Match chezmoi-sync's literal/dot encoding; permission attributes are
    # irrelevant here because exclusions normalize those attributes away.
    reserved = r"^(dot_|executable_|private_|symlink_|literal_|empty_|readonly_|create_|modify_|remove_|exact_|run_|once_|encrypted_|after_|before_|external_|onchange_)|\.tmpl$"
    stem = name[1:] if name.startswith(".") else name
    encoded = ("dot_" if name.startswith(".") else "") + ("literal_" if re.search(reserved, stem) else "") + stem
    return encoded + (".tmpl" if encoded.endswith(".tmpl") else "")


def build_bundle(repo, bundle, host):
    records = []
    manifests = sorted((repo / "infra/chezmoi/manifests").glob("*.manifest"))
    if not manifests:
        raise ValueError("No manifests found")
    for manifest in manifests:
        if manifest.is_symlink():
            raise ValueError(f"Manifest is a symlink: {manifest}")
        for line in manifest.read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            mode, source, dest = line.replace("__HOST__", host).split("|")
            relative_path(dest)
            if mode == "exclude":
                if source:
                    raise ValueError("Exclude source must be empty")
            elif mode in {"required", "optional"}:
                relative_path(source)
                if not source.startswith(("packages/", f"hosts/{host}/dotfiles/")):
                    raise ValueError(f"Source outside allowed roots: {source}")
            else:
                raise ValueError(f"Unknown manifest mode: {mode}")
            records.append((mode, source, dest))

    def normalized(path):
        return "/".join(re.sub(r"^(?:(?:private|readonly|empty|executable|symlink)_)+", "", p)
                        for p in path.split("/"))

    excluded = {normalized(dest) for mode, _, dest in records if mode == "exclude"}

    def copy_payload(source, target, destination):
        if normalized(destination) in excluded:
            return
        mode = source.lstat().st_mode
        target.parent.mkdir(parents=True, exist_ok=True)
        if stat.S_ISLNK(mode):
            if not target.is_symlink():
                target.symlink_to(source.readlink())
        elif stat.S_ISDIR(mode):
            target.mkdir(exist_ok=True)
            for child in source.iterdir():
                copy_payload(child, target / child.name, destination + "/" + encoded_name(child.name))
            shutil.copystat(source, target, follow_symlinks=False)
        elif stat.S_ISREG(mode):
            shutil.copy2(source, target)
        else:
            raise ValueError(f"Unsupported payload type: {source}")

    for mode, source, dest in records:
        if mode == "exclude":
            continue
        path = repo / source
        for parent in path.parents:
            if parent == repo:
                break
            if parent.is_symlink():
                raise ValueError(f"Source ancestor is a symlink: {parent}")
        if not path.exists() and not path.is_symlink():
            if mode == "required":
                raise ValueError(f"Required source missing: {source}")
            continue
        copy_payload(path, bundle / source, dest)
    for path in [*manifests, repo / "infra/chezmoi/bin/chezmoi-sync",
                 *sorted((repo / "infra/chezmoi/lib").glob("*.py")), repo / "scripts/lib/target-tuple.py"]:
        target = bundle / path.relative_to(repo)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)


def create_archive(bundle, archive):
    def validate_member(member):
        relative_path(member.name)
        if member.issym():
            target = os.path.normpath(os.path.join(os.path.dirname(member.name), member.linkname))
            if os.path.isabs(member.linkname) or target == ".." or target.startswith("../"):
                raise ValueError(f"Archive symlink escapes payload: {member.name}")
        elif not (member.isdir() or member.isfile()):
            raise ValueError(f"Unsupported archive entry: {member.name}")
        return member

    # Only our validated bundle is archived; never follow payload symlinks.
    with tarfile.open(archive, "w", dereference=False) as output:
        for path in sorted(bundle.iterdir()):
            output.add(path, arcname=path.name, filter=validate_member)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("inventory", "host", "user", "home", "source"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    if not args.user or args.user == "root":
        parser.error("--user must select a non-root account")
    repo = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="dotfiles-remote-", dir="/tmp/opencode" if Path("/tmp/opencode").is_dir() else None) as temp:
        bundle = Path(temp) / "repo"
        build_bundle(repo, bundle, args.host)
        # Reject unsafe distributable content before any bytes leave the controller.
        # This isolated source is never the SSH target's filesystem path.
        sync = os.environ.get("DOTFILES_CHEZMOI_SYNC") or str(bundle / "infra/chezmoi/bin/chezmoi-sync")
        validation = subprocess.run([sync, "--host", args.host, "--source-dir", str(Path(temp) / "validation")])
        if validation.returncode:
            raise SystemExit(validation.returncode)
        archive = Path(temp) / "payload.tar"
        create_archive(bundle, archive)
        remote = "{{ dotfiles_remote_stage.path }}"
        play = [{"hosts": args.host, "gather_facts": False, "become": True,
                 "become_user": args.user, "environment": {"HOME": args.home},
                 "pre_tasks": [{"name": "Require selected non-root execution", "ansible.builtin.command": {
                     "argv": ["python3", "-c", "import os, sys; sys.exit(os.geteuid() == 0)"]}, "changed_when": False}],
                 "tasks": [
            {"name": "Create isolated remote payload directory", "ansible.builtin.tempfile": {
                "state": "directory", "prefix": "dotfiles-chezmoi-"}, "register": "dotfiles_remote_stage"},
            {"block": [
                {"name": "Extract isolated payload preserving directory modes", "ansible.builtin.unarchive": {
                    "src": str(archive), "dest": remote + "/", "remote_src": False,
                    "extra_opts": ["--same-permissions", "--no-same-owner"]}},
                {"name": "Validate target filesystem before mutation", "ansible.builtin.command": {"argv": [
                    "python3", remote + "/scripts/lib/target-tuple.py", "check-paths", args.home, args.source]}, "changed_when": False},
                {"name": "Reconcile owned source paths transactionally", "ansible.builtin.command": {"argv": [
                    "bash", remote + "/infra/chezmoi/bin/chezmoi-sync", "--host", args.host, "--source-dir", args.source]}},
                {"ansible.builtin.command": {"argv": ["chezmoi", "--source", args.source, "--destination", args.home, "apply"]}},
            ], "always": [{"name": "Remove isolated remote payload directory", "ansible.builtin.command": {
                "argv": ["python3", "-c", CLEANUP_CODE, remote]}}]},
        ]}]
        playbook = Path(temp) / "sync.json"
        playbook.write_text(json.dumps(play))
        raise SystemExit(subprocess.run(["ansible-playbook", "-i", args.inventory, str(playbook),
                                        "--limit", args.host, "--connection", "ssh"]).returncode)


if __name__ == "__main__":
    main()
