"""Independent, deliberately bounded Linux source preservation, never adoption."""

import argparse
import base64
import fcntl
import hashlib
import json
import os
from pathlib import Path
import stat
import struct
import sys

from cutover_plan import inventory_tuple
from sync_engine import Transaction
from sync_manifest import require


SCHEMA = 'dragonarchy-source-snapshot-v1'
SLOTS = ('source', 'state', 'lock', 'stage', 'backup')
READ = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_NOATIME


def sha(data):
    return hashlib.sha256(data).hexdigest()


def packed(value):
    return base64.b64encode(os.fsencode(value)).decode('ascii')


def unpacked(value):
    raw = base64.b64decode(value, validate=True)
    require(b'\0' not in raw, 'NUL path')
    return os.fsdecode(raw)


def canonical(path):
    require(os.path.isabs(path) and str(Path(path)) == path
            and '..' not in Path(path).parts, 'Require normalized absolute paths')
    return Path(path)


def open_dir(path):
    """Pin every ancestor, refusing links; caller owns returned descriptor."""
    path = canonical(str(path))
    flags = os.O_PATH | os.O_NOFOLLOW | os.O_DIRECTORY
    fd = os.open('/', flags)
    try:
        for part in path.parts[1:]:
            child = os.open(part, flags, dir_fd=fd)
            os.close(fd)
            fd = child
        return os.open('.', READ | os.O_DIRECTORY, dir_fd=fd)
    finally:
        os.close(fd)


def proc(fd, name=None):
    return f'/proc/self/fd/{fd}' + (('/' + name) if name is not None else '')


def mount_id(fd):
    with open(f'/proc/self/fdinfo/{fd}', encoding='ascii') as stream:
        for line in stream:
            if line.startswith('mnt_id:'):
                return int(line.split()[1])
    raise ValueError('Linux mount identity unavailable')


def metadata(info):
    return {key: getattr(info, 'st_' + key) for key in
            ('mode', 'uid', 'gid', 'atime_ns', 'mtime_ns')}


def evidence(info):
    return {key: getattr(info, 'st_' + key) for key in
            ('dev', 'ino', 'mode', 'uid', 'gid', 'nlink', 'size', 'mtime_ns', 'ctime_ns')}


def supported(fd, link_path=None):
    # ACLs, capabilities, SELinux labels and arbitrary xattrs must not disappear.
    attrs = os.listxattr(link_path, follow_symlinks=False) if link_path else os.listxattr(fd)
    require(not attrs, 'Extended metadata/ACL unsupported; preserve externally')
    if fd is not None:
        # Linux FS_IOC_GETFLAGS. Extent layout alone is not restore metadata.
        flags = struct.unpack('I', fcntl.ioctl(fd, 0x80086601, bytes(4)))[0]
        require(flags & ~0x80000 == 0, 'Inode flags unsupported; preserve externally')


def regular(fd, output=None):
    checksum = hashlib.sha256()
    first = True
    while block := os.read(fd, 1024 * 1024):
        if first:
            require(not block.startswith(b'SQLite format 3\0'),
                    'SQLite database refused; use its online backup API separately')
            first = False
        checksum.update(block)
        if output is not None:
            output.write(block)
    return checksum.hexdigest()


