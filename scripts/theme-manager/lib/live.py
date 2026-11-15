"""Installed live theme commands; publication/recovery belongs to theme-bootstrap.

All commands run under that engine's existing lock. Session effects follow its
commit, are not a second selection writer, and are not claimed crash-atomic.
"""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import uuid
from urllib.parse import urlsplit

HELPERS = Path(__file__).resolve().parent.parent
SLUG = re.compile(r'[A-Za-z0-9][A-Za-z0-9_-]*')
IMAGES = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'}


def state(api):
    root = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state')))
    if not root.is_absolute() or '..' in root.parts:
        raise ValueError('XDG_STATE_HOME must be absolute without parent traversal')
    root /= 'dragon/theme-manager'
    api.directory(root)
    return root


def read_file(path):
    try:
        info = path.lstat()
    except FileNotFoundError:
        return None
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
        raise ValueError(f'Preserve and inspect the conflicting runtime record: {path}')
    return path.read_bytes()


def write_file(path, data):
    read_file(path)  # Never follow a record symlink or replace a personal directory.
    with tempfile.TemporaryDirectory(prefix='.theme-record-', dir=path.parent) as temporary:
        new = Path(temporary) / 'new'
        new.write_bytes(data)
        os.chmod(new, 0o600)
        os.replace(new, path)


def encode(value):
    return (json.dumps(value, sort_keys=True, ensure_ascii=True) + '\n').encode()


def backgrounds_record(root):
    data = read_file(root / 'theme-backgrounds.json')
    value = json.loads(data) if data is not None else {'version': 1, 'items': {}}
    if (not isinstance(value, dict) or value.get('version') != 1 or
            not isinstance(value.get('items'), dict) or
            any(not isinstance(k, str) or (v is not None and not isinstance(v, str))
                for k, v in value['items'].items())):
        raise ValueError('Unknown theme-backgrounds.json format; preserve it for inspection')
    return value


def preview_record(root):
    # Existing firedragon/legacy preview state is not permission to migrate it.
    if any((root / name).exists() or (root / name).is_symlink()
           for name in ('preview-active', 'preview-theme', 'preview-background')):
        raise ValueError('Legacy preview markers exist; preserve/resolve that session before managed preview/set/undo')
    data = read_file(root / 'preview-session.json')
    if data is None:
        return None
    value = json.loads(data)
    if not isinstance(value, dict) or value.get('version') != 1 or not isinstance(value.get('active'), bool):
        raise ValueError('Unknown preview-session.json format; preserve it for inspection')
    if not value['active']:
        return None
    if not isinstance(value.get('generation'), str) or value.get('background') is not None and not isinstance(value.get('background'), str):
        raise ValueError('Incomplete preview session; preserve it for inspection')
    return value


def retained(api, config, path):
    path = Path(path)
    snapshots = config / 'current/.theme-snapshots'
    if (not path.is_absolute() or path.parent.parent != snapshots or path.is_symlink() or
            not path.is_dir() or path.parent.is_symlink()):
        raise ValueError(f'Not a retained managed generation: {path}')
    api.assets(path)
    source = path.parent / 'source'
    if source.is_symlink() or not source.is_file() or not Path(source.read_text()).is_absolute():
        raise ValueError(f'Invalid generation source: {source}')
    return path


def generation(api, config, required=True):
    current = config / 'current/theme'
    if not current.exists() and not current.is_symlink() and not required:
        return None
    if not current.is_symlink():
        raise ValueError('Run theme-bootstrap before live theme selection; no home is adopted automatically')
    return retained(api, config, current.resolve(strict=True))


def source_of(path):
    return Path((path.parent / 'source').read_text()).resolve(strict=False)


def background(api, config):
    api.directory(config / 'current', create=False)
    path = config / 'current/background'
    try:
        info = path.lstat()
    except FileNotFoundError:
        return None
    if not stat.S_ISLNK(info.st_mode):
        raise ValueError(f'Background is a personal file/directory, not an owned link; preserve it: {path}')
    return os.readlink(path)


