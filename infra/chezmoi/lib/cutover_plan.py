"""Read-only existing-home inventory; no adoption, recovery or apply authority."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import stat
import subprocess
import sys

from host_selection import select_manifests
from sync_engine import Transaction
from sync_manifest import plan, require, source_root


SEMANTICS = 'chezmoi-2.72.2-static-subset'
# Go unicode.IsSpace / bytes.TrimSpace, not Python's broader str.isspace.
GO_SPACE = '\t\n\v\f\r \u0085\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000'
# Exact ordered grammar from v2.72.2 internal/chezmoi/{attr,chezmoi}.go.
# Unsupported operations/templates are blockers, never guessed target ownership.
UNSUPPORTED = ('create_', 'remove_', 'run_', 'modify_', 'encrypted_',
               'external_', 'exact_', 'once_', 'onchange_', 'before_', 'after_')


def path_data(value):
    """JSON text is display-only; base64 is the authoritative POSIX byte path."""
    raw = os.fsencode(value)
    return {'text': os.fsdecode(raw), 'bytes_base64': base64.b64encode(raw).decode('ascii')}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(info):
    return {name: getattr(info, 'st_' + name) for name in
            ('dev', 'ino', 'uid', 'gid', 'nlink', 'size', 'mtime_ns', 'ctime_ns')} | {
                'mode': format(stat.S_IMODE(info.st_mode), '04o')}


def read_regular(path, hash_only=False):
    # O_NOATIME is deliberate: regular-file inspection must not update atimes.
    # Do not silently fall back when ownership/filesystem permissions forbid it.
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_NOATIME)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode), f'Not a regular file: {path!r}')
        chunks = []
        checksum = hashlib.sha256()
        while block := os.read(fd, 1024 * 1024):
            if hash_only:
                checksum.update(block)
            else:
                chunks.append(block)
        require(identity(before) == identity(os.fstat(fd)) == identity(path.lstat()),
                f'File changed during inspection: {path!r}')
        return checksum.hexdigest() if hash_only else b''.join(chunks)
    finally:
        os.close(fd)


def observe(path):
    """Never intentionally traverse a redirected ancestor or open special files."""
    for parent in reversed(path.parents):
        try:
            info = parent.lstat()
        except FileNotFoundError:
            return {'kind': 'absent', 'missing_ancestor': path_data(parent)}
        if not stat.S_ISDIR(info.st_mode):
            return {'kind': 'blocked-ancestor', 'ancestor': path_data(parent),
                    'identity': identity(info),
                    'link_target': path_data(os.readlink(parent)) if stat.S_ISLNK(info.st_mode) else None}
    try:
        info = path.lstat()
    except FileNotFoundError:
        return {'kind': 'absent'}
    result = {'identity': identity(info)}
    if stat.S_ISLNK(info.st_mode):
        result.update(kind='symlink', link_target=path_data(os.readlink(path)))
    elif stat.S_ISREG(info.st_mode):
        result.update(kind='regular', sha256=read_regular(path, hash_only=True))
    elif stat.S_ISDIR(info.st_mode):
        result['kind'] = 'directory'
    else:
        result['kind'] = 'special'
    require(identity(info) == identity(path.lstat()), f'Path changed during inspection: {path!r}')
    return result


def tree(root):
    """No-follow, no-atime enumeration; includes unowned source/transaction data."""
    result = []

    def walk(path):
        item = observe(path)
        result.append({'path': path_data(path), 'relative': path_data(path.relative_to(root)), **item})
        if item['kind'] != 'directory':
            return
        fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_NOATIME)
        try:
            require(identity(os.fstat(fd)) == item['identity'], f'Directory changed: {path!r}')
            with os.scandir(fd) as children:
                names = sorted((child.name for child in children), key=os.fsencode)
            for name in names:
                walk(path / name)
            require(identity(os.fstat(fd)) == identity(path.lstat()) == item['identity'],
                    f'Directory changed during inspection: {path!r}')
        finally:
            os.close(fd)

    walk(root)
    return result


def decode_component(name, directory):
    require(name and not name.startswith('.'), f'Ignored/control source name: {name!r}')
    require(not name.startswith(UNSUPPORTED), f'Unsupported source attributes: {name!r}')
    flags = set()
    order = ('private', 'readonly') if directory else ('symlink', 'private', 'readonly', 'empty', 'executable')
    for attr in order:
        if name.startswith(attr + '_'):
            flags.add(attr)
            name = name[len(attr) + 1:]
            if attr == 'symlink':
                break  # chezmoi does NOT parse regular attributes after symlink_.
    require(not name.startswith(UNSUPPORTED), f'Unsupported source attributes: {name!r}')
    if name.startswith('dot_'):
        name = '.' + name[4:]
    elif name.startswith('literal_'):
        name = name[8:]
    elif name.startswith(('private_', 'readonly_', 'empty_', 'executable_', 'symlink_')):
        raise ValueError(f'Noncanonical source attributes: {name!r}')
    if not directory:
        if name.endswith('.literal'):
            name = name[:-8]
        elif name.endswith('.tmpl'):
            raise ValueError(f'Template requires reviewed rendering; no target claim: {name!r}')
    require(name not in ('', '.', '..') and '/' not in name and '\0' not in name,
            f'Invalid decoded source name: {name!r}')
    return name, flags


def decoded_path(encoded, directory, directory_names):
    parts = encoded.split('/')
    names = []
    flags = set()
    for index, part in enumerate(parts):
        is_dir = index < len(parts) - 1 or directory
        prefix = '/'.join(parts[:index + 1])
        require(not is_dir or directory_names.get(prefix, True),
                f'Non-directory source parent: {encoded!r}')
        name, flags = decode_component(part, is_dir)
        names.append(name)
    return '/'.join(names), flags


def inventory_tuple(args, repo):
    require(re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]*', args.host or ''),
            'An exact literal inventory --host is required')
    require(args.user and args.user != 'root', 'An explicit non-root managed --user is required')
    # ansible-inventory itself creates controller temporary directories. Require
    # an explicit caller-supplied offline artifact instead of secretly launching
    # it (or SSH), creating scratch state, or consulting INVENTORY_JSON.
    inventory_path = Path(os.path.abspath(args.inventory_json))
    require(observe(inventory_path)['kind'] == 'regular', 'Offline inventory must be a regular file')
    inventory_bytes = read_regular(inventory_path)
    inventory = json.loads(inventory_bytes)
    require(isinstance(inventory, dict) and isinstance(inventory.get('_meta'), dict)
            and isinstance(inventory['_meta'].get('hostvars'), dict),
            'Offline artifact must be complete ansible-inventory --list JSON')
    def members(data):
        hosts = set(data.get('_meta', {}).get('hostvars', {}))
        groups = set(data) - {'_meta'}
        for name in groups.copy():
            group = data[name]
            require(isinstance(group, dict), 'Invalid offline inventory group')
            for field in ('hosts', 'children'):
                require(isinstance(group.get(field, []), list) and
                        all(isinstance(value, str) for value in group.get(field, [])),
                        'Invalid offline inventory members')
            hosts.update(group.get('hosts', []))
            groups.update(group.get('children', []))
        return hosts, groups
    hosts, groups = members(inventory)
    require(args.host in hosts and args.host not in groups, 'Selection is not an exact inventory host')
    data = inventory['_meta']['hostvars'].get(args.host)
    require(isinstance(data, dict), 'Selected host has no offline hostvars')
    output = subprocess.run([sys.executable, '-B', str(repo / 'scripts/lib/target-tuple.py'),
                             'resolve', args.user], env={**os.environ, 'INVENTORY_JSON': json.dumps(data)},
                            capture_output=True, text=True, check=True)
    profile, connection, user, home, source = output.stdout.rstrip('\n').split('\t')
    require((args.host == 'opencode-runtime') == (profile == 'container'), 'Invalid container host identity')
    for requested, actual, label in ((args.target, profile, 'profile'),
                                      (args.connection, connection, 'connection'),
                                      (args.home, home, 'home'), (args.source_dir, source, 'source')):
        require(requested is None or requested == actual, f'Requested {label} differs from inventory')
    # No SSH status probes and no controller-home substitution. This explicit
    # assertion labels local bytes as belonging to the remote inventory tuple;
    # it does not change that tuple's connection policy or authorize normal apply.
    require(connection != 'ssh' or args.offline_local_inspection,
            'Remote inspection unsupported: run on the selected host with --offline-local-inspection; no SSH attempted')
    try:
        account = pwd.getpwnam(user)
    except KeyError as error:
        raise ValueError('Selected managed user is not a local account') from error
    require(os.geteuid() != 0 and os.geteuid() == account.pw_uid and account.pw_dir == home
            and os.environ.get('HOME') == home,
            'Local inspection requires the selected non-root account, passwd home and HOME')
    source_root(home)
    source_root(source)
    return data, {'host': args.host, 'user': user, 'uid': account.pw_uid,
                  'home': home, 'source': source, 'profile': profile, 'connection': connection,
                  'offline_local_inspection_asserted': args.offline_local_inspection,
                  'inventory_snapshot': {'path': path_data(inventory_path), 'sha256': digest(inventory_bytes),
                                         'provenance': 'caller-supplied-offline-declaration-not-authentication'},
                  'kernel_hostname': os.uname().nodename, 'hardware_identity_verified': False}


def source_journal(root, source_tree):
    tx = Transaction(root)
    paths = {name: getattr(tx, name) for name in ('state', 'lock', 'stage', 'backup')}
    records = {name: tree(path) if name in ('stage', 'backup') else
               [{'path': path_data(path), **observe(path)}] for name, path in paths.items()}
    journal = {'paths': records, 'status': 'absent', 'version': None, 'entries': [], 'blockers': []}
    if records['state'][0]['kind'] == 'regular':
        state_bytes = read_regular(paths['state'])
        require(digest(state_bytes) == records['state'][0]['sha256'],
                'Journal changed during inspection')
        # Use the engine's exact v1/v2 parser on bytes already read without atime.
        # Transaction.read only needs exists/read_bytes; no validate/recover/write.
        class StateBytes:
            def exists(self):
                return True

            def read_bytes(self):
                return state_bytes
        tx.state = StateBytes()
        try:
            tx.read()
        except ValueError as error:
            journal['blockers'].append('invalid-source-journal')
            journal['parser_error'] = str(error)
            return journal
        journal.update(status=tx.status, version=tx.version)
        fields = state_bytes.split(b'\0')[2:-1]
        # Preserve proposed transaction records too; the engine validates both
        # sections but deliberately exposes only old ownership to callers.
        if tx.status not in ('complete', 'finalizing'):
            separator = fields.index(b'') if tx.version == 'v1' else next(
                index for index in range(0, len(fields), 4) if fields[index] == b'')
            proposed = fields[separator + 1:]
            width = 1 if tx.version == 'v1' else 4
            journal['proposed_entries'] = [
                {'source_path': path_data(proposed[index]),
                 'evidence': [os.fsdecode(value) for value in proposed[index + 1:index + width]]}
                for index in range(0, len(proposed), width)]
        actual = {os.fsdecode(base64.b64decode(item['relative']['bytes_base64'])): item
                  for item in source_tree}
        for rel in tx.old:
            item = actual.get(rel, {'kind': 'absent'})
            observed = ('d' if item['kind'] == 'directory' else 'f' if item['kind'] == 'regular' else '?',
                        format(int(item.get('identity', {}).get('mode', '0'), 8), 'o'),
                        item.get('sha256', '-'))
            status = 'v1-unverified' if tx.version == 'v1' else (
                'matches-source-evidence' if observed == tx.old_evidence[rel] else 'source-drift')
            journal['entries'].append({'source_path': path_data(rel), 'assessment': status,
                                       'recorded_evidence': tx.old_evidence.get(rel)})
            if status != 'matches-source-evidence':
                journal['blockers'].append(status)
    elif records['state'][0]['kind'] != 'absent':
        journal['blockers'].append('invalid-journal-path')
    if journal['status'] not in ('absent', 'complete'):
        journal['blockers'].append('interrupted-source-transaction-review-required')
    if any(records[name][0]['kind'] != 'absent' for name in ('stage', 'backup')):
        journal['blockers'].append('transaction-tree-preservation-required')
    if records['lock'][0]['kind'] not in ('absent', 'regular'):
        journal['blockers'].append('invalid-lock-path')
    if journal['status'] == 'complete' and records['lock'][0]['kind'] == 'absent':
        journal['blockers'].append('completed-journal-without-lock')
    if journal['status'] == 'complete' and source_tree[0]['kind'] != 'directory':
        journal['blockers'].append('completed-source-missing')
    return journal


def make_plan(args, repo):
    data, target = inventory_tuple(args, repo)  # Before any home enumeration.
    root, home = Path(target['source']), Path(target['home'])
    # Resolve from the explicit full offline inventory, never a transported
    # source-only host-selection snapshot or ambient INVENTORY_JSON override.
    require(not (repo / 'infra/chezmoi/host-selection.json').exists()
            and not (repo / 'infra/chezmoi/host-selection.json').is_symlink(),
            'Cutover planning requires canonical inventory, not a transported source snapshot')
    old_inventory = os.environ.get('INVENTORY_JSON')
    os.environ['INVENTORY_JSON'] = json.dumps(data)
    try:
        manifests, selection = select_manifests(repo, args.host)
    finally:
        if old_inventory is None:
            os.environ.pop('INVENTORY_JSON', None)
        else:
            os.environ['INVENTORY_JSON'] = old_inventory
    entries, excludes = plan(repo, manifests, args.host, root)
    # Sync materializes these parents in its source tree. Chezmoi parses them
    # as directory entries too, so omitting them would hide target chmod/mkdir
    # proposals for shared .config/.local parents from an existing-home review.
    explicit = set(entries)
    for rel in list(entries):
        parts = rel.split('/')
        for index in range(1, len(parts)):
            entries.setdefault('/'.join(parts[:index]), (None, 'directory'))
    source = tree(root)
    journal = source_journal(root, source)
    blockers = list(journal['blockers'])
    # Never load user configuration/templates or initialize chezmoi state. A
    # personal config could change mode, umask, filters or destination semantics.
    configs = [{'path': path_data(home / '.config/chezmoi' / ('chezmoi.' + suffix)),
                **observe(home / '.config/chezmoi' / ('chezmoi.' + suffix))}
               for suffix in ('toml', 'yaml', 'yml', 'json', 'jsonc')]
    if any(item['kind'] != 'absent' for item in configs) or any(
            key.startswith('CHEZMOI_') for key in os.environ) or (
                os.environ.get('XDG_CONFIG_HOME', str(home / '.config')) != str(home / '.config')):
        blockers.append('personal-chezmoi-configuration-requires-reviewed-rendering')
    # Linux exposes the inherited process umask without changing it even briefly.
    masks = [int(line.split()[1], 8) for line in Path('/proc/self/status').read_text().splitlines()
             if line.startswith('Umask:')]
    require(len(masks) == 1, 'Linux inherited process umask is unavailable')
    mask = masks[0]
    directories = {rel: kind == 'directory' for rel, (_, kind) in entries.items()}
    desired, aliases, unresolved = [], {}, []
    for rel, (payload, kind) in entries.items():
        try:
            dest, flags = decoded_path(rel, kind == 'directory', directories)
            require(kind != 'symlink' or 'symlink' in flags, 'Invalid encoded symlink')
            expected_kind = 'directory' if kind == 'directory' else 'symlink' if 'symlink' in flags else 'regular'
            content = os.fsencode(os.readlink(payload)) if kind == 'symlink' else (
                read_regular(payload) if kind == 'regular' else None)
            # Real symlink rendering trims Go Unicode whitespace; on Unix
            # normalizeLinkname is the identity function (path_unix.go).
            if expected_kind == 'symlink':
                content = os.fsencode(os.fsdecode(content).strip(GO_SPACE))
                require(content and b'\0' not in content, 'Invalid rendered symlink target')
            # Empty/whitespace-only regular contents can mean removal, not an
            # empty managed file. Refuse that operation rather than guessing.
            require(expected_kind != 'regular' or os.fsdecode(content).strip(GO_SPACE) or 'empty' in flags,
                    'Whitespace-only contents without empty_: removal requires review')
            mode = (0o777 if expected_kind == 'directory' or 'executable' in flags else 0o666)
            if 'private' in flags:
                mode &= ~0o077
            if 'readonly' in flags:
                mode &= ~0o222
            desired.append({'source_path': path_data(rel),
                            'origin': 'manifest' if rel in explicit else 'implicit-source-parent',
                            'payload': path_data(payload) if payload is not None else None,
                            'payload_identity': identity(payload.lstat()) if payload is not None else None,
                            'target_path': path_data(home / dest), 'target_relative': path_data(dest),
                            'kind': expected_kind,
                            'executable': 'executable' in flags if expected_kind == 'regular' else None,
                            'mode_before_umask': format(mode, '04o') if expected_kind != 'symlink' else None,
                            'mode': format(mode & ~mask, '04o') if expected_kind != 'symlink' else None,
                            'sha256': digest(content) if content is not None else None,
                            'link_target': path_data(content) if expected_kind == 'symlink' else None})
            aliases.setdefault(dest, set()).add(rel)
            # Implicit parents count too: private_dot_config aliases dot_config
            # even when the manifests map only dot_config/nvim and its peers.
            components = rel.split('/')
            for index in range(1, len(components)):
                parent = '/'.join(components[:index])
                parent_dest, _ = decoded_path(parent, True, directories)
                aliases.setdefault(parent_dest, set()).add(parent)
        except ValueError as error:
            unresolved.append({'source_path': path_data(rel), 'reason': str(error)})
    if unresolved:
        blockers.append('unsupported-desired-semantics')
    source_aliases, unselected = [], []
    source_dirs = {os.fsdecode(base64.b64decode(item['relative']['bytes_base64'])):
                   item['kind'] == 'directory' for item in source}
    for item in source[1:]:
        rel = os.fsdecode(base64.b64decode(item['relative']['bytes_base64']))
        if any(part.startswith('.') for part in rel.split('/')):
            if any(part.startswith('.chezmoi') for part in rel.split('/')):
                blockers.append('source-control-semantics-require-review')
            continue  # Ordinary dot-prefixed source entries are ignored by chezmoi.
        try:
            require(item['kind'] in ('regular', 'directory'), 'Source symlink/special requires review')
            dest, _ = decoded_path(rel, item['kind'] == 'directory', source_dirs)
            if dest in aliases and rel not in aliases[dest]:
                source_aliases.append({'source_path': path_data(rel), 'target_path': path_data(home / dest)})
            elif rel not in entries:
                unselected.append({'source_path': path_data(rel), 'target_path': path_data(home / dest),
                                   'policy': 'unselected-source-preserve-no-target-authority'})
        except ValueError as error:
            blockers.append('unresolved-existing-source-semantics')
            unresolved.append({'existing_source_path': path_data(rel), 'reason': str(error)})
    if source_aliases or any(len(paths) > 1 for paths in aliases.values()):
        blockers.append('source-alias-conflict')
    source_by_path = {os.fsdecode(base64.b64decode(item['relative']['bytes_base64'])): item
                      for item in source}
    journal_by_path = {os.fsdecode(base64.b64decode(item['source_path']['bytes_base64'])): item
                       for item in journal['entries']}
    for item in desired:
        rel = os.fsdecode(base64.b64decode(item['source_path']['bytes_base64']))
        current = source_by_path.get(rel, {'kind': 'absent'})
        item['current_source'] = current
        item['source_evidence'] = journal_by_path.get(rel, {'assessment': 'unjournaled'})
        if rel not in journal_by_path and current['kind'] not in ('absent', 'directory'):
            blockers.append('unowned-exact-source-conflict')
        if current['kind'] == 'directory' and item['kind'] != 'directory':
            blockers.append('source-type-transition-review-required')
        path = Path(os.fsdecode(base64.b64decode(item['target_path']['bytes_base64'])))
        existing = observe(path)
        item['existing'] = existing
        category = {'absent': 'create-requires-authority', 'regular': 'personal-or-unknown-regular',
                    'directory': 'shared-directory-review', 'symlink': 'unknown-symlink-review',
                    'special': 'special-file-conflict', 'blocked-ancestor': 'redirected-or-nondirectory-parent'}[existing['kind']]
        if existing['kind'] in ('regular', 'directory') and existing['kind'] != item['kind']:
            category = 'target-type-conflict'
        if item['kind'] == existing['kind'] == 'regular' and existing.get('sha256') == item['sha256']:
            category = 'matching-bytes-ownership-unverified'
        if existing['kind'] == 'symlink':
            link = os.fsdecode(base64.b64decode(existing['link_target']['bytes_base64']))
            lexical = Path(os.path.normpath(os.path.join(path.parent, link)))
            if repo / 'packages' in lexical.parents:
                category = 'checkout-stow-candidate-not-ownership'
        item['category'] = category
        item['historical_target_ownership'] = 'unverified'
    if any(item['existing']['kind'] != 'absent' for item in desired):
        blockers.append('existing-home-target-review-required')
    excluded = []
    for rel in sorted(excludes, key=os.fsencode):
        # SourceState.Read skips ordinary dot-prefixed source files/subtrees
        # before parsing attributes. Such a spelling has NO managed target;
        # decoding it as a literal home path would fabricate ownership. The
        # first hidden component matters: controls below an ignored directory
        # are not visited, but .chezmoi* controls themselves need review.
        hidden = next((part for part in rel.split('/') if part.startswith('.')), None)
        if hidden is not None and not hidden.startswith('.chezmoi'):
            excluded.append({'source_path': path_data(rel),
                             'source_semantics': 'ordinary-dot-source-ignored-by-chezmoi',
                             'target_semantics': 'no-managed-target',
                             'policy': 'source-excluded-ignored-preserve-only-not-inspected'})
            continue
        try:
            dest, _ = decoded_path(rel, True, {})
            excluded.append({'source_path': path_data(rel), 'target_path': path_data(home / dest),
                             'policy': 'runtime-or-personal-preserve-not-inspected'})
        except ValueError as error:
            excluded.append({'source_path': path_data(rel), 'reason': str(error), 'policy': 'preserve'})
            blockers.append('unresolved-exclusion-semantics')
    units = sorted({Path(os.fsdecode(base64.b64decode(item['target_relative']['bytes_base64']))).name
                    for item in desired if '/systemd/user/' in item['target_relative']['text']
                    and item['target_relative']['text'].endswith(('.service', '.timer', '.socket', '.path'))})
    preserve = [{'path': item['target_path'], 'role': 'existing-target',
                 'recursive': item['existing']['kind'] == 'directory',
                 'observation': item['existing']} for item in desired if item['existing']['kind'] != 'absent']
    preserve.extend({'path': path_data(path), 'role': 'source-' + role, 'recursive': True}
                    for role, path in [('root', root), *[(name, getattr(Transaction(root), name))
                                                       for name in ('state', 'lock', 'stage', 'backup')]])
    preserve.extend({'path': item['target_path'], 'role': 'runtime-or-personal-exclusion',
                     'recursive': True, 'observation': 'not-inspected'}
                    for item in excluded if 'target_path' in item)
    preserve.extend({'path': item['existing']['ancestor'], 'role': 'redirected-ancestor',
                     'recursive': True, 'observation': item['existing']}
                    for item in desired if item['existing']['kind'] == 'blocked-ancestor')
    return {'schema': 'dragonarchy-cutover-plan-v1', 'authorization': False, 'apply_supported': False,
            'target': target, 'selection': selection, 'semantics': SEMANTICS,
            'manifest_inputs': [{'path': path_data(path), 'sha256': digest(read_regular(path)),
                                 'identity': identity(path.lstat())} for path in manifests],
            'umask': format(mask, '04o'), 'configuration': configs,
            'desired_semantics_resolved': not any(reason in blockers for reason in (
                'unsupported-desired-semantics', 'unresolved-existing-source-semantics',
                'unresolved-exclusion-semantics',
                'source-control-semantics-require-review', 'source-alias-conflict',
                'personal-chezmoi-configuration-requires-reviewed-rendering')),
            'snapshot_consistent': False, 'locks_acquired': False, 'inventory_freshness_verified': False,
            'limitations': ['uncoordinated point-in-time observations; rename/mount/writer races remain',
                            'kernel symlink read-access timestamps may advance',
                            'fingerprints do not authenticate ownership or preserve ACLs/xattrs',
                            'offline inventory and same-host assertion are not physical-host attestation'],
            'blockers': sorted(set(blockers)), 'desired': desired, 'unresolved': unresolved,
            'existing_source_aliases': source_aliases, 'excluded': excluded,
            'unselected_source_targets': unselected,
            'source_tree': source, 'source_journal': journal,
            'recovery_requirements': {
                'preserve_paths': preserve,
                'backup_before_any_mutation': ['every existing desired target and redirected ancestor; directory subtrees and unrelated children',
                                             'complete source, journal, lock, stage and backup at the recorded exact paths',
                                             'Stow link text AND separately resolved checkout payload/personal edits',
                                             'personal/runtime exclusions and active runtime generation/selection',
                                             'current service fragments/drop-ins, masks, enablement and active state'],
                'preserve_metadata': ['raw filename bytes', 'type', 'mode', 'uid/gid', 'symlink text',
                                      'hardlink relationships', 'ACLs', 'xattrs', 'timestamps'],
                'review_unit_references': units,
                'unit_reference_paths': [item['target_path'] for item in desired
                                         if item['target_relative']['text'].startswith('.config/systemd/user/')
                                         and item['target_relative']['text'].endswith(('.service', '.timer', '.socket', '.path'))],
                'session_writer_review_required': selection['host_desktop_stack'] == 'hyprland',
                'service_actions': 'Review selected units, vendor dependencies and actual session owners before scoped quiescence; do not stop these names blindly.',
                'restore': ['quiesce only approved exact writers/units and preserve intervening edits',
                            'restore saved target types, bytes, link text and metadata at exact paths; remove only newly created paths whose receipt proves identity',
                            'restore source/journal/stage/backup together to the reviewed topology; never run recovery to discard ambiguous trees',
                            'restore runtime selection/generation and unit fragments/drop-ins/masks/enablement; daemon-reload only after reviewed unit restoration',
                            'restart only previously active, approved exact services in dependency order; verify retained user outcomes'],
                'next_steps': ['review conflicts, aliases, personal merges and exact service/session writers with owner',
                               'obtain explicit real backup, inspection and cutover authority; verify independently restorable copies',
                               'design coordinated no-replace publication and identity-bound rollback; this planner supplies no executor',
                               'replan under approved writer quiescence immediately before any future approved mutation']}}


def main():
    repo = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory-json', required=True,
                        help='Explicit offline ansible-inventory --list JSON; planner launches no Ansible/SSH')
    parser.add_argument('--host', required=True)
    parser.add_argument('--user', required=True)
    parser.add_argument('--target')
    parser.add_argument('--connection', choices=('local', 'ssh'))
    parser.add_argument('--home')
    parser.add_argument('--source-dir')
    parser.add_argument('--offline-local-inspection', action='store_true')
    args = parser.parse_args()
    try:
        output = make_plan(args, repo)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({'schema': 'dragonarchy-cutover-plan-v1', 'authorization': False,
                          'apply_supported': False, 'error': str(error)}, ensure_ascii=True))
        return 2
    print(json.dumps(output, ensure_ascii=True, sort_keys=True))
    return 0


if __name__ == '__main__':
    sys.exit(main())