def scan(parent, roots, objects=None):
    """Pinned no-follow enumeration; all unowned entries are included."""
    records = []
    boundary = mount_id(parent)

    def walk(pfd, name, slot, parts):
        try:
            before = os.stat(name, dir_fd=pfd, follow_symlinks=False)
        except FileNotFoundError:
            require(not parts, 'Entry disappeared')
            records.append({'slot': slot, 'parts': [], 'kind': 'absent'})
            return
        mode = before.st_mode
        kind = ('directory' if stat.S_ISDIR(mode) else 'regular' if stat.S_ISREG(mode)
                else 'symlink' if stat.S_ISLNK(mode) else 'unsupported')
        require(kind != 'unsupported', 'Special file refused')
        require(kind == 'directory' or before.st_nlink == 1, 'Hardlinked file/link refused')
        require(before.st_uid == os.geteuid(), 'Foreign-owned entry refused')
        require(not mode & (stat.S_ISUID | stat.S_ISGID | stat.S_ISVTX), 'Special mode bits refused')
        item = {'slot': slot, 'parts': [packed(p) for p in parts], 'kind': kind,
                'metadata': metadata(before), 'evidence': evidence(before)}
        number = len(records)
        records.append(item)
        if kind == 'symlink':
            linkfd = os.open(name, os.O_PATH | os.O_NOFOLLOW, dir_fd=pfd)
            try:
                require(mount_id(linkfd) == boundary, 'Symlink mount boundary refused')
            finally:
                os.close(linkfd)
            supported(None, proc(pfd, name))
            item['link'] = packed(os.readlink(name, dir_fd=pfd))
            if objects is not None:
                os.symlink(unpacked(item['link']), str(number), dir_fd=objects)
        else:
            require(mode & stat.S_IRUSR and (kind != 'directory' or mode & stat.S_IXUSR),
                    'Owner-unreadable/unsearchable entry refused')
            fd = os.open(name, READ | (os.O_DIRECTORY if kind == 'directory' else 0), dir_fd=pfd)
            try:
                require(evidence(os.fstat(fd)) == evidence(before), 'Entry changed before open')
                require(mount_id(fd) == boundary, 'Mount/bind-mount boundary refused')
                supported(fd)
                if kind == 'regular':
                    require(not name.endswith(('-wal', '-shm', '-journal')),
                            'Possible live database companion refused')
                    if objects is None:
                        item['sha256'] = regular(fd)
                    else:
                        out = os.open(str(number), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                      0o600, dir_fd=objects)
                        with os.fdopen(out, 'wb') as stream:
                            item['sha256'] = regular(fd, stream)
                            stream.flush()
                            os.fsync(stream.fileno())
                else:
                    with os.scandir(fd) as entries:
                        names = sorted((entry.name for entry in entries), key=os.fsencode)
                    for child in names:
                        walk(fd, child, slot, parts + [child])
                require(evidence(os.fstat(fd)) == evidence(before), 'Entry changed during read')
            finally:
                os.close(fd)
        require(evidence(os.stat(name, dir_fd=pfd, follow_symlinks=False)) == evidence(before),
                'Entry replaced during read')

    for slot in SLOTS:
        walk(parent, roots[slot], slot, [])
    return records


def stable(records):
    # readlink can advance symlink atime; it is not a writer-authentication signal.
    return [{**r, 'metadata': {k: v for k, v in r.get('metadata', {}).items()
                             if k != 'atime_ns'}} for r in records]


def read_file(parent, name):
    fd = os.open(name, READ, dir_fd=parent)
    try:
        before = os.fstat(fd)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1
                and before.st_uid == os.geteuid() and stat.S_IMODE(before.st_mode) == 0o600,
                'Control must be caller-owned single-link 0600 regular file')
        with os.fdopen(os.dup(fd), 'rb') as stream:
            data = stream.read()
        require(evidence(before) == evidence(os.fstat(fd)), 'Control file changed')
        return data
    finally:
        os.close(fd)


def write_file(parent, name, data):
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def fresh(path):
    path = canonical(path)
    parent = open_dir(path.parent)
    try:
        info = os.fstat(parent)
        require(info.st_uid == os.geteuid() and stat.S_IMODE(info.st_mode) == 0o700,
                'Destination parent must already be owned by caller with mode 0700')
        require(not os.listxattr(parent), 'Destination parent ACL/xattrs unsupported')
        os.mkdir(path.name, 0o700, dir_fd=parent)
        fd = os.open(path.name, READ | os.O_DIRECTORY, dir_fd=parent)
        os.fsync(parent)
        return fd
    finally:
        os.close(parent)


def bound(fd, path):
    current = open_dir(path)
    try:
        require(os.path.samestat(os.fstat(fd), os.fstat(current))
                and mount_id(fd) == mount_id(current), 'Directory path binding changed')
    finally:
        os.close(current)


def outside(path, identity):
    path = canonical(path)
    home = Path(identity['home'])
    source = Path(identity['source'])
    require(not path.is_relative_to(home) and not home.is_relative_to(path)
            and not path.is_relative_to(source) and not source.is_relative_to(path),
            'Destination must be outside and nonoverlapping with home/source')
    return path