def validate_background(config, value):
    if value is not None:
        path = Path(value)
        if not path.is_absolute():
            path = config / 'current' / path
        if not path.is_file():
            raise ValueError(f'Background no longer exists: {path}')
        return str(path.resolve(strict=True))
    return value


def image_files(root):
    folder = root / 'backgrounds'
    return sorted(p for p in folder.rglob('*') if p.is_file() and p.suffix.lower() in IMAGES) if folder.is_dir() else []


def set_background(api, config, root, value, *, remember=True):
    value = validate_background(config, value)
    old = background(api, config)
    path = config / 'current/background'
    if old == value:
        return
    # Preserve the real prior image before replacing the pointer. A failed later
    # session effect never deletes image data or claims to undo a visible change.
    if remember and old is not None:
        old_path = Path(old) if Path(old).is_absolute() else path.parent / old
        write_file(root / 'prev-background', (str(old_path.resolve(strict=True)) + '\n').encode())
    with tempfile.TemporaryDirectory(prefix='.background-', dir=path.parent) as temporary:
        if value is None:
            if path.is_symlink():
                path.unlink()
        else:
            new = Path(temporary) / 'new'
            new.symlink_to(value)
            os.replace(new, path)
    record = backgrounds_record(root)
    current = generation(api, config, required=False)
    if current is not None:
        record['items'][str(current)] = value
        write_file(root / 'theme-backgrounds.json', encode(record))


def run(args):
    return subprocess.run([str(x) for x in args], check=True, timeout=30)


