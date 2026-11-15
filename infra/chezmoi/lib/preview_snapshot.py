#!/usr/bin/env python3
"""Copy a stable source and its ownership journal for a local preview."""

from contextlib import nullcontext
import fcntl
import os
from pathlib import Path
import shutil
import stat
import sys

from sync_engine import Transaction, reject_hardlinks
from sync_manifest import require, source_root


def snapshot(source, output):
    root = source_root(source)
    target = source_root(output)
    require(not target.exists(), f'Preview source already exists: {target}')
    require(not target.is_relative_to(root) and not root.is_relative_to(target),
            'Preview and original source paths must not overlap')
    transaction = Transaction(root)
    transaction.validate()

    # Never create a lock in the user's home just to preview. If one already
    # exists, coordinate the copy with the same lock as source reconciliation.
    if transaction.lock.exists():
        fd = os.open(transaction.lock, os.O_RDWR | os.O_NOFOLLOW)
        lock = os.fdopen(fd, 'r+b')
    else:
        lock = nullcontext()
    with lock as opened:
        if opened is not None:
            require(stat.S_ISREG(os.fstat(opened.fileno()).st_mode), 'Invalid source transaction lock')
            fcntl.flock(opened, fcntl.LOCK_EX)
            require(os.path.samestat(os.fstat(opened.fileno()), os.stat(transaction.lock, follow_symlinks=False)),
                    'Source transaction lock changed during preview')
        transaction.validate()
        transaction.read()
        require(transaction.status in ('absent', 'complete'),
                'Source transaction requires recovery before preview')
        require(not transaction.stage.exists() and not transaction.backup.exists(),
                'Source transaction has untracked lifecycle paths')
        require(transaction.status != 'complete' or (opened is not None and root.is_dir()),
                'Completed source transaction is missing its lock or source')
        reject_hardlinks(root)
        if root.exists():
            shutil.copytree(root, target, symlinks=True)
        else:
            target.mkdir()
        if transaction.status == 'complete':
            shutil.copyfile(transaction.state, Path(str(target) + '.chezmoi-sync-state'))
        if opened is None:
            transaction.validate()
            require(not transaction.lock.exists() and not transaction.state.exists()
                    and not transaction.stage.exists() and not transaction.backup.exists(),
                    'Source transaction changed during preview')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3:
            raise ValueError('Preview snapshot requires source and output paths')
        snapshot(*sys.argv[1:])
    except (ValueError, OSError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