def validate_manifest(data, identity):
    require(data['schema'] == SCHEMA and data['identity'] == identity,
            'Snapshot identity/inventory/path binding mismatch')
    records = data['records']
    tx = Transaction(Path(identity['source']))
    expected_roots = {'source': Path(identity['source']).name} | {
        slot: getattr(tx, slot).name for slot in SLOTS[1:]}
    require(data['roots'] == expected_roots, 'Transaction path binding mismatch')
    seen = set()
    for item in records:
        require(item['slot'] in SLOTS, 'Unknown snapshot slot')
        parts = tuple(unpacked(p) for p in item['parts'])
        require(all(p not in ('', '.', '..') and '/' not in p for p in parts), 'Unsafe snapshot path')
        key = (item['slot'], parts)
        require(key not in seen, 'Duplicate snapshot entry')
        if parts:
            require((item['slot'], parts[:-1]) in seen, 'Missing snapshot parent')
            parent = next(r for r in records if r['slot'] == item['slot']
                          and r['parts'] == item['parts'][:-1])
            require(parent['kind'] == 'directory', 'Non-directory snapshot parent')
        seen.add(key)
        require(item['kind'] in ('absent', 'directory', 'regular', 'symlink'), 'Invalid kind')
        require(item['kind'] != 'absent' or not parts, 'Invalid absent entry')
        if item['kind'] != 'absent':
            meta = item['metadata']
            require(meta['uid'] == identity['uid'] and meta['gid'] in os.getgroups() + [os.getegid()],
                    'Cannot preserve snapshot ownership')
            mode = meta['mode']
            expected = {'directory': stat.S_IFDIR, 'regular': stat.S_IFREG, 'symlink': stat.S_IFLNK}
            require(stat.S_IFMT(mode) == expected[item['kind']] and not mode & 0o7000, 'Invalid mode')
            require(item['kind'] == 'symlink' or (mode & stat.S_IRUSR
                    and (item['kind'] != 'directory' or mode & stat.S_IXUSR)),
                    'Unverifiable restored mode')
        if item['kind'] == 'symlink':
            require(unpacked(item['link']) != '', 'Empty symlink')
    require(all((slot, ()) in seen for slot in SLOTS), 'Missing snapshot roots')
    require(sha(json.dumps(records, sort_keys=True).encode()) == data['records_sha256'],
            'Snapshot record fingerprint mismatch')
    return records


def verify(fd, identity, complete=True):
    info = os.fstat(fd)
    require(info.st_uid == os.geteuid() and stat.S_IMODE(info.st_mode) == 0o700,
            'Snapshot root must be private and caller-owned')
    raw = read_file(fd, 'manifest.json')
    if complete:
        require(read_file(fd, 'COMPLETE') == (sha(raw) + '\n').encode(), 'Incomplete/changed snapshot')
    data = json.loads(raw)
    records = validate_manifest(data, identity)
    objects = os.open('objects', READ | os.O_DIRECTORY, dir_fd=fd)
    try:
        objinfo = os.fstat(objects)
        require(objinfo.st_uid == os.geteuid() and stat.S_IMODE(objinfo.st_mode) == 0o700
                and mount_id(objects) == mount_id(fd), 'Invalid object store')
        expected = set()
        for index, item in enumerate(records):
            if item['kind'] not in ('regular', 'symlink'):
                continue
            name = str(index)
            expected.add(name)
            info = os.stat(name, dir_fd=objects, follow_symlinks=False)
            require(info.st_nlink == 1 and info.st_uid == os.geteuid(), 'Invalid backup object identity')
            if item['kind'] == 'symlink':
                require(stat.S_ISLNK(info.st_mode) and packed(os.readlink(name, dir_fd=objects)) == item['link'],
                        'Changed symlink object')
            else:
                require(stat.S_ISREG(info.st_mode) and stat.S_IMODE(info.st_mode) == 0o600,
                        'Invalid byte-copy object')
                obj = os.open(name, READ, dir_fd=objects)
                try:
                    require(evidence(os.fstat(obj)) == evidence(info)
                            and mount_id(obj) == mount_id(objects), 'Changed/mounted object')
                    require(regular(obj) == item['sha256'], 'Changed snapshot bytes')
                    require(evidence(os.fstat(obj)) == evidence(info), 'Object changed during verify')
                finally:
                    os.close(obj)
        require(set(os.listdir(objects)) == expected, 'Unknown/missing snapshot objects')
    finally:
        os.close(objects)
    require(set(os.listdir(fd)) == ({'manifest.json', 'objects', 'COMPLETE'} if complete
                                    else {'manifest.json', 'objects'}), 'Unknown snapshot artifacts')
    return data