def refresh(config, current, *, restart_walker):
    # No guessed installation roots or process-name restart fallbacks. Color
    # files are already regular-file publications by the one engine transaction.
    if (config / 'wayle/config.toml').is_file():
        run([HELPERS / 'wayle-theme-apply', current / 'hyprland-palette.conf'])
    run([HELPERS / 'wallpaper-apply'])
    failures = []
    commands = [['hyprctl', 'reload'], ['swaync-client', '-rs'], ['swaync-client', '-R'],
                ['pkill', '-USR1', '-u', str(os.getuid()), '-x', 'kitty'],
                ['pkill', '-USR2', '-u', str(os.getuid()), '-x', 'btop']]
    if restart_walker and os.environ.get('DRAGON_SKIP_WALKER_RESTART') != '1':
        commands.append(['systemctl', '--user', 'try-restart', 'walker.service'])
    for cmd in commands:
        if shutil.which(cmd[0]) is None:
            continue
        result = subprocess.run(cmd, timeout=10, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if result.returncode and cmd[0] != 'pkill':
            failures.append(cmd[0])
    # GTK base preferences remain user-owned; only derived settings and native
    # refresh keys change. Never quit/restart Nemo or alter SDDM/Plymouth.
    if shutil.which('gsettings'):
        parser = __import__('configparser').RawConfigParser(strict=False)
        parser.read(config / 'gtk-3.0/settings.ini')
        dark = parser.get('Settings', 'gtk-application-prefer-dark-theme', fallback='')
        scheme = 'prefer-dark' if dark == 'true' or (not dark and not (current / 'light.mode').exists()) else 'prefer-light'
        for key, value in [('color-scheme', scheme), ('gtk-theme', parser.get('Settings', 'gtk-theme-name', fallback='Adwaita'))]:
            # Toggle to request a reread, then publish the actual selected value.
            for setting in (('default' if key == 'color-scheme' else 'Adwaita'), value):
                result = subprocess.run(['gsettings', 'set', 'org.gnome.desktop.interface', key, setting],
                                        timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                if result.returncode:
                    failures.append('gsettings:' + key)
    if failures:
        raise RuntimeError('Generation committed; live refresh failed for ' + ', '.join(sorted(set(failures))) + '; retry theme-set for this selection')


def select(api, config, root, action, identifier, no_gui):
    preview = preview_record(root)
    old = generation(api, config)
    old_bg = validate_background(config, background(api, config))
    records = backgrounds_record(root)
    records['items'][str(old)] = old_bg
    metadata = {root / 'theme-backgrounds.json': encode(records)}
    history_from = None
    mode, target = 'set', identifier
    if action == 'preview':
        if preview is None:
            preview = {'version': 1, 'active': True, 'generation': str(old), 'background': old_bg}
        retained(api, config, preview['generation'])
        metadata[root / 'preview-session.json'] = encode(preview)
        mode = 'preview'
    elif action == 'revert' or action == 'undo' and preview is not None:
        if preview is None:
            raise ValueError('No managed preview session is active')
        target = str(retained(api, config, preview['generation']))
        validate_background(config, preview['background'])
        metadata[root / 'preview-session.json'] = encode({'version': 1, 'active': False})
        mode = 'restore'
    elif action == 'undo':
        mode, target = 'undo', None
        previous = read_file(root / 'previous-generation')
        if previous is None:
            raise ValueError('No managed previous generation; existing legacy history is not migrated')
        previous = retained(api, config, previous.decode())
        if str(previous) in records['items']:
            validate_background(config, records['items'][str(previous)])
    elif preview is not None:
        history_from = retained(api, config, preview['generation'])
        # Applying a preview commits it, but Undo returns to the pre-preview
        # generation, not one of the temporary preview selections.
        records['items'][str(history_from)] = preview['background']
        metadata[root / 'theme-backgrounds.json'] = encode(records)
        metadata[root / 'preview-session.json'] = encode({'version': 1, 'active': False})
        if preview['background'] is not None and preview['background'] != old_bg:
            prior = Path(preview['background'])
            if not prior.is_absolute():
                prior = config / 'current' / prior
            metadata[root / 'prev-background'] = (str(prior.resolve(strict=True)) + '\n').encode()
        if old == history_from and identifier in api.theme_sources(config) and api.theme_sources(config)[identifier].resolve() == source_of(old):
            history_from = None
        elif identifier in api.theme_sources(config) and api.theme_sources(config)[identifier].resolve() == source_of(retained(api, config, preview['generation'])):
            # Choosing the pre-preview theme cancels preview without consuming
            # its pre-existing Undo history. A later normal set can apply updates.
            mode, target, history_from = 'restore', preview['generation'], None
            metadata.pop(root / 'prev-background', None)
    ready = api.prepare(config, mode, target, metadata=metadata,
                        history_generation=history_from, live_settings=True)
    if mode == 'restore':
        chosen = preview['background']
    elif mode == 'undo':
        # Historical generations without wallpaper metadata retain the actual
        # current wallpaper. Never invent/rewrite old firedragon history.
        chosen = records['items'].get(str(ready), old_bg)
    elif ready != old:
        images = image_files(ready)
        chosen = str(images[0]) if images else old_bg
    else:
        chosen = old_bg
    set_background(api, config, root, chosen, remember=mode not in ('preview', 'restore'))
    if not no_gui:
        refresh(config, ready, restart_walker=action == 'set')


def catalog(api, config):
    choices = api.theme_sources(config)
    current = config / 'current/theme'
    selected = current.resolve() if current.is_symlink() else None
    if selected is not None and selected.parent.parent == config / 'current/.theme-snapshots':
        selected = source_of(retained(api, config, selected))
    return [{'id': key, 'slug': path.name, 'path': str(path.resolve()),
             'origin': key.split(':')[0], 'current': path.resolve() == selected}
            for key, path in choices.items() if ':' in key]


def gallery_preview(api, config, identifier):
    choices = api.theme_sources(config)
    if identifier not in choices:
        raise ValueError(f'Unknown installed theme: {identifier}')
    theme = choices[identifier]
    images = image_files(theme)
    if not images:
        return ''
    image = images[0].resolve(strict=True)
    data = api.palette(theme / 'hyprland-palette.conf')
    colors = list(dict.fromkeys('#' + c.decode()[:6] for c in re.findall(rb'rgba\(([0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)\)', data)))[:6]
    colors += [colors[-1]] * (6 - len(colors))
    cache = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'dragon/theme-gallery'
    api.directory(cache)
    key = hashlib.sha256(data + str(image).encode() + str(image.stat().st_mtime_ns).encode() + Path(__file__).read_bytes()).hexdigest()
    output = cache / (key + '.png')
    if output.is_symlink():
        raise ValueError('Gallery cache must not redirect writes')
    if not output.exists():
        with tempfile.TemporaryDirectory(prefix='.gallery-', dir=cache) as temporary:
            temporary = Path(temporary)
            run(['magick', image, '-auto-orient', '-resize', '900x500^', '-gravity', 'center', '-extent', '900x500', temporary / 'thumb.png'])
            args = ['magick']
            for color in colors:
                args += ['-size', '150x110', 'xc:' + color]
            run([*args, '+append', temporary / 'colors.png'])
            run(['magick', temporary / 'thumb.png', temporary / 'colors.png', '-append', temporary / 'new.png'])
            os.replace(temporary / 'new.png', output)
    return str(output)


def git(path, *args, capture=False):
    return subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-c', 'protocol.file.allow=never',
                           '-c', 'protocol.ext.allow=never', '-C', str(path), *args],
                          check=True, text=True, stdout=subprocess.PIPE if capture else None,
                          timeout=300).stdout


