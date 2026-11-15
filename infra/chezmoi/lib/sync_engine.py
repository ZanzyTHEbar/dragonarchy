"""Transactional manifest sync with versioned source ownership evidence."""

import argparse
import errno
import fcntl
import hashlib
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import tempfile

from sync_manifest import destination, plan, relative, require, source_root
from host_selection import select_manifests, validate_manifests


def failpoint(name):
    require(os.environ.get('CHEZMOI_SYNC_FAILPOINT') != name,
            f'Injected chezmoi-sync failure: {name}')


def writable(path):
    path.chmod(stat.S_IMODE(path.stat().st_mode) | 0o700)


def reject_hardlinks(root):
    try:
        mode = root.lstat().st_mode
    except FileNotFoundError:
        return
    require(stat.S_ISDIR(mode), f'Invalid source directory: {root}')
    pending = [root]
    while pending:
        with os.scandir(pending.pop()) as entries:
            for entry in entries:
                info = entry.stat(follow_symlinks=False)
                require(not (stat.S_ISREG(info.st_mode) and info.st_nlink > 1),
                        f'Source contains a hardlinked file: {entry.path!r}. '
                        'Sync would break its links; preserve and review the file and its '
                        'other links before deciding how to proceed.')
                if stat.S_ISDIR(info.st_mode):
                    pending.append(entry.path)


def remove_tree(path):
    require(path.is_dir() and not path.is_symlink(), f'Invalid transaction cleanup path: {path}')
    writable(path)
    for child in path.iterdir():
        if child.is_dir() and not child.is_symlink():
            remove_tree(child)
        else:
            child.unlink()
    path.rmdir()


def evidence(path):
    info = path.lstat()
    mode = format(stat.S_IMODE(info.st_mode), 'o')
    if stat.S_ISDIR(info.st_mode):
        return ('d', mode, '-')
    require(stat.S_ISREG(info.st_mode), f'Unsupported owned source type: {path}')
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return ('f', mode, digest.hexdigest())


def desired_evidence(path, entry_kind):
    if entry_kind == 'symlink':
        return ('f', '644', hashlib.sha256(os.fsencode(os.readlink(path))).hexdigest())
    return evidence(path)


