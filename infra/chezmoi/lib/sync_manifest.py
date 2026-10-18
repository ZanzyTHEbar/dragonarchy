"""Validate manifests and plan native chezmoi source entries without mutation."""

import fnmatch
import os
from pathlib import Path
import re
import stat


def require(condition, message):
    if not condition:
        raise ValueError(message)


def relative(value, kind):
    require(value and not value.startswith('/') and
            all(part not in ('', '.', '..') for part in value.split('/')) and
            '\0' not in value, f'Invalid manifest {kind} path: {value}')


def directory_chain(path, label, leaf=False):
    current = Path(path.anchor)
    parts = path.parts[1:] if path.is_absolute() else path.parts
    for part in parts if leaf else parts[:-1]:
        current /= part
        require(not current.is_symlink(), f'{label} contains a symlink: {current}')
        require(not current.exists() or current.is_dir(),
                f'{label} is not a directory: {current}')


def source_root(value):
    require(value.startswith('/'), f'--source-dir must be absolute: {value}')
    require(value != '/', '--source-dir cannot be the filesystem root')
    require(all(p not in ('', '.', '..') for p in value[1:].split('/')),
            f'--source-dir must be canonical: {value}')
    path = Path(value)
    directory_chain(path, '--source-dir', leaf=True)
    return path


def destination(root, rel):
    relative(rel, 'destination')
    directory_chain(root, 'Destination path', leaf=True)
    directory_chain(root / rel, 'Destination path')
    return root / rel


def kind(path):
    mode = path.lstat().st_mode
    if stat.S_ISLNK(mode):
        return 'symlink'
    if stat.S_ISDIR(mode):
        return 'directory'
    require(stat.S_ISREG(mode), f'Unsupported file type: {path}')
    return 'regular'


RESERVED = ('dot executable private symlink literal empty readonly create modify '
            'remove exact run once encrypted after before external onchange').split()
ATTRIBUTES = re.compile(r'^(?:(?:private|readonly|empty|executable|symlink)_)+')


def encode(name):
    hidden = name.startswith('.')
    bare = name[1:] if hidden else name
    reserved = bare.endswith('.tmpl') or any(bare.startswith(p + '_') for p in RESERVED)
    result = ('dot_' if hidden else '') + ('literal_' if reserved else '') + bare
    return result + ('.tmpl' if result.endswith('.tmpl') else '')


def direct(name):
    if name.endswith('.tmpl'):
        if name.startswith('dot_') and not name.startswith('dot_literal_'):
            return 'dot_literal_' + name[4:] + '.tmpl'
        if not name.startswith('literal_'):
            return 'literal_' + name + '.tmpl'
    return name


def prefix(path, entry_kind):
    if entry_kind == 'symlink':
        return 'symlink_'
    info = path.stat()
    result = 'private_' if info.st_mode & 0o077 == 0 else ''
    if info.st_mode & 0o222 == 0:
        result += 'readonly_'
    if entry_kind == 'regular':
        if info.st_size == 0:
            result += 'empty_'
        if info.st_mode & 0o111:
            result += 'executable_'
    return result


def normalized(rel):
    return '/'.join(ATTRIBUTES.sub('', part) for part in rel.split('/'))


UNSAFE_NAMES = '''.env* .git .gitmodules .gitattributes .gitkeep .package readme*
.vscode .idea .vs .fleet .project .classpath .settings *.code-workspace
*.sublime-project *.sublime-workspace identity *.pem *.key *.crt *.cer *.der
*.p12 *.pfx *.jks *.keystore *~ *.bak *.backup *.old *.orig *.rej *.swp *.swo
*.log *.log.* clipboard_history.json'''.split()
for _name in '''secret secrets credential credentials password passwd token api_key
api-key apikey access_token access-token auth_token auth-token client_secret
client-secret private_key private-key'''.split():
    UNSAFE_NAMES.extend((_name, _name + '.*'))
for _name in ('id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519', 'id_xmss'):
    UNSAFE_NAMES.extend((_name, _name + '-*', _name + '_*'))
UNSAFE_DIRS = set('''.cache node_modules bower_components vendor build dist out target
coverage backup backups .next .nuxt .svelte-kit .angular .turbo .parcel-cache
.vite .webpack .rollup.cache .yarn .pnpm-store .terraform .gradle .m2 .venv venv
env __pycache__ .pytest_cache .mypy_cache .ruff_cache .tox .nox'''.split())
SECRET_KEY = (r'api[_-]?key|apikey|access[_-]?token|auth[_-]?token|bearer[_-]?token|'
              r'client[_-]?secret|aws[_-]?access[_-]?key[_-]?id|'
              r'aws[_-]?secret[_-]?access[_-]?key|database[_-]?url|db[_-]?password|'
              r'password|passwd|secret|token|private[_-]?key|credentials?')