def remote_url(value):
    if not (value.startswith(('https://', 'ssh://')) or re.fullmatch(r'[^\s/@]+@[^\s/:]+:[^\s]+', value)):
        raise ValueError('Theme source must be an explicit HTTPS or SSH Git URL')
    if '://' in value:
        parsed = urlsplit(value)
        if not parsed.hostname or parsed.password is not None or parsed.scheme == 'https' and parsed.username is not None:
            raise ValueError('Use Git credential/SSH helpers, not credentials embedded in a theme URL')
    return value


def publish_directory(source, destination):
    # Supported desktops are Linux/glibc. No overwrite of an existing personal
    # directory, even an empty one created between validation and publication.
    function = getattr(ctypes.CDLL(None, use_errno=True), 'renameat2', None)
    if function is None:
        raise ValueError('Theme directory publication requires Linux renameat2(RENAME_NOREPLACE)')
    if function(-100, os.fsencode(source), -100, os.fsencode(destination), 1):
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number), str(destination))


def owned_repository(api, config, identifier):
    choices = api.theme_sources(config)
    if identifier not in choices:
        raise ValueError(f'Unknown installed theme: {identifier}')
    path = choices[identifier]
    if path.parent != config / 'themes' or path.is_symlink() or not (path / '.git').is_dir() or (path / '.git').is_symlink():
        raise ValueError('Only explicitly installed personal Git themes can be updated/removed; shipped and unmanaged themes are preserved')
    if git(path, 'config', '--get', 'dragonarchy.theme', capture=True).strip() != 'true':
        raise ValueError(f'Personal repository is not owned by theme-install: {path}')
    if git(path, 'status', '--porcelain', '--untracked-files=all', '--ignored=matching', capture=True).strip():
        raise ValueError(f'Personal edits/untracked files exist; preserve them before update/remove: {path}')
    return path


def install(api, config, root, url, name, no_gui):
    preview_record(root)
    url = remote_url(url)
    slug = name or re.sub(r'-theme$', '', re.sub(r'^dragon-', '', url.rstrip('/').rsplit('/', 1)[-1].removesuffix('.git')))
    if not SLUG.fullmatch(slug):
        raise ValueError('Theme name must be an alphanumeric slug; use --name SLUG')
    personal = config / 'themes'
    api.directory(personal)
    destination = personal / slug
    if destination.exists() or destination.is_symlink():
        raise ValueError(f'Existing personal theme is never replaced: {destination}')
    with tempfile.TemporaryDirectory(prefix='.install-', dir=personal) as temporary:
        source = Path(temporary) / 'source'
        git(personal, 'clone', '--', url, str(source))
        api.assets(source)
        api.palette(source / 'hyprland-palette.conf')
        git(source, 'config', 'dragonarchy.theme', 'true')
        print('Installed source:', git(source, 'remote', 'get-url', 'origin', capture=True).strip(),
              'commit:', git(source, 'rev-parse', 'HEAD', capture=True).strip())
        publish_directory(source, destination)
    # Failure to apply leaves the successfully installed source intact, not rm -rf.
    select(api, config, root, 'apply', 'personal:' + slug, no_gui)