def snapshot(args, identity):
    require(args.writers_quiescent, 'Explicit --writers-quiescent assertion required')
    output = outside(args.destination, identity)
    root = Path(identity['source'])
    tx = Transaction(root)
    roots = {'source': root.name} | {slot: getattr(tx, slot).name for slot in SLOTS[1:]}
    parent = open_dir(root.parent)
    lock = None
    target = None
    try:
        # Never create or replace a lifecycle lock. Missing lock is an unsupported
        # topology for this bounded operation, not permission to initialize one.
        lock = os.open(roots['lock'], READ, dir_fd=parent)
        info = os.fstat(lock)
        require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1 and info.st_uid == os.geteuid(),
                'Existing cooperative lock must be an owned single-link regular file')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        before = scan(parent, roots)
        for item in before:
            if not item['parts']:
                allowed = ('regular', 'absent') if item['slot'] in ('state', 'lock') else ('directory', 'absent')
                require(item['kind'] in allowed, 'Unsupported transaction companion topology')
        require(before[0]['kind'] in ('directory', 'absent'), 'Source root must be directory or absent')
        require(any(r['kind'] != 'absent' and r['slot'] in ('source', 'stage', 'backup') for r in before),
                'No source tree/transaction tree to preserve')
        require(evidence(os.stat(roots['lock'], dir_fd=parent, follow_symlinks=False)) == evidence(info),
                'Cooperative lock replaced')
        target = fresh(str(output))
        os.mkdir('objects', 0o700, dir_fd=target)
        objects = os.open('objects', READ | os.O_DIRECTORY, dir_fd=target)
        try:
            copied = scan(parent, roots, objects)
            os.fsync(objects)
        finally:
            os.close(objects)
        require(stable(before) == stable(copied) == stable(scan(parent, roots)),
                'Source/transaction changed; incomplete artifacts retained')
        data = {'schema': SCHEMA, 'identity': identity, 'records': before,
                'records_sha256': sha(json.dumps(before, sort_keys=True).encode()),
                'coverage': 'source-and-exact-transaction-companions-only',
                'writers_quiescent_asserted': True, 'target_home_backup': False,
                'roots': roots}
        raw = (json.dumps(data, sort_keys=True, indent=2) + '\n').encode()
        write_file(target, 'manifest.json', raw)
        verify(target, identity, complete=False)
        require(stable(before) == stable(scan(parent, roots)), 'Source changed before completion')
        bound(parent, root.parent)
        bound(target, output)
        os.fsync(target)
        # Exclusive publication only after verification; a partial marker cannot
        # match its checksum and is never accepted on retry.
        write_file(target, 'COMPLETE.pending', (sha(raw) + '\n').encode())
        os.link('COMPLETE.pending', 'COMPLETE', src_dir_fd=target, dst_dir_fd=target,
                follow_symlinks=False)
        os.unlink('COMPLETE.pending', dir_fd=target)
        os.fsync(target)
    finally:
        if target is not None:
            os.close(target)
        if lock is not None:
            os.close(lock)
        os.close(parent)