PRIVATE_KEY = re.compile(rb'-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY( BLOCK)?-----')
ASSIGNMENT = re.compile(
    r'''^\s*(export\s+)?([a-z0-9]+_)*(''' + SECRET_KEY + r''')\s*[:=]\s*(['"][^$]|[a-z0-9_+/-]+={0,2}(\s*(#.*)?$))''',
    re.I | re.ASCII)
JSON_SECRET = re.compile(r'"(' + SECRET_KEY + r')"\s*:\s*"[^${"]+"', re.I | re.ASCII)


def safe_entry(path, entry_kind, target, root):
    name = path.name.lower()
    unsafe = any(fnmatch.fnmatchcase(name, pattern) for pattern in UNSAFE_NAMES)
    unsafe |= entry_kind == 'directory' and name in UNSAFE_DIRS
    if entry_kind == 'regular':
        content = path.read_bytes()
        text = content.decode('latin1')
        unsafe |= bool(PRIVATE_KEY.search(content) or JSON_SECRET.search(text))
        unsafe |= any(ASSIGNMENT.search(line) and not re.search(r'^[^:=]*[:=]\s*\$\{\{', line)
                      for line in text.splitlines())
    require(not unsafe, f'Unsafe distributable artifact: {path}')
    if entry_kind == 'symlink':
        link = os.readlink(path)
        resolved = Path(os.path.normpath(os.path.join(root / target, '..', link)))
        require(resolved == root or root in resolved.parents,
                f'Symlink target escapes --source-dir: {path} -> {link}')


def plan(repo, manifests, host, root):
    records = []
    excludes = set()
    for manifest in manifests:
        for number, line in enumerate(manifest.read_bytes().decode('utf-8', 'surrogateescape').split('\n'), 1):
            require('\r' not in line, f'Manifest record contains CR at {manifest}:{number}')
            if not line or line.startswith('#'):
                continue
            fields = line.split('|')
            require(len(fields) == 3, f'Malformed manifest record at {manifest}:{number}')
            mode, source, target = (field.replace('__HOST__', host) for field in fields)
            relative(target, 'destination')
            destination(root, target)
            if mode == 'exclude':
                require(not source, f'Exclude source field must be empty at {manifest}:{number}')
                excludes.add(normalized(target))
                continue
            require(mode in ('required', 'optional'), f'Unknown manifest mode: {mode}')
            relative(source, 'source')
            require(source.startswith(('packages/', f'hosts/{host}/dotfiles/')),
                    f'Manifest source is outside the allowed roots: {source}')
            path = repo / source
            directory_chain(path, 'Source path')
            exists = path.exists() or path.is_symlink()
            require(exists or mode == 'optional', f'Required source missing: {source}')
            entry_kind = kind(path) if exists else None
            records.append((mode, source, target, entry_kind))

    overrides = set()
    for index, first in enumerate(records):
        for second in records[:index]:
            require(first[2] != second[2], f'Duplicate logical destination: {first[2]}')
            parent, child = sorted((first, second), key=lambda r: len(r[2]))
            if not child[2].startswith(parent[2] + '/'):
                continue
            allowed = (parent[0] == 'required' and parent[1].startswith('packages/') and
                       parent[3] == 'directory' and child[0] == 'optional' and
                       child[1].startswith(f'hosts/{host}/dotfiles/') and
                       child[3] in (None, 'regular'))
            require(allowed, f'Mapped parent/child destination conflict: {first[2]} and {second[2]}')
            if child[3] is not None:
                overrides.add(child[2])

    entries = {}

    def walk(path, target, logical, include=True):
        entry_kind = kind(path)
        destination(root, target)
        if normalized(target) in excludes:
            return
        safe_entry(path, entry_kind, target, root)
        if include:
            require(target not in entries, f'Duplicate rendered destination: {target}')
            entries[target] = (path, entry_kind)
        if entry_kind == 'directory':
            require(os.access(path, os.R_OK | os.X_OK), f'Directory is not readable/searchable: {path}')
            for child in sorted(path.iterdir()):
                child_kind = kind(child)
                child_logical = logical + '/' + child.name
                walk(child, target + '/' + prefix(child, child_kind) + encode(child.name),
                     child_logical, include and child_logical not in overrides)

    for _, source, target, entry_kind in records:
        if entry_kind is None:
            continue
        path = repo / source
        parent, _, name = target.rpartition('/')
        rendered = (parent + '/' if parent else '') + prefix(path, entry_kind) + direct(name)
        walk(path, rendered, target)
    return entries, excludes