def update(api, config, identifier):
    choices = api.theme_sources(config)
    ids = [identifier] if identifier else [key for key in choices if key.startswith('personal:')]
    for key in ids:
        if identifier is None:
            candidate = choices[key]
            if candidate.is_symlink() or not (candidate / '.git').is_dir() or (candidate / '.git').is_symlink():
                print(f'Preserved unmanaged personal theme: {key}')
                continue
            marked = subprocess.run(['git', '-C', str(candidate), 'config', '--get', 'dragonarchy.theme'],
                                    capture_output=True, text=True, check=False)
            if marked.returncode != 0 or marked.stdout.strip() != 'true':
                print(f'Preserved unmanaged personal theme: {key}')
                continue
        path = owned_repository(api, config, key)
        remote = remote_url(git(path, 'remote', 'get-url', 'origin', capture=True).strip())
        branch = git(path, 'symbolic-ref', '--short', 'HEAD', capture=True).strip()
        old = git(path, 'rev-parse', 'HEAD', capture=True).strip()
        with tempfile.TemporaryDirectory(prefix='.update-', dir=path.parent) as temporary:
            source = Path(temporary) / 'source'
            git(path.parent, 'clone', '--single-branch', '--branch', branch, '--', remote, str(source))
            api.assets(source)
            api.palette(source / 'hyprland-palette.conf')
            new = git(source, 'rev-parse', 'HEAD', capture=True).strip()
            git(source, 'merge-base', '--is-ancestor', old, new)
            git(path, 'fetch', '--no-tags', 'origin', new)
            git(path, 'merge', '--ff-only', '--no-edit', '--no-overwrite-ignore', new)
            print(f'Updated {key}: {old} -> {new}; current generation/background unchanged')


def remove(api, config, root, identifier):
    path = owned_repository(api, config, identifier)
    current = generation(api, config)
    preview = preview_record(root)
    if source_of(current) == path.resolve() or preview and source_of(retained(api, config, preview['generation'])) == path.resolve():
        raise ValueError('Current/preview-original theme cannot be removed')
    values = [background(api, config), *backgrounds_record(root)['items'].values()]
    previous = read_file(root / 'prev-background')
    if previous:
        values.append(previous.decode().strip())
    if preview:
        values.append(preview['background'])
    for value in values:
        if value is not None:
            image = Path(value) if Path(value).is_absolute() else config / 'current' / value
            if image.resolve(strict=False).is_relative_to(path.resolve()):
                raise ValueError('Wallpaper/history still references this source; preserve the theme until explicitly resolved')
    retired = path.parent / '.retired'
    api.directory(retired)
    destination = retired / (path.name + '-' + uuid.uuid4().hex)
    publish_directory(path, destination)
    print(f'Removed from catalog; all files/Git history retained for recovery: {destination}')