class Transaction:
    def __init__(self, root):
        self.root = root
        for name in ('state', 'stage', 'backup', 'lock'):
            setattr(self, name, Path(str(root) + '.chezmoi-sync-' + name))
        self.status, self.old = 'absent', []
        self.version, self.old_evidence = 'v1', {}

    def validate(self):
        for name in ('state', 'stage', 'backup', 'lock'):
            path = getattr(self, name)
            require(not path.is_symlink(), f'Transaction {name} path is a symlink: {path}')
            require(not path.exists() or (path.is_file() if name in ('state', 'lock') else path.is_dir()),
                    f'Invalid transaction {name} path: {path}')

    def read(self):
        if not self.state.exists():
            return
        fields = self.state.read_bytes().split(b'\0')
        require(len(fields) >= 3 and fields.pop() == b'' and
                fields[0] in (b'chezmoi-sync-state-v1', b'chezmoi-sync-state-v2'),
                f'Invalid transaction state file: {self.state}')
        status = os.fsdecode(fields[1])
        require(status in ('complete', 'finalizing', 'staging', 'staging-new', 'prepared', 'prepared-new'),
                'Invalid transaction state status')
        self.version = os.fsdecode(fields[0]).rsplit('-', 1)[-1]
        paths = [os.fsdecode(value) for value in fields[2:]]
        if self.version == 'v2':
            # NUL separates raw filesystem paths and fixed-width evidence
            # fields; an empty path separates old and proposed records.
            sections = [{}]
            index = 0
            while index < len(paths):
                if paths[index] == '':
                    require(status not in ('complete', 'finalizing') and len(sections) == 1,
                            'Invalid transaction state separator')
                    sections.append({})
                    index += 1
                    continue
                require(index + 4 <= len(paths), 'Incomplete transaction evidence')
                path, kind, mode, digest = paths[index:index + 4]
                relative(path, 'state')
                require(path not in sections[-1], 'Duplicate state path')
                require(kind in ('f', 'd') and re.fullmatch(r'(0|[1-7][0-7]{0,3})', mode) and
                        int(mode, 8) <= 0o7777 and
                        (re.fullmatch(r'[0-9a-f]{64}', digest) if kind == 'f' else digest == '-'),
                        'Invalid transaction evidence')
                sections[-1][path] = (kind, mode, digest)
                index += 4
            require(len(sections) == (1 if status in ('complete', 'finalizing') else 2),
                    'Invalid transaction state separator')
            require(status not in ('staging-new', 'prepared-new') or not sections[0],
                    'Invalid new transaction state')
            self.status, self.old_evidence = status, sections[0]
            self.old = list(self.old_evidence)
            return
        sections = [paths]
        if status not in ('complete', 'finalizing'):
            require(paths.count('') == 1, 'Invalid transaction state separator')
            split = paths.index('')
            sections = [paths[:split], paths[split + 1:]]
        for section in sections:
            require(len(set(section)) == len(section), 'Duplicate state path')
            for path in section:
                relative(path, 'state')
        require(status not in ('staging-new', 'prepared-new') or not sections[0],
                'Invalid new transaction state')
        self.status, self.old = status, sections[0]

    def write(self, status, old, new=()):
        if self.version == 'v2':
            def records(items):
                return [field for path, attributes in items.items() for field in (path, *attributes)]
            fields = ['chezmoi-sync-state-v2', status, *records(old)]
            if status not in ('complete', 'finalizing'):
                fields.extend(['', *records(new)])
        else:
            fields = ['chezmoi-sync-state-v1', status, *old]
            if status not in ('complete', 'finalizing'):
                fields.extend(['', *new])
        fd, name = tempfile.mkstemp(prefix=self.state.name + '.tmp.', dir=self.state.parent)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(b'\0'.join(os.fsencode(field) for field in fields) + b'\0')
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(name, self.state)
        finally:
            if os.path.exists(name):
                os.unlink(name)

    def recover(self):
        root, stage, backup = self.root.exists(), self.stage.exists(), self.backup.exists()
        # V1 records paths, not the contents of transaction trees. A stage,
        # backup or promoted root may have been edited since interruption.
        # Refuse before changing any of them, including the journal.
        ambiguous = (self.status in ('prepared', 'prepared-new') or
                     (self.status in ('staging', 'staging-new') and stage) or
                     (self.status == 'finalizing' and backup))
        require(not ambiguous,
                f'Interrupted {self.version} source transaction needs inspection; no recovery changes made. '
                f'Status: {self.status!r}; source: {str(self.root)!r}; '
                f'journal: {str(self.state)!r}; stage: {str(self.stage)!r}; '
                f'backup: {str(self.backup)!r}. Stop other writers, preserve copies of all '
                'existing paths, and compare the trees and journal before deciding how to '
                'recover. Do not remove transaction paths or retry with an older engine.')
        if self.status == 'absent':
            require(not stage and not backup, 'Untracked transaction lifecycle paths exist')
        elif self.status == 'complete':
            require(root and not stage and not backup, 'Unknown transaction recovery topology')
        elif self.status == 'finalizing':
            require(root and not stage, 'Unknown transaction recovery topology')
            self.write('complete', self.old_evidence if self.version == 'v2' else self.old)
            self.status = 'complete'
        elif self.status in ('staging', 'staging-new'):
            require(not backup and (self.status == 'staging-new' or root),
                    'Unknown transaction recovery topology')
            if self.status == 'staging-new':
                self.state.unlink()
                self.status, self.old = 'absent', []
            else:
                self.write('complete', self.old_evidence if self.version == 'v2' else self.old)
                self.status = 'complete'

    def parent(self, path):
        rel = str(path.relative_to(self.stage))
        destination(self.stage, rel)
        current = self.stage
        self.parent_modes.setdefault(current, stat.S_IMODE(current.stat().st_mode))
        writable(current)
        for part in path.relative_to(self.stage).parts[:-1]:
            current /= part
            if current.exists():
                self.parent_modes.setdefault(current, stat.S_IMODE(current.stat().st_mode))
            current.mkdir(exist_ok=True)
            writable(current)

    def remove(self, path, stale=False):
        destination(self.stage, str(path.relative_to(self.stage)))
        if not path.exists() and not path.is_symlink():
            return
        self.parent(path)
        if path.is_dir() and not path.is_symlink():
            try:
                path.rmdir()
            except OSError as error:
                if not stale or error.errno not in (errno.ENOTEMPTY, errno.EEXIST):
                    raise
        else:
            path.unlink()

    def sync(self, entries):
        self.parent_modes = {}
        owned = set(self.old)
        shared_dirs = set()
        legacy_dirs = set()
        # These two source directory names both denote ~/.config in chezmoi.
        # Do not adopt or move the existing alias; a general attribute decoder
        # would need to match chezmoi's complete, version-specific semantics.
        config_alias = self.root / 'private_dot_config'
        if any(rel == 'dot_config' or rel.startswith('dot_config/') for rel in entries):
            try:
                alias_mode = config_alias.lstat().st_mode
            except FileNotFoundError:
                pass
            else:
                require(not stat.S_ISDIR(alias_mode),
                        f'Source directory alias conflicts with managed dot_config: {config_alias}')
        # A manifest declares desired source entries, not ownership of an
        # existing user's source file. Refuse exact-path takeover before staging.
        for rel, (_, entry_kind) in entries.items():
            path = self.root / rel
            if rel not in owned and (path.exists() or path.is_symlink()):
                require(entry_kind == 'directory' and path.is_dir() and not path.is_symlink(),
                        f'Unowned source path conflicts with manifest: {path}')
                shared_dirs.add(rel)
        # copytree duplicates regular files and would break even unowned links.
        # Refuse before writing a staging journal or making the copy.
        reject_hardlinks(self.root)
        for rel in self.old:
            path = destination(self.root, rel)
            if self.version == 'v1':
                require(rel in entries,
                        f'Unverified v1 source path is stale: {path!r}; preserve and inspect it before reconciliation.')
            try:
                current = evidence(path)
            except FileNotFoundError:
                raise ValueError(f'Owned source path is missing: {path!r}; preserve and inspect the journal.') from None
            expected = (desired_evidence(*entries[rel]) if self.version == 'v1'
                        else self.old_evidence[rel])
            require(current == expected,
                    f'Owned source differs from {"desired content" if self.version == "v1" else "recorded evidence"}: '
                    f'{path!r}; preserve and inspect it before reconciliation.')
            require(not (current[0] == 'd' and rel in entries and entries[rel][1] != 'directory'),
                    f'Owned source directory cannot be replaced by a file: {path!r}; '
                    'preserve and inspect the directory and its contents before reconciliation.')
            if self.version == 'v1' and current[0] == 'd':
                legacy_dirs.add(rel)
        for rel in entries:
            if rel not in owned:
                require(not any(rel.startswith(parent + '/') for parent in legacy_dirs),
                        f'New source entry is inside an unverified v1 directory: {str(self.root / rel)!r}; '
                        'preserve and inspect it before reconciliation.')
        root_mode = stat.S_IMODE(self.root.stat().st_mode) if self.root.exists() else None
        if self.status == 'absent':
            self.version = 'v2'
        old = self.old_evidence if self.version == 'v2' else self.old
        # Record ownership before creating staging; an unrelated pre-existing
        # stage without this journal must never be removed during recovery.
        self.write('staging-new' if self.status == 'absent' else 'staging', old,
                   {} if self.version == 'v2' else entries)
        if self.root.exists():
            shutil.copytree(self.root, self.stage, symlinks=True)
        else:
            self.stage.mkdir()
        # Staging preserves unowned data, including symlinks; only journal-owned
        # stale entries are pruned. Exclusions stop new ownership; they never
        # authorize removing an unjournaled runtime/user file.
        modes = {}
        for index, (rel, (source, entry_kind)) in enumerate(entries.items()):
            path = self.stage / rel
            if self.version == 'v1' and rel in owned:
                continue  # Equal v1 entries remain unverified, not adopted or rewritten.
            self.parent(path)
            if entry_kind == 'directory':
                if path.is_symlink() or (path.exists() and not path.is_dir()):
                    self.remove(path)
                shared = rel in shared_dirs
                path.mkdir(exist_ok=True)
                if shared:
                    self.parent_modes.setdefault(path, stat.S_IMODE(path.stat().st_mode))
                writable(path)
                if not shared:
                    modes[path] = stat.S_IMODE(source.stat().st_mode)
            else:
                self.remove(path)
                if entry_kind == 'symlink':
                    path.write_bytes(os.fsencode(os.readlink(source)))
                    path.chmod(0o644)
                else:
                    shutil.copy2(source, path)
            if index == 0:
                failpoint('copy:1')
        stale = [rel for rel in self.old if rel not in entries]
        for index, rel in enumerate(sorted(stale, key=lambda p: p.count('/'), reverse=True)):
            self.remove(self.stage / rel, stale=True)
            if index == 0:
                failpoint('stale-cleanup:1')
        for path, mode in reversed(list(self.parent_modes.items())):
            if path.is_dir() and not path.is_symlink():
                path.chmod(mode)
        for path, mode in reversed(list(modes.items())):
            path.chmod(mode)
        if root_mode is not None:
            self.stage.chmod(root_mode)
        managed_entries = [rel for rel in entries if rel not in shared_dirs]
        new = ({rel: evidence(self.stage / rel) for rel in managed_entries}
               if self.version == 'v2' else managed_entries)
        self.write('prepared-new' if self.status == 'absent' else 'prepared', old, new)
        failpoint('promote:after-prepare')
        if self.root.exists():
            self.root.rename(self.backup)
            failpoint('promote:after-park')
        self.stage.rename(self.root)
        failpoint('promote:after-root')
        self.write('finalizing', new)
        failpoint('finalize:before-backup-delete')
        if self.backup.exists():
            remove_tree(self.backup)
        self.write('complete', new)


