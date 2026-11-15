#!/usr/bin/env python3
"""Remove only the identified private preview tree without following links."""

import os
from pathlib import Path
import stat
import sys


def remove_directory(parent, name, device, expected=None):
    path_fd = os.open(name, os.O_PATH | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
    try:
        info = os.fstat(path_fd)
        if info.st_dev != device or (expected is not None and (info.st_dev, info.st_ino) != expected):
            raise ValueError('preview directory identity or filesystem changed')
        if not os.path.samestat(info, os.stat(name, dir_fd=parent, follow_symlinks=False)):
            raise ValueError('preview directory changed')
        # O_PATH opens even a mode-000 directory. This proc fd refers to that
        # inode, not a symlink or a newly substituted name in the tree.
        os.chmod(f'/proc/self/fd/{path_fd}', stat.S_IMODE(info.st_mode) | 0o700)
        directory = os.open('.', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=path_fd)
        try:
            for entry in os.listdir(directory):
                entry_info = os.stat(entry, dir_fd=directory, follow_symlinks=False)
                if stat.S_ISDIR(entry_info.st_mode):
                    remove_directory(directory, entry, device, (entry_info.st_dev, entry_info.st_ino))
                else:
                    os.unlink(entry, dir_fd=directory)
            if not os.path.samestat(info, os.stat(name, dir_fd=parent, follow_symlinks=False)):
                raise ValueError('preview directory changed during cleanup')
            os.rmdir(name, dir_fd=parent)
        finally:
            os.close(directory)
    finally:
        os.close(path_fd)


def cleanup(root, identity):
    path = Path(root)
    if not path.is_absolute() or not path.name.startswith('dotfiles-chezmoi-dry-run.'):
        raise ValueError('invalid preview root')
    device, inode = (int(value) for value in identity.split(':'))
    parent = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        remove_directory(parent, path.name, device, (device, inode))
    finally:
        os.close(parent)


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3:
            raise ValueError('preview cleanup requires a root and its identity')
        cleanup(*sys.argv[1:])
    except (ValueError, OSError) as error:
        print(f'Error: preview cleanup failed: {error}', file=sys.stderr)
        sys.exit(1)
