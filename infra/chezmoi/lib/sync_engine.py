"""Transactional manifest sync; sidecar format and flock remain Bash-compatible."""

import argparse
import errno
import fcntl
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile

from sync_manifest import destination, plan, relative, require, source_root


def failpoint(name):
    require(os.environ.get('CHEZMOI_SYNC_FAILPOINT') != name,
            f'Injected chezmoi-sync failure: {name}')


def writable(path):
    path.chmod(stat.S_IMODE(path.stat().st_mode) | 0o700)


def remove_tree(path):
    require(path.is_dir() and not path.is_symlink(), f'Invalid transaction cleanup path: {path}')
    writable(path)
    for child in path.iterdir():
        if child.is_dir() and not child.is_symlink():
            remove_tree(child)
        else:
            child.unlink()
    path.rmdir()


class Transaction:
    def __init__(self, root):
        self.root = root
        for name in ('state', 'stage', 'backup', 'lock'):
            setattr(self, name, Path(str(root) + '.chezmoi-sync-' + name))
        self.status, self.old = 'absent', []

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
        require(len(fields) >= 3 and fields.pop() == b'' and fields[0] == b'chezmoi-sync-state-v1',
                f'Invalid transaction state file: {self.state}')
        status = os.fsdecode(fields[1])
        require(status in ('complete', 'prepared', 'prepared-new'), 'Invalid transaction state status')
        paths = [os.fsdecode(value) for value in fields[2:]]
        sections = [paths]
        if status != 'complete':
            require(paths.count('') == 1, 'Invalid transaction state separator')
            split = paths.index('')
            sections = [paths[:split], paths[split + 1:]]
        for section in sections:
            require(len(set(section)) == len(section), 'Duplicate state path')
            for path in section:
                relative(path, 'state')
        require(status != 'prepared-new' or not sections[0], 'Invalid prepared-new transaction state')
        self.status, self.old = status, sections[0]

    def write(self, status, old, new=()):
        fields = ['chezmoi-sync-state-v1', status, *old]
        if status != 'complete':
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
        if self.status == 'absent':
            require(not backup, 'Untracked transaction lifecycle paths exist')
            if stage:
                remove_tree(self.stage)
        elif self.status == 'complete':
            require(root and not (stage and backup), 'Unknown transaction recovery topology')
            if stage:
                remove_tree(self.stage)
            if backup:
                remove_tree(self.backup)
        else:
            if backup and not root and stage:
                self.backup.rename(self.root)
            elif backup and root and not stage:
                self.root.rename(self.stage)
                self.backup.rename(self.root)
            elif root and stage and not backup:
                pass  # Keep staging until the rollback journal update is durable.
            elif self.status == 'prepared-new' and not backup and stage and not root:
                pass
            elif self.status == 'prepared-new' and not backup and root and not stage:
                self.root.rename(self.stage)
            else:
                raise ValueError('Unknown transaction recovery topology')
            if self.status == 'prepared-new':
                self.state.unlink()
                self.status, self.old = 'absent', []
            else:
                self.write('complete', self.old)
                self.status = 'complete'
            remove_tree(self.stage)

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
        root_mode = stat.S_IMODE(self.root.stat().st_mode) if self.root.exists() else None
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
            self.parent(path)
            if entry_kind == 'directory':
                if path.is_symlink() or (path.exists() and not path.is_dir()):
                    self.remove(path)
                path.mkdir(exist_ok=True)
                writable(path)
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
        self.write('prepared-new' if self.status == 'absent' else 'prepared', self.old, entries)
        failpoint('promote:after-prepare')
        if self.root.exists():
            self.root.rename(self.backup)
            failpoint('promote:after-park')
        self.stage.rename(self.root)
        failpoint('promote:after-root')
        self.write('complete', entries)
        failpoint('finalize:before-backup-delete')
        if self.backup.exists():
            remove_tree(self.backup)


def main():
    parser = argparse.ArgumentParser(description='Sync manifest-declared dotfiles into chezmoi source.')
    parser.add_argument('--host', required=True)
    parser.add_argument('--source-dir', default=os.path.expanduser('~/.local/share/chezmoi'))
    args = parser.parse_args()
    if not args.host:
        parser.error('--host is required')
    repo = Path(__file__).resolve().parents[3]
    manifests = repo / 'infra/chezmoi/manifests'
    paths = sorted(manifests.glob('*.manifest'))
    require(paths, f'No manifests found in {manifests}')
    root = source_root(args.source_dir)
    entries, excludes = plan(repo, paths, args.host, root)
    root.parent.mkdir(parents=True, exist_ok=True)
    source_root(args.source_dir)
    transaction = Transaction(root)
    transaction.validate()
    fd = os.open(transaction.lock, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'r+b') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        transaction.validate()
        transaction.read()
        transaction.recover()
        # Recheck under the shared lock: another sync may have promoted a tree
        # while this invocation was waiting for its preflight to finish.
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
