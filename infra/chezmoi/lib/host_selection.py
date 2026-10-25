"""Inventory-owned manifest selection, frozen into isolated remote bundles."""

import json
import os
import re
import subprocess


SNAPSHOT = 'infra/chezmoi/host-selection.json'


def select_manifests(repo, host, inventory=None):
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]*', host):
        raise ValueError('Host must be a literal safe inventory host name')
    snapshot = repo / SNAPSHOT
    if snapshot.is_symlink():
        raise ValueError('Host selection snapshot must not be a symlink')
    if snapshot.exists():
        data = json.loads(snapshot.read_text())
        if not isinstance(data, dict) or data.get('inventory_hostname') != host:
            raise ValueError('Host selection snapshot does not match selected host')
    elif 'INVENTORY_JSON' in os.environ:
        data = json.loads(os.environ['INVENTORY_JSON'])
    else:
        result = subprocess.run([
            'ansible-inventory', '-i', str(inventory or repo / 'infra/ansible/inventory/hosts.yml'),
            '--host', host], capture_output=True, text=True)
        if result.returncode:
            raise ValueError(f'Unable to resolve inventory host selection: {host}: {result.stderr.strip()}')
        data = json.loads(result.stdout)
    stack = data.get('host_desktop_stack') if isinstance(data, dict) else None
    if stack not in ('none', 'hyprland'):
        raise ValueError('host_desktop_stack must be an explicit inventory value: none or hyprland')
    names = ['devtools-core', 'git-ssh', 'session-zsh']
    if stack == 'hyprland':
        names.extend(['session-core', 'session-shell'])
    paths = [repo / 'infra/chezmoi/manifests' / (name + '.manifest') for name in sorted(names)]
    for path in paths:
        if path.is_symlink() or not path.is_file():
            raise ValueError(f'Required selected manifest missing or unsafe: {path}')
    return paths, {'inventory_hostname': host, 'host_desktop_stack': stack}