def main():
    parser = argparse.ArgumentParser(description='Sync manifest-declared dotfiles into chezmoi source.')
    parser.add_argument('--host', required=True)
    parser.add_argument('--profile')
    parser.add_argument('--source-dir')
    parser.add_argument('--recover-only', action='store_true')
    args = parser.parse_args()
    if not args.host:
        parser.error('--host is required')
    if args.recover_only and (args.profile is not None or args.source_dir is None):
        parser.error('--recover-only requires an explicit --source-dir and no profile')
    if args.recover_only and args.host == 'poco-x3-pro':
        parser.error('--recover-only does not support the isolated mobile host')
    if args.source_dir is None:
        args.source_dir = os.path.expanduser('~/.local/share/chezmoi')
    repo = Path(__file__).resolve().parents[3]
    manifests = repo / 'infra/chezmoi/manifests'
    if args.profile is not None:
        if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]*', args.profile):
            parser.error(f'Invalid profile name: {args.profile}')
        if args.profile != 'mobile' or args.host != 'poco-x3-pro':
            parser.error('Only --host poco-x3-pro --profile mobile is supported')
        if args.source_dir == os.path.expanduser('~/.local/share/chezmoi'):
            args.source_dir = os.path.expanduser('~/.local/share/dragonarchy/poco-x3-pro/omalauncher/chezmoi')
        manifests /= 'mobile'
        paths = [manifests / (name + '.manifest') for name in ('common', 'mobile')]
    else:
        paths, _ = select_manifests(repo, args.host, check_paths=False)
    require(paths, f'No manifests found in {manifests}')

    def check_manifests():
        if args.profile is not None:
            require(manifests.is_dir(), f'Mobile manifest directory not found: {manifests}')
            for path in paths:
                require(path.is_file(), f'Required mobile manifest missing: {path.stem}')
        else:
            validate_manifests(paths)

    root = source_root(args.source_dir)
    if args.recover_only and not root.parent.exists():
        print('==> No source transaction directory exists; nothing to recover.')
        return
    # No journal can exist without its parent. Keep invalid fresh plans from
    # creating directories, but recover an existing journal before planning.
    if not args.recover_only and not root.parent.exists():
        check_manifests()
        plan(repo, paths, args.host, root)
    root.parent.mkdir(parents=True, exist_ok=True)
    source_root(args.source_dir)
    transaction = Transaction(root)
    transaction.validate()
    if not args.recover_only and not transaction.lock.exists():
        # With no lock yet, avoid creating one for a source that is already
        # known to be uncopyable. Only inspect states whose recovery is a
        # non-mutating topology check; interrupted transactions recover first
        # under the lock below. Repeat the scan under the lock in sync().
        transaction.read()
        if transaction.status in ('absent', 'complete'):
            transaction.recover()
            reject_hardlinks(root)
        transaction = Transaction(root)
    fd = os.open(transaction.lock, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'r+b') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        transaction.validate()
        transaction.read()
        transaction.recover()
        if args.recover_only:
            print('==> Source transaction recovery complete; no desired state applied.')
            return
        # The desired payload may have become invalid while a prior source was
        # parked. Restore an authorized transaction before validating the plan.
        check_manifests()
        entries, _ = plan(repo, paths, args.host, root)
        print(f'==> chezmoi-sync: host={args.host} source={root}', flush=True)
        transaction.sync(entries)
    print("==> Sync complete. Run 'chezmoi apply' to update home directory.")


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