def restore(args, identity):
    snapshot_path = outside(args.snapshot, identity)
    output = outside(args.destination, identity)
    require(not output.is_relative_to(snapshot_path) and not snapshot_path.is_relative_to(output),
            'Restore/snapshot paths overlap')
    fd = open_dir(snapshot_path)
    target = None
    try:
        data = verify(fd, identity)  # All bytes, identity and paths before ANY write.
        target = fresh(str(output))
        objects = os.open('objects', READ | os.O_DIRECTORY, dir_fd=fd)
        try:
            for index, item in enumerate(data['records']):
                if item['kind'] == 'absent':
                    continue
                parts = [item['slot']] + [unpacked(p) for p in item['parts']]
                parent = os.dup(target)
                try:
                    for part in parts[:-1]:
                        child = os.open(part, READ | os.O_DIRECTORY, dir_fd=parent)
                        os.close(parent)
                        parent = child
                    name = parts[-1]
                    if item['kind'] == 'directory':
                        os.mkdir(name, 0o700, dir_fd=parent)
                    elif item['kind'] == 'symlink':
                        os.symlink(unpacked(item['link']), name, dir_fd=parent)
                    else:
                        obj = os.open(str(index), READ, dir_fd=objects)
                        out = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                                      0o600, dir_fd=parent)
                        try:
                            with os.fdopen(out, 'wb') as stream:
                                require(regular(obj, stream) == item['sha256'], 'Snapshot changed during restore')
                                stream.flush()
                                os.fsync(stream.fileno())
                        finally:
                            os.close(obj)
                    os.fsync(parent)
                finally:
                    os.close(parent)
        finally:
            os.close(objects)
        # Leaf-first metadata: keep ancestors traversable until children finish.
        for item in reversed(data['records']):
            if item['kind'] == 'absent':
                continue
            parts = [item['slot']] + [unpacked(p) for p in item['parts']]
            parent = os.dup(target)
            try:
                for part in parts[:-1]:
                    child = os.open(part, READ | os.O_DIRECTORY, dir_fd=parent)
                    os.close(parent)
                    parent = child
                name, meta = parts[-1], item['metadata']
                os.chown(name, meta['uid'], meta['gid'], dir_fd=parent, follow_symlinks=False)
                if item['kind'] != 'symlink':
                    os.chmod(name, stat.S_IMODE(meta['mode']), dir_fd=parent, follow_symlinks=False)
                os.utime(name, ns=(meta['atime_ns'], meta['mtime_ns']), dir_fd=parent, follow_symlinks=False)
                require(metadata(os.stat(name, dir_fd=parent, follow_symlinks=False)) == meta,
                        'Restored metadata mismatch; artifacts retained')
                if item['kind'] != 'symlink':
                    restored = os.open(name, READ, dir_fd=parent)
                    try:
                        os.fsync(restored)
                    finally:
                        os.close(restored)
                os.fsync(parent)
            finally:
                os.close(parent)
        actual = scan(target, {slot: slot for slot in SLOTS})
        def portable(records):
            return [{k: v for k, v in r.items() if k != 'evidence'} for r in stable(records)]
        require(portable(actual) == portable(data['records']), 'Restored tree verification mismatch')
        verify(fd, identity)
        bound(fd, snapshot_path)
        bound(target, output)
        # This is an offline layout, not original sibling path publication.
        write_file(target, 'RESTORED.json', (json.dumps({'schema': SCHEMA, 'identity': identity,
                   'snapshot': str(snapshot_path), 'records_sha256': data['records_sha256'],
                   'original_roots': data['roots'], 'published_to_original': False}, sort_keys=True) + '\n').encode())
        os.fsync(target)
    finally:
        if target is not None:
            os.close(target)
        os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command')
    for command in ('snapshot', 'verify', 'restore'):
        child = sub.add_parser(command)
        child.add_argument('--host', required=True)
        child.add_argument('--user', required=True)
        child.add_argument('--inventory-json', required=True)
        child.add_argument('--offline-local-inspection', action='store_true')
        if command != 'snapshot':
            child.add_argument('--snapshot', required=True)
        if command != 'verify':
            child.add_argument('--destination', required=True, help='Fresh absolute directory; existing private parent required')
        if command == 'snapshot':
            child.add_argument('--writers-quiescent', action='store_true',
                               help='Caller has stopped all runtime/editor writers; advisory lock alone is insufficient')
    args = parser.parse_args()
    if args.command is None:
        parser.print_help()
        return
    for name in ('target', 'connection', 'home', 'source_dir'):
        setattr(args, name, None)
    _, identity = inventory_tuple(args, Path(__file__).resolve().parents[3])
    os.umask(0o077)
    if args.command == 'snapshot':
        snapshot(args, identity)
    elif args.command == 'restore':
        restore(args, identity)
    else:
        fd = open_dir(outside(args.snapshot, identity))
        try:
            verify(fd, identity)
        finally:
            os.close(fd)
    print(json.dumps({'operation': args.command, 'status': 'complete', 'target_home_backup': False}))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, StopIteration) as error:
        print(f'Refused: {error}. Any created artifacts are retained; no automatic cleanup/retry.', file=sys.stderr)
        sys.exit(2)