def command(api, config, args):
    if not args:
        raise ValueError('Usage: theme-bootstrap live {list,set,apply,undo,preview,revert,background,background-next,background-undo,background-apply,favorite,gallery-preview,install,update,remove}')
    action, *args = args
    no_gui = '--no-gui' in args
    args = [x for x in args if x != '--no-gui']
    root = state(api)
    if action == 'list':
        if args == ['--backgrounds']:
            current = generation(api, config)
            selected = (config / 'current/background').resolve(strict=False)
            print(json.dumps([{'path': str(p), 'name': p.name, 'current': p == selected}
                              for p in image_files(current)]))
            return
        if args not in ([], ['--json']):
            raise ValueError('Usage: theme-list [--json|--backgrounds]')
        items = catalog(api, config)
        print(json.dumps(items) if args else '\n'.join(item['id'] for item in items))
    elif action in ('set', 'apply', 'preview', 'undo', 'revert'):
        if len(args) != (0 if action in ('undo', 'revert') else 1):
            raise ValueError('Theme command requires exactly one installed ID (undo/revert take none)')
        select(api, config, root, action, args[0] if args else None, no_gui)
    elif action == 'commit-preview':
        if args:
            raise ValueError('theme-preview-clear takes no arguments')
        preview = preview_record(root)
        if preview is None:
            return
        current = generation(api, config)
        original = retained(api, config, preview['generation'])
        record = backgrounds_record(root)
        record['items'][str(original)] = preview['background']
        record['items'][str(current)] = background(api, config)
        metadata = {root / 'preview-session.json': encode({'version': 1, 'active': False}),
                    root / 'theme-backgrounds.json': encode(record)}
        if preview['background'] is not None and preview['background'] != background(api, config):
            prior = Path(preview['background'])
            if not prior.is_absolute():
                prior = config / 'current' / prior
            metadata[root / 'prev-background'] = (str(prior.resolve(strict=True)) + '\n').encode()
        api.prepare(config, 'commit', str(current),
                    metadata=metadata,
                    history_generation=original if original != current else None,
                    live_settings=True)
    elif action in ('background', 'background-next', 'background-undo', 'background-apply'):
        if len(args) != (1 if action == 'background' else 0):
            raise ValueError('Background setter takes one image path; next/undo/apply take none')
        preview = preview_record(root)
        old = background(api, config)
        value = old
        if action == 'background':
            value = str(Path(args[0]).expanduser().resolve(strict=True))
        elif action == 'background-next':
            images = image_files(generation(api, config))
            if images:
                actual = (config / 'current/background').resolve() if old is not None else None
                value = str(images[(images.index(actual) + 1) % len(images)] if actual in images else images[0])
        elif action == 'background-undo':
            previous = read_file(root / 'prev-background')
            if previous is None:
                raise ValueError('No previous background recorded')
            value = previous.decode().strip()
        set_background(api, config, root, value, remember=preview is None)
        if not no_gui:
            run([HELPERS / 'wallpaper-apply'])
    elif action == 'favorite':
        if len(args) != 1 or args[0] not in api.theme_sources(config):
            raise ValueError('Choose an installed theme ID')
        path = config / 'dragon/theme-favorites'
        api.directory(path.parent)
        raw = read_file(path)
        existing = raw.decode().splitlines() if raw is not None else []
        target = args[0]
        slug = api.theme_sources(config)[target].name
        aliases = {target}
        if api.theme_sources(config).get(slug) == api.theme_sources(config)[target]:
            aliases.add(slug)
        updated = [x for x in existing if x not in aliases] if aliases.intersection(existing) else [target, *existing]
        write_file(path, ('\n'.join(updated) + '\n').encode())
    elif action == 'gallery-preview':
        if len(args) != 1:
            raise ValueError('Choose an installed theme ID')
        print(gallery_preview(api, config, args[0]))
    elif action == 'install':
        name = None
        if len(args) == 3 and args[1] == '--name':
            name, args = args[2], args[:1]
        if len(args) != 1:
            raise ValueError('Usage: theme-install URL [--name SLUG]')
        install(api, config, root, args[0], name, no_gui)
    elif action == 'update':
        if len(args) > 1 or any(x.startswith('-') for x in args):
            raise ValueError('Usage: theme-update [personal:SLUG]; control-plane updates use install --update')
        update(api, config, args[0] if args else None)
    elif action == 'remove':
        if len(args) != 1:
            raise ValueError('Usage: theme-remove personal:SLUG')
        remove(api, config, root, args[0])
    else:
        raise ValueError(f'Unknown live theme command: {action}')
