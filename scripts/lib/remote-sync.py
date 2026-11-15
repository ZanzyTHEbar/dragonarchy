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
import sys
import tarfile
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infra/chezmoi/lib'))
from host_selection import SNAPSHOT, select_manifests
from sync_manifest import allowed_source


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


def build_bundle(repo, bundle, host, inventory=None):
    records = []
    manifests, selection = select_manifests(repo, host, inventory)
    for manifest in manifests:
        if manifest.is_symlink():
            raise ValueError(f"Manifest is a symlink: {manifest}")
        for number, line in enumerate(manifest.read_bytes().decode('utf-8', 'surrogateescape').split('\n'), 1):
            if '\r' in line:
                raise ValueError(f'Manifest record contains CR at {manifest}:{number}')
            if not line or line.startswith("#"):
                continue
            fields = line.split('|')
            if len(fields) != 3:
                raise ValueError(f'Malformed manifest record at {manifest}:{number}')
            mode, source, dest = (field.replace('__HOST__', host) for field in fields)
            relative_path(dest)
            if mode == "exclude":
                if source:
                    raise ValueError("Exclude source must be empty")
            elif mode in {"required", "optional"}:
                relative_path(source)
                if not allowed_source(source, host):
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
    (bundle / SNAPSHOT).write_text(json.dumps(selection) + '\n')


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


def selected_user_pre_tasks(host, user):
    return [
        {'name': 'Require the exact selected host', 'ansible.builtin.assert': {
            'that': [f'ansible_play_hosts_all == [{json.dumps(host)}]']}},
        {'name': 'Require the selected non-root user', 'ansible.builtin.command': {
            'argv': ['python3', '-c',
                     'import os, pwd, sys; uid = os.geteuid(); sys.exit(uid == 0 or uid != pwd.getpwnam(sys.argv[1]).pw_uid)',
                     user]}, 'changed_when': False},
    ]


def recover_only(args, repo):
    # Re-resolve the tuple from the selected inventory, rather than accepting a
    # caller-supplied home/source or controller environment as authorization.
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]*', args.host):
        raise ValueError('Host must be a literal safe inventory host name')
    if args.host == 'poco-x3-pro':
        raise ValueError('Recovery does not support the isolated mobile host')
    def inventory_list(*options):
        output = subprocess.run(['ansible-inventory', '-i', args.inventory, '--list', *options],
                                capture_output=True, text=True, check=True)
        inventory = json.loads(output.stdout)
        if not isinstance(inventory, dict) or not isinstance(inventory.get('_meta'), dict):
            raise ValueError('Invalid inventory host listing')
        hostvars = inventory['_meta'].get('hostvars')
        if not isinstance(hostvars, dict):
            raise ValueError('Invalid inventory host listing')
        hosts = set(hostvars)
        groups = set()
        for name, group in inventory.items():
            if name == '_meta':
                continue
            if (not isinstance(group, dict) or not isinstance(group.get('hosts', []), list)
                    or not isinstance(group.get('children', []), list)):
                raise ValueError('Invalid inventory group listing')
            groups.add(name)
            for child in group.get('children', []):
                if not isinstance(child, str):
                    raise ValueError('Invalid inventory group listing')
                groups.add(child)
            for host in group.get('hosts', []):
                if not isinstance(host, str):
                    raise ValueError('Invalid inventory host listing')
                hosts.add(host)
        return hosts, groups

    hosts, groups = inventory_list()
    if args.host not in hosts or args.host in groups:
        raise ValueError('Recovery requires an exact inventory host that is not also a group')
    limited, _ = inventory_list('--limit', args.host)
    if limited != {args.host}:
        raise ValueError('Recovery inventory limit must select exactly the requested host')
    inventory = subprocess.run(['ansible-inventory', '-i', args.inventory, '--host', args.host],
                               capture_output=True, text=True, check=True)
    data = json.loads(inventory.stdout)
    result = subprocess.run([sys.executable, str(repo / 'scripts/lib/target-tuple.py'), 'resolve', args.user],
                            env={**os.environ, 'INVENTORY_JSON': inventory.stdout},
                            capture_output=True, text=True, check=True)
    if result.stdout.rstrip('\n').split('\t') != ['remote-host', 'ssh', args.user, args.home, args.source]:
        raise ValueError('Recovery target does not match the remote inventory tuple')
    stack = data.get('host_desktop_stack') if isinstance(data, dict) else None
    if stack not in ('none', 'hyprland'):
        raise ValueError('host_desktop_stack must be an explicit inventory value: none or hyprland')

    with tempfile.TemporaryDirectory(prefix='dotfiles-recovery-') as temporary:
        root = Path(temporary)
        bundle = root / 'repo'
        for relative in ('infra/chezmoi/bin/chezmoi-sync', 'infra/chezmoi/lib/sync_engine.py',
                         'infra/chezmoi/lib/sync_manifest.py', 'infra/chezmoi/lib/host_selection.py',
                         'scripts/lib/target-tuple.py'):
            source = repo / relative
            if source.is_symlink() or not source.is_file() or any(p.is_symlink() for p in source.parents if p != repo and repo in p.parents):
                raise ValueError(f'Recovery component missing or unsafe: {relative}')
            target = bundle / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        (bundle / SNAPSHOT).write_text(json.dumps({
            'inventory_hostname': args.host, 'host_desktop_stack': stack}) + '\n')
        archive = root / 'recovery.tar'
        create_archive(bundle, archive)
        remote = '{{ dotfiles_remote_stage.path }}'
        play = [{'hosts': args.host, 'gather_facts': False, 'become': True,
                 'become_user': args.user, 'environment': {'HOME': args.home},
                 'pre_tasks': selected_user_pre_tasks(args.host, args.user),
                 'tasks': [
                     {'name': 'Create isolated remote recovery directory', 'ansible.builtin.tempfile': {
                         'state': 'directory', 'prefix': 'dotfiles-chezmoi-recovery-'}, 'register': 'dotfiles_remote_stage'},
                     {'block': [
                         {'name': 'Extract recovery engine', 'ansible.builtin.unarchive': {
                             'src': str(archive), 'dest': remote + '/', 'remote_src': False,
                             'extra_opts': ['--same-permissions', '--no-same-owner']}},
                         {'name': 'Validate target filesystem before recovery', 'ansible.builtin.command': {'argv': [
                             'python3', remote + '/scripts/lib/target-tuple.py', 'check-paths', args.home, args.source]}, 'changed_when': False},
                         {'name': 'Recover authorized source transaction only', 'ansible.builtin.command': {'argv': [
                             'bash', remote + '/infra/chezmoi/bin/chezmoi-sync', '--recover-only',
                             '--host', args.host, '--source-dir', args.source]}},
                     ], 'always': [{'name': 'Remove isolated remote recovery directory', 'ansible.builtin.command': {
                         'argv': ['python3', '-c', CLEANUP_CODE, remote]}}]},
                 ]}]
        playbook = root / 'recover.json'
        playbook.write_text(json.dumps(play))
        return subprocess.run(['ansible-playbook', '-i', args.inventory, str(playbook),
                               '--limit', args.host, '--connection', 'ssh']).returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("inventory", "host", "user", "home", "source"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument('--recover-only', action='store_true')
    args = parser.parse_args()
    if not args.user or args.user == "root":
        parser.error("--user must select a non-root account")
    repo = Path(__file__).resolve().parents[2]
    if args.recover_only:
        raise SystemExit(recover_only(args, repo))
    with tempfile.TemporaryDirectory(prefix="dotfiles-remote-", dir="/tmp/opencode" if Path("/tmp/opencode").is_dir() else None) as temp:
        bundle = Path(temp) / "repo"
        build_bundle(repo, bundle, args.host, args.inventory)
        # Reject unsafe distributable content before any bytes leave the controller.
        # This isolated source is never the SSH target's filesystem path.
        sync = str(bundle / "infra/chezmoi/bin/chezmoi-sync")
        validation = subprocess.run([sync, "--host", args.host, "--source-dir", str(Path(temp) / "validation")])
        if validation.returncode:
            raise SystemExit(validation.returncode)
        archive = Path(temp) / "payload.tar"
        create_archive(bundle, archive)
        selection = json.loads((bundle / SNAPSHOT).read_text())
        remote = "{{ dotfiles_remote_stage.path }}"
        play = [{"hosts": args.host, "gather_facts": False, "become": True,
                 "become_user": args.user, "environment": {"HOME": args.home},
                 "pre_tasks": selected_user_pre_tasks(args.host, args.user),
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
                *([{"name": "Initialize only missing desktop MIME preferences", "ansible.builtin.command": {
                    "argv": [args.home + "/.local/libexec/dragon/mime-defaults"]},
                    "register": "dotfiles_mime_defaults",
                    "changed_when": "'mime-defaults: initialized' in dotfiles_mime_defaults.stdout",
                    "environment": {"XDG_CONFIG_HOME": args.home + "/.config",
                                    "XDG_DATA_HOME": args.home + "/.local/share"}},
                   {"name": "Refresh changed managed user icons", "ansible.builtin.command": {
                    "argv": [args.home + "/.local/libexec/dragon/user-icon-cache"]},
                    "register": "dotfiles_user_icon_cache",
                    "changed_when": "'user-icon-cache: refreshed' in dotfiles_user_icon_cache.stdout",
                    "environment": {"XDG_STATE_HOME": args.home + "/.local/state"}},
                   {"name": "Prepare required palettes before next managed login", "ansible.builtin.command": {
                    "argv": [args.home + "/.local/bin/theme-bootstrap"]},
                    "environment": {"XDG_CONFIG_HOME": args.home + "/.config"}}]
                  if selection['host_desktop_stack'] == 'hyprland' else []),
            ], "always": [{"name": "Remove isolated remote payload directory", "ansible.builtin.command": {
                "argv": ["python3", "-c", CLEANUP_CODE, remote]}}]},
        ]}]
        playbook = Path(temp) / "sync.json"
        playbook.write_text(json.dumps(play))
        raise SystemExit(subprocess.run(["ansible-playbook", "-i", args.inventory, str(playbook),
                                        "--limit", args.host, "--connection", "ssh"]).returncode)


if __name__ == "__main__":
    main()
