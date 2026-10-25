#!/usr/bin/env python3
"""Isolated remote bundle/transaction checks; no SSH or Ansible execution."""
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("remote_sync", ROOT / "scripts/lib/remote-sync.py")
remote_sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(remote_sync)


class RemoteSyncTest(unittest.TestCase):
    def test_installed_palette_bootstrap_without_checkout_preserves_selection_and_preferences(self):
        # Source-output materialization, NOT native chezmoi apply proof. Use the
        # actual manifest/encoding and extracted bundle; run only installed code.
        with tempfile.TemporaryDirectory(prefix='theme-installed-', dir='/tmp/opencode') as temporary:
            root = Path(temporary)
            home = root / 'home'
            config = home / '.config'
            bundle = root / 'bundle'
            archive = root / 'payload.tar'
            extracted = root / 'extracted'
            source = root / 'source'
            # Allowlisted by construction, not inherited then partially patched.
            # This is environment/path isolation, not an OS sandbox.
            environment = {
                'PATH': '/usr/bin:/bin', 'LC_ALL': 'C.UTF-8', 'HOME': str(home),
                'XDG_CONFIG_HOME': str(config), 'XDG_STATE_HOME': str(home / '.local/state'),
                'XDG_CACHE_HOME': str(home / '.cache'), 'XDG_DATA_HOME': str(home / '.local/share'),
                'XDG_RUNTIME_DIR': str(root / 'runtime'), 'TMPDIR': str(root / 'tmp'),
            }
            writable_roots = tuple(Path(environment[key]) for key in (
                'HOME', 'XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME',
                'XDG_DATA_HOME', 'XDG_RUNTIME_DIR', 'TMPDIR'))
            for path in (*writable_roots, bundle, archive, extracted, source):
                self.assertTrue(path.is_absolute() and path.resolve().is_relative_to(root))
                self.assertFalse(path.is_symlink())
            for path in writable_roots:
                path.mkdir(parents=True, exist_ok=True, mode=0o700)
            # The real bundle builder's inventory subprocess also gets only the
            # fixture environment; source reconciliation uses its frozen snapshot.
            with patch.dict(os.environ, environment, clear=True):
                remote_sync.build_bundle(ROOT, bundle, 'firedragon')
            remote_sync.create_archive(bundle, archive)
            extracted.mkdir()
            subprocess.run(['/usr/bin/tar', '-xf', str(archive), '-C', str(extracted)],
                           check=True, cwd=root, env=environment)
            subprocess.run(['/usr/bin/bash', str(extracted / 'infra/chezmoi/bin/chezmoi-sync'),
                            '--host', 'firedragon', '--source-dir', str(source)], check=True,
                           capture_output=True, cwd=root, env=environment)
            # These three declared outputs have only ordinary/dot/executable
            # names. Do not emulate chezmoi's general template/apply machinery.
            shutil.copytree(source / 'dot_config/dragon', config / 'dragon')
            base = config / 'swaync/style-base.css'
            base.parent.mkdir(parents=True)
            shutil.copy2(source / 'dot_config/swaync/style-base.css', base)
            base_original = base.read_bytes()
            self.assertFalse((source / 'dot_config/btop').exists())
            installed = home / '.local/bin/theme-bootstrap'
            installed.parent.mkdir(parents=True)
            for name in ('theme-bootstrap', 'theme-set', 'theme-undo'):
                shutil.copy2(source / ('dot_local/bin/executable_' + name), installed.parent / name)
            renderer_source = source / 'dot_local/libexec/dragon/theme-manager'
            renderer_target = home / '.local/libexec/dragon/theme-manager'
            renderer_target.mkdir(parents=True)
            for relative in ('generate-kitty-themes', 'generate-gtk-themes', 'generate-btop-themes',
                             'generate-swaync-themes', 'lib/theme-utils.sh'):
                path = Path(relative)
                target = renderer_target / path
                target.parent.mkdir(parents=True, exist_ok=True)
                encoded = ('executable_' if (ROOT / 'scripts/theme-manager' / path).stat().st_mode & 0o111 else '') + path.name
                shutil.copy2(renderer_source / path.parent / encoded, target)
            shutil.rmtree(bundle)
            shutil.rmtree(extracted)
            shutil.rmtree(source)

            def prepare(success=True, command='theme-bootstrap', args=()):
                for path in writable_roots:
                    self.assertTrue(path.resolve().is_relative_to(root) and not path.is_symlink())
                result = subprocess.run([str(installed.parent / command), *args], cwd=home, env=environment,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, success, result.stderr)

            original = (config / 'dragon/theme-inputs/tokyo-night/hyprland-palette.conf').read_bytes()
            # Conflicting mutable defaults fail before any selection is published.
            conflict = config / 'btop/btop.conf'
            conflict.mkdir(parents=True)
            prepare(False)
            self.assertFalse((config / 'current/theme').exists())
            self.assertFalse((config / 'theme-manager/wallpaper.conf').exists())
            conflict.rmdir()
            prepare()
            current = config / 'current/theme'
            colors = config / 'hypr/colors-theme.conf'
            self.assertEqual((current / 'hyprland-palette.conf').read_bytes(), original)
            self.assertEqual(colors.read_bytes(), original)
            self.assertEqual(current.resolve().name, 'tokyo-night')
            swaync = config / 'swaync/style.css'
            self.assertTrue(swaync.read_bytes().endswith(base_original))
            self.assertIn(b'@define-color noti-bg rgba(26, 27, 38, 0.9);', swaync.read_bytes())
            btop = config / 'btop/themes/current.theme'
            btop_preferences = config / 'btop/btop.conf'
            self.assertIn(b'theme[main_bg]="#1a1b26"', btop.read_bytes())
            self.assertEqual(btop_preferences.read_bytes(), (config / 'dragon/btop.defaults.conf').read_bytes())
            self.assertIn(b'color_theme = "current"', btop_preferences.read_bytes())
            btop_preferences.write_text('color_theme = "Personal"\n# personal btop settings\n')
            history = Path(environment['XDG_STATE_HOME']) / 'dragon/theme-manager'
            self.assertFalse(history.exists())
            history.mkdir(parents=True)
            sentinel = {history / 'recent-themes': b'personal\nolder\n',
                        history / 'prev-theme': b'personal\n',
                        history / 'previous-generation': b'personal history, not bootstrap input\n'}
            for path, content in sentinel.items():
                path.write_bytes(content)
            preferences = config / 'theme-manager/wallpaper.conf'
            preferences.write_text('WALLPAPER_BACKEND=swaybg\n# personal\n')
            (config / 'current/background').symlink_to('/personal/wallpaper.png')
            (config / 'gtk-3.0').mkdir(exist_ok=True)
            gui = config / 'gtk-3.0/settings.ini'
            gui.write_text('[Settings]\ngtk-theme-name=Personal\n')
            snapshots = config / 'current/.theme-snapshots'
            initial = current.readlink()
            generations = set(snapshots.iterdir())
            prepare()
            self.assertEqual(current.readlink(), initial)
            self.assertEqual(set(snapshots.iterdir()), generations)
            # Structural bytes alone participate in identity, without changing
            # the installed palette or rewriting the old recovery base/output.
            base.write_bytes(base_original + b'\n/* updated structural input */\n')
            prepare()
            self.assertNotEqual(current.readlink(), initial)
            self.assertEqual((initial.parent / 'style-base.css').read_bytes(), base_original)
            self.assertTrue(swaync.read_bytes().endswith(base.read_bytes()))
            base.write_bytes(base_original)
            prepare()
            initial = current.readlink()
            generations = set(snapshots.iterdir())
            # A genuine installed-input update is picked up from provenance.
            updated = original.replace(b'1a1b26ff', b'101020ff')
            (config / 'dragon/theme-inputs/tokyo-night/hyprland-palette.conf').write_bytes(updated)
            prepare()
            self.assertEqual(colors.read_bytes(), updated)
            self.assertNotEqual(current.readlink(), initial)
            self.assertEqual(len(set(snapshots.iterdir()) - generations), 1)
            # Non-palette asset changes also matter, even with identical size
            # and timestamps. Overlapping real helpers must publish only once.
            generations = set(snapshots.iterdir())
            asset = config / 'dragon/theme-inputs/tokyo-night/kitty.conf'
            metadata = asset.stat()
            changed_asset = asset.read_bytes().replace(b'#', b';', 1)
            asset.write_bytes(changed_asset)
            os.utime(asset, ns=(metadata.st_atime_ns, metadata.st_mtime_ns))
            for path in writable_roots:
                self.assertTrue(path.resolve().is_relative_to(root) and not path.is_symlink())
            with subprocess.Popen([str(installed)], cwd=home, env=environment,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE) as first, \
                    subprocess.Popen([str(installed)], cwd=home, env=environment,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE) as second:
                results = [(process, process.communicate(timeout=20)) for process in (first, second)]
            for process, (_, errors) in results:
                self.assertEqual(process.returncode, 0, errors)
            self.assertEqual((current.resolve().parent / 'input/kitty.conf').read_bytes(), changed_asset)
            self.assertIn(b'background #101020', (current / 'kitty.conf').read_bytes())
            self.assertEqual(len(set(snapshots.iterdir()) - generations), 1)
            previous = current.readlink()
            prepare()
            self.assertEqual(current.readlink(), previous)
            self.assertEqual(len(set(snapshots.iterdir()) - generations), 1)
            # A custom external selection with the SAME basename is not reset.
            custom = home / 'personal/tokyo-night'
            custom.mkdir(parents=True)
            custom_palette = original.replace(b'1a1b26ff', b'112233ff')
            (custom / 'hyprland-palette.conf').write_bytes(custom_palette)
            current.unlink()
            current.symlink_to(custom)
            prepare()
            custom_generation = current.readlink()
            generations = set(snapshots.iterdir())
            prepare()
            self.assertEqual(current.readlink(), custom_generation)
            self.assertEqual(set(snapshots.iterdir()), generations)
            self.assertEqual(colors.read_bytes(), custom_palette)
            self.assertEqual({path: path.read_bytes() for path in sentinel}, sentinel)
            # Old generations may carry shipped COLORS-ONLY SwayNC assets, not
            # complete generated stylesheets. No retained structural base exists.
            legacy = snapshots / '.pre-btop-fixture'
            shutil.copytree(custom_generation.parent, legacy)
            custom_generation = legacy / custom_generation.name
            (custom_generation / 'btop.theme').unlink()
            (legacy / 'style-base.css').unlink()
            (custom_generation / 'swaync.css').write_bytes(b'@define-color background #ffffff;\n')
            current.unlink()
            current.symlink_to(custom_generation)
            retained = {p: (p.stat().st_mode, p.read_bytes()) for p in legacy.rglob('*') if p.is_file()}
            # Real installed selection/rendering and exact-generation undo, with
            # no source checkout and no writes into immutable installed assets.
            static = {p: p.read_bytes() for p in (config / 'dragon').rglob('*') if p.is_file()}
            static[base] = base_original
            prepare(command='theme-set', args=('--no-gui', 'nord'))
            nord = current.readlink()
            self.assertEqual(nord.name, 'nord')
            self.assertFalse(colors.is_symlink())
            for destination, relative in (('kitty/colors.conf', 'kitty.conf'),
                                          ('gtk-3.0/gtk.css', 'gtk-3.0/gtk.css'),
                                          ('gtk-4.0/gtk.css', 'gtk-4.0/gtk.css'),
                                          ('btop/themes/current.theme', 'btop.theme'),
                                          ('swaync/style.css', 'swaync.css')):
                self.assertEqual((config / destination).read_bytes(), (current / relative).read_bytes())
                self.assertFalse((config / destination).is_symlink())
            recent = (history / 'recent-themes').read_bytes()
            prepare(command='theme-set', args=('nord',))
            self.assertEqual(current.readlink(), nord)
            self.assertEqual((history / 'recent-themes').read_bytes(), recent)
            # An installed-input refresh of the SAME selection must not replace
            # the custom previous selection with the older Nord generation.
            interactive_history = {path: path.read_bytes() for path in history.iterdir()}
            nord_input = config / 'dragon/theme-inputs/nord/hyprland-palette.conf'
            nord_input.write_bytes(nord_input.read_bytes() + b'\n# declared input refresh\n')
            static[nord_input] = nord_input.read_bytes()
            prepare(command='theme-set', args=('nord',))
            self.assertNotEqual(current.readlink(), nord)
            nord = current.readlink()
            self.assertEqual({path: path.read_bytes() for path in interactive_history}, interactive_history)
            usable = {path: path.read_bytes() for path in (
                colors, config / 'kitty/colors.conf', config / 'gtk-3.0/gtk.css',
                config / 'gtk-4.0/gtk.css', btop, btop_preferences, swaync,
                config / 'current/.published-palette', config / 'current/.swaync-base-source', *history.iterdir())}
            renderer = renderer_target / 'generate-gtk-themes'
            renderer.rename(renderer.with_suffix('.unavailable'))
            prepare(False, command='theme-set', args=('gruvbox',))
            self.assertEqual(current.readlink(), nord)
            self.assertEqual((history / 'recent-themes').read_bytes(), recent)
            self.assertEqual({path: path.read_bytes() for path in usable}, usable)
            renderer.with_suffix('.unavailable').rename(renderer)
            # The actual installed btop renderer cannot execute. A stale shipped
            # Catppuccin asset must not make selection appear successful.
            renderer = renderer_target / 'generate-btop-themes'
            renderer.chmod(0o644)
            prepare(False, command='theme-set', args=('catppuccin',))
            self.assertEqual(current.readlink(), nord)
            self.assertEqual({path: path.read_bytes() for path in usable}, usable)
            renderer.chmod(0o755)
            renderer = renderer_target / 'generate-swaync-themes'
            renderer.chmod(0o644)
            prepare(False, command='theme-set', args=('catppuccin',))
            renderer.chmod(0o755)
            base.rename(base.with_suffix('.unavailable'))
            prepare(False, command='theme-set', args=('catppuccin',))
            base.with_suffix('.unavailable').rename(base)
            self.assertEqual(current.readlink(), nord)
            self.assertEqual({path: path.read_bytes() for path in usable}, usable)
            # Compact assignments look valid to Hyprland but are not separate
            # awk fields. Shipped app assets must not mask skipped rendering.
            rejected = config / 'dragon/theme-inputs/gruvbox'
            for relative in ('kitty.conf', 'gtk-3.0/gtk.css', 'gtk-4.0/gtk.css'):
                self.assertTrue((rejected / relative).is_file())
            rejected_palette = rejected / 'hyprland-palette.conf'
            rejected_original = rejected_palette.read_bytes()
            rejected_palette.write_bytes(rejected_original.replace(b' = ', b'='))
            prepare(False, command='theme-set', args=('gruvbox',))
            self.assertEqual(current.readlink(), nord)
            self.assertEqual({path: path.read_bytes() for path in usable}, usable)
            rejected_palette.write_bytes(rejected_original)
            # An external theme source must not contain a publication destination:
            # publishing btop/current.theme would otherwise mutate its own input.
            overlapping = config / 'btop/themes'
            (overlapping / 'hyprland-palette.conf').write_bytes(custom_palette)
            source_assets = {p: p.read_bytes() for p in overlapping.iterdir() if p.is_file()}
            generations = set(snapshots.iterdir())
            current.unlink()
            current.symlink_to(overlapping)
            prepare(False)
            self.assertEqual(current.readlink(), overlapping)
            self.assertEqual({p: p.read_bytes() for p in source_assets}, source_assets)
            self.assertEqual({p: p.read_bytes() for p in usable}, usable)
            self.assertEqual(set(snapshots.iterdir()), generations)
            current.unlink()
            current.symlink_to(nord)
            # Undo must use retained palette bytes, not today's custom source.
            (custom / 'hyprland-palette.conf').write_bytes(original)
            prepare(command='theme-undo')
            self.assertEqual(current.readlink(), custom_generation)
            self.assertIn(b'theme[main_bg]="#112233"', btop.read_bytes())
            self.assertIn(b'@define-color noti-bg rgba(17, 34, 51, 0.9);', swaync.read_bytes())
            self.assertTrue(swaync.read_bytes().endswith(base_original))
            self.assertTrue((config / 'current/.swaync-base-source').read_text().startswith(str(base) + '\n'))
            for destination, relative in (('hypr/colors-theme.conf', 'hyprland-palette.conf'),
                                          ('kitty/colors.conf', 'kitty.conf'),
                                          ('gtk-3.0/gtk.css', 'gtk-3.0/gtk.css'),
                                          ('gtk-4.0/gtk.css', 'gtk-4.0/gtk.css')):
                self.assertEqual((config / destination).read_bytes(), (custom_generation / relative).read_bytes())
            self.assertEqual({p: (p.stat().st_mode, p.read_bytes()) for p in retained}, retained)
            self.assertFalse((custom_generation / 'btop.theme').exists())
            (custom / 'hyprland-palette.conf').write_bytes(custom_palette)
            # Exact generated undo uses its retained base/output even if today's
            # declared structure changes; old-generation fallback uses today's.
            base.write_bytes(base_original + b'\n/* newer structural input */\n')
            prepare(command='theme-undo')
            self.assertEqual(current.readlink(), nord)
            self.assertEqual(swaync.read_bytes(), (nord / 'swaync.css').read_bytes())
            prepare(command='theme-undo')
            self.assertEqual(current.readlink(), custom_generation)
            self.assertTrue(swaync.read_bytes().endswith(base.read_bytes()))
            base.write_bytes(base_original)
            prepare()
            self.assertEqual(current.readlink(), custom_generation)
            generations = set(snapshots.iterdir())
            prepare()
            self.assertEqual(current.readlink(), custom_generation)
            self.assertEqual(set(snapshots.iterdir()), generations)
            self.assertEqual({p: (p.stat().st_mode, p.read_bytes()) for p in retained}, retained)
            self.assertEqual(btop_preferences.read_text(), 'color_theme = "Personal"\n# personal btop settings\n')
            self.assertEqual({p: p.read_bytes() for p in static}, static)
            previous = current.readlink()
            (custom / 'hyprland-palette.conf').write_text('invalid palette\n')
            prepare(False)
            self.assertEqual(current.readlink(), previous)
            self.assertEqual(colors.read_bytes(), custom_palette)
            self.assertEqual(preferences.read_text(), 'WALLPAPER_BACKEND=swaybg\n# personal\n')
            self.assertEqual(gui.read_text(), '[Settings]\ngtk-theme-name=Personal\n')
            self.assertEqual(os.readlink(config / 'current/background'), '/personal/wallpaper.png')
            self.assertEqual((config / 'dragon/theme-inputs/tokyo-night/hyprland-palette.conf').read_bytes(), updated)

    def test_inventory_scoped_sources_survive_isolated_transport_for_active_fleet(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            environment = {key: value for key, value in os.environ.items() if key != 'INVENTORY_JSON'}

            def sync(checkout, host, source, env=environment):
                subprocess.run(['bash', str(checkout / 'infra/chezmoi/bin/chezmoi-sync'),
                                '--host', host, '--source-dir', str(source)],
                               env=env, check=True, capture_output=True, text=True)

            # Start with journal-owned desktop files, as an existing all-manifest
            # source would, plus personal state that narrowing scope must retain.
            seed = root / 'seed'
            sync(ROOT, 'firedragon', seed)
            (seed / 'dot_config/hypr/personal.conf').write_text('personal monitors\n')
            (seed / 'dot_personal').write_text('unowned\n')
            no_inventory = root / 'bin'
            no_inventory.mkdir()
            query_guard = no_inventory / 'ansible-inventory'
            query_guard.write_text('#!/bin/sh\necho "target queried controller inventory" >&2\nexit 99\n')
            query_guard.chmod(0o755)
            isolated_env = {**environment, 'PATH': str(no_inventory) + ':' + environment['PATH']}
            for host, desktop in (('firedragon', True), ('microdragon', False),
                                  ('ubuntu-mobile-dev', True), ('opencode-runtime', False)):
                with self.subTest(host=host):
                    bundle = root / (host + '-bundle')
                    remote_sync.build_bundle(ROOT, bundle, host)
                    expected = {'devtools-core', 'git-ssh', 'session-zsh'}
                    if desktop:
                        expected |= {'session-core', 'session-shell'}
                    self.assertEqual({p.stem for p in (bundle / 'infra/chezmoi/manifests').iterdir()}, expected)
                    self.assertEqual((bundle / 'packages/hyprland').exists(), desktop)
                    self.assertFalse((bundle / 'infra/ansible/inventory').exists())
                    self.assertFalse((bundle / 'hosts/poco-x3-pro').exists())
                    archive = root / (host + '.tar')
                    remote_sync.create_archive(bundle, archive)
                    target = root / (host + '-target')
                    target.mkdir()
                    subprocess.run(['tar', '--extract', '--file', str(archive), '--directory', str(target),
                                    '--same-permissions', '--no-same-owner'], check=True)
                    outputs = []
                    for checkout in (ROOT, target):
                        source = root / (host + '-' + checkout.name + '-source')
                        shutil.copytree(seed, source)
                        shutil.copy2(Path(str(seed) + '.chezmoi-sync-state'),
                                     Path(str(source) + '.chezmoi-sync-state'))
                        sync(checkout, host, source, environment if checkout == ROOT else isolated_env)
                        self.assertEqual((source / 'dot_config/hypr/hyprland.conf').exists(), desktop)
                        self.assertEqual((source / 'dot_config/autostart').exists(), desktop)
                        self.assertEqual((source / 'dot_config/hypr/personal.conf').read_text(), 'personal monitors\n')
                        self.assertEqual((source / 'dot_personal').read_text(), 'unowned\n')
                        self.assertTrue((source / 'dot_zshrc').is_file())
                        self.assertTrue((source / 'dot_gitconfig').is_file())
                        self.assertFalse((source / 'dot_config/omalauncher').exists())
                        outputs.append({str(p.relative_to(source)): (p.stat().st_mode & 0o7777,
                                        p.read_bytes() if p.is_file() else None) for p in source.rglob('*')})
                    self.assertEqual(*outputs)

    def test_session_manifests_keep_runtime_state_out_of_local_and_remote_sources(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = root / 'repo'
            manifests = repo / 'infra/chezmoi/manifests'
            manifests.mkdir(parents=True)
            (repo / remote_sync.SNAPSHOT).write_text(json.dumps({
                'inventory_hostname': 'fixture', 'host_desktop_stack': 'hyprland'}))
            for name in ('devtools-core', 'git-ssh', 'session-shell'):
                (manifests / (name + '.manifest')).touch()
            shutil.copytree(ROOT / 'infra/chezmoi/bin', repo / 'infra/chezmoi/bin')
            shutil.copytree(ROOT / 'infra/chezmoi/lib', repo / 'infra/chezmoi/lib',
                            ignore=shutil.ignore_patterns('__pycache__'))
            (repo / 'scripts/lib').mkdir(parents=True)
            shutil.copy2(ROOT / 'scripts/lib/target-tuple.py', repo / 'scripts/lib')
            for name in ('session-core', 'session-zsh'):
                manifest = ROOT / 'infra/chezmoi/manifests' / (name + '.manifest')
                shutil.copy2(manifest, manifests)
                for line in manifest.read_text().splitlines():
                    if line.startswith('required|'):
                        source = repo / line.split('|')[1]
                        if (ROOT / line.split('|')[1]).is_file():
                            source.parent.mkdir(parents=True, exist_ok=True)
                            source.write_text('# static shell entry\n')
                        else:
                            source.mkdir(parents=True, exist_ok=True)
            runtime = {
                'hypr/colors-theme.conf': 'generated colors\n',
                'hypr/config/keyboard.local.conf': 'personal keyboard\n',
                'hypr/config/monitor.local.conf': 'personal monitors\n',
                'hypr/config/workspace-indicator.local.conf': 'generated workspaces\n',
                'hypr/config/wallpaper.conf': 'personal wallpaper\n',
                'walker/themes/current/style.css': None,
            }
            hyprland = repo / 'packages/hyprland/.config'
            for name, content in runtime.items():
                path = hyprland / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if content is None:
                    path.symlink_to('../nord/style.css')
                else:
                    path.write_text(content)
            base = hyprland / 'hypr/config/monitor.local.conf.base'
            base.write_bytes((ROOT / 'packages/hyprland/.config/hypr/config/monitor.local.conf.base').read_bytes())
            (repo / 'packages/zsh/.config/zsh/autosuggest-theme.zsh').write_text('generated shell colors\n')
            bundle = root / 'bundle'
            remote_sync.build_bundle(repo, bundle, 'fixture')
            for checkout in (repo, bundle):
                source = root / (checkout.name + '-source')
                subprocess.run(['bash', str(checkout / 'infra/chezmoi/bin/chezmoi-sync'),
                                '--host', 'fixture', '--source-dir', str(source)],
                               check=True, capture_output=True, text=True)
                self.assertEqual((source / 'dot_config/hypr/config/monitor.local.conf.base').read_bytes(),
                                 base.read_bytes())
                names = {path.name for path in source.rglob('*')}
                for name in (*runtime, 'zsh/autosuggest-theme.zsh'):
                    self.assertFalse(any(entry.endswith(Path(name).name) for entry in names), name)
            for name in runtime:
                self.assertFalse((bundle / 'packages/hyprland/.config' / name).is_symlink())
                self.assertFalse((bundle / 'packages/hyprland/.config' / name).exists())

    def test_cleanup_repairs_readonly_directories_without_following_links(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            root = base / 'staging'
            readonly = root / 'readonly'
            readonly.mkdir(parents=True)
            (readonly / 'payload').write_text('owned')
            sentinel = base / 'outside'
            sentinel.mkdir()
            (sentinel / 'file').write_text('preserve')
            (root / 'external').symlink_to(sentinel)
            readonly.chmod(0o555)
            result = subprocess.run([sys.executable, '-c', remote_sync.CLEANUP_CODE, str(root)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(root.exists())
            self.assertEqual((sentinel / 'file').read_text(), 'preserve')

    def test_archive_transport_preserves_metadata(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            bundle = root / "bundle"
            bundle.mkdir()
            for name, mode in (("private", 0o700), ("readonly", 0o555), ("shared", 0o777)):
                directory = bundle / name
                directory.mkdir()
                (directory / "tool").write_text("#!/bin/sh\nexit 0\n")
                (directory / "tool").chmod(0o751)
                (directory / "link").symlink_to("tool")
                directory.chmod(mode)
                os.utime(directory, (1700000000, 1700000000))
            (root / "controller-secret").write_text("never transfer")
            archive = root / "payload.tar"
            remote_sync.create_archive(bundle, archive)
            extracted = root / "target"
            extracted.mkdir()
            subprocess.run(["tar", "--extract", "--file", str(archive), "--directory", str(extracted),
                            "--same-permissions", "--no-same-owner"], check=True,
                           env={**os.environ, "TAR_OPTIONS": ""}, umask=0o077)
            self.assertFalse((extracted / "controller-secret").exists())
            for directory in bundle.iterdir():
                target = extracted / directory.name
                self.assertEqual(target.stat().st_mode & 0o7777, directory.stat().st_mode & 0o7777)
                self.assertEqual(int(target.stat().st_mtime), 1700000000)
                self.assertEqual((target / "tool").stat().st_mode & 0o7777, 0o751)
                self.assertEqual((target / "tool").read_bytes(), (directory / "tool").read_bytes())
                self.assertEqual((target / "link").readlink(), Path("tool"))
                self.assertEqual(target.stat().st_uid, os.geteuid())

    def test_archive_rejects_escaping_symlinks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            bundle = root / "bundle"
            bundle.mkdir()
            link = bundle / "link"
            for destination in ("/etc/passwd", "../outside"):
                link.symlink_to(destination)
                with self.assertRaisesRegex(ValueError, "symlink"):
                    remote_sync.create_archive(bundle, root / "payload.tar")
                link.unlink()

    def test_transport_plan_uses_selected_user_and_cleans_staging(self):
        archive_path = None

        def bundle_fixture(repo, bundle, host, inventory=None):
            bundle.mkdir()
            (bundle / "payload").write_text("fixture")
            (bundle / remote_sync.SNAPSHOT).parent.mkdir(parents=True)
            (bundle / remote_sync.SNAPSHOT).write_text(json.dumps({
                'inventory_hostname': host, 'host_desktop_stack': 'none'}))

        def run_mock(argv):
            nonlocal archive_path
            if argv[0] == "ansible-playbook":
                play, = json.loads(Path(argv[3]).read_text())
                self.assertTrue(play["become"])
                self.assertEqual(play["become_user"], "remoteuser")
                self.assertEqual(play["environment"], {"HOME": "/remote/home/remoteuser"})
                guard, = play["pre_tasks"]
                self.assertEqual(guard["ansible.builtin.command"]["argv"], [
                    "python3", "-c", "import os, sys; sys.exit(os.geteuid() == 0)"])
                for uid in (0, 1000):
                    with patch.object(os, "geteuid", return_value=uid):
                        with self.assertRaises(SystemExit) as guarded:
                            exec(guard["ansible.builtin.command"]["argv"][-1], {})
                    self.assertEqual(guarded.exception.code, uid == 0)
                stage, transaction = play["tasks"]
                self.assertEqual(stage["ansible.builtin.tempfile"]["state"], "directory")
                extract = transaction["block"][0]["ansible.builtin.unarchive"]
                self.assertEqual(extract["extra_opts"], ["--same-permissions", "--no-same-owner"])
                self.assertFalse(extract["remote_src"])
                self.assertNotIn("mode", extract)
                archive_path = Path(extract["src"])
                self.assertTrue(archive_path.is_file())
                cleanup, = transaction["always"]
                self.assertEqual(cleanup["ansible.builtin.command"]["argv"], [
                    "python3", "-c", remote_sync.CLEANUP_CODE, "{{ dotfiles_remote_stage.path }}"])
                return subprocess.CompletedProcess(argv, 42)
            return subprocess.CompletedProcess(argv, 0)

        argv = ["remote-sync.py", "--inventory", "fixture.yml", "--host", "fixture",
                "--user", "remoteuser", "--home", "/remote/home/remoteuser",
                "--source", "/remote/home/remoteuser/.local/share/chezmoi"]
        with patch.object(sys, "argv", argv), patch.object(remote_sync, "build_bundle", bundle_fixture), \
                patch.object(remote_sync.subprocess, "run", run_mock):
            with self.assertRaises(SystemExit) as result:
                remote_sync.main()
        self.assertEqual(result.exception.code, 42)
        self.assertIsNotNone(archive_path)
        self.assertFalse(archive_path.parent.exists())

        argv[argv.index("remoteuser")] = "root"
        with patch.object(sys, "argv", argv), patch.object(sys, "stderr"), \
                patch.object(remote_sync, "build_bundle") as build:
            with self.assertRaises(SystemExit) as result:
                remote_sync.main()
            self.assertEqual(result.exception.code, 2)
            build.assert_not_called()

    def test_bundle_and_target_transaction(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            repo = root / "repo"
            manifests = repo / "infra/chezmoi/manifests"
            manifests.mkdir(parents=True)
            (repo / "infra/chezmoi/bin").mkdir()
            (repo / "scripts/lib").mkdir(parents=True)
            for name in ("target-tuple.py",):
                (repo / "scripts/lib" / name).write_bytes((ROOT / "scripts/lib" / name).read_bytes())
            engine = repo / "infra/chezmoi/bin/chezmoi-sync"
            engine.write_bytes((ROOT / "infra/chezmoi/bin/chezmoi-sync").read_bytes())
            engine.chmod(0o755)
            shutil.copytree(ROOT / "infra/chezmoi/lib", repo / "infra/chezmoi/lib",
                            ignore=shutil.ignore_patterns("__pycache__"))
            payload = repo / "packages/test/config"
            payload.mkdir(parents=True)
            (payload / "owned").write_text("old")
            (payload / "secret").write_text("never transfer")
            (repo / "controller-secret").write_text("never transfer")
            (payload / "link").symlink_to("owned")
            (payload / "tool").write_text("#!/bin/sh\nexit 0\n")
            (payload / "tool").chmod(0o755)
            (repo / remote_sync.SNAPSHOT).write_text(json.dumps({
                'inventory_hostname': 'fixture', 'host_desktop_stack': 'none'}))
            for name in ('git-ssh', 'session-zsh'):
                (manifests / (name + '.manifest')).touch()
            manifest = manifests / "devtools-core.manifest"
            manifest.write_text("required|packages/test/config|dot_config/test\nexclude||dot_config/test/secret\n")
            home = root / "home"
            source = home / ".local/share/chezmoi"
            source.mkdir(parents=True)
            (source / "neighbor").write_text("keep")

            def sync(bundle):
                remote_sync.build_bundle(repo, bundle, "fixture")
                self.assertFalse((bundle / "controller-secret").exists())
                self.assertFalse((bundle / "packages/test/config/secret").exists())
                self.assertTrue((bundle / "packages/test/config/link").is_symlink())
                archive = bundle.with_suffix(".tar")
                remote_sync.create_archive(bundle, archive)
                extracted = bundle.with_name(bundle.name + "-remote")
                extracted.mkdir()
                subprocess.run(["tar", "--extract", "--file", str(archive), "--directory", str(extracted),
                                "--same-permissions", "--no-same-owner"], check=True)
                result = subprocess.run(["bash", str(extracted / "infra/chezmoi/bin/chezmoi-sync"),
                                         "--host", "fixture", "--source-dir", str(source)],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

            sync(root / "bundle1")
            self.assertEqual((source / "dot_config/test/symlink_link").read_text(), "owned")
            self.assertTrue((source / "dot_config/test/executable_tool").stat().st_mode & 0o111)
            (source / "dot_config/test/unowned").write_text("keep too")
            (payload / "owned").unlink()
            (payload / "new").write_text("new")
            sync(root / "bundle2")
            self.assertFalse((source / "dot_config/test/owned").exists())
            self.assertEqual((source / "dot_config/test/unowned").read_text(), "keep too")
            self.assertEqual((source / "neighbor").read_text(), "keep")
            (payload / "new").write_text("changed")
            bundle = root / "bundle3"
            remote_sync.build_bundle(repo, bundle, "fixture")
            result = subprocess.run(["bash", str(bundle / "infra/chezmoi/bin/chezmoi-sync"),
                                     "--host", "fixture", "--source-dir", str(source)],
                                    env={**os.environ, "CHEZMOI_SYNC_FAILPOINT": "copy:1"},
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((source / "dot_config/test/new").read_text(), "new")
            sync(root / "bundle4")
            self.assertEqual((source / "dot_config/test/new").read_text(), "changed")
            result = subprocess.run(["bash", str(bundle / "infra/chezmoi/bin/chezmoi-sync"),
                                     "--host", "fixture", "--source-dir", str(source)],
                                    env={**os.environ, "CHEZMOI_SYNC_FAILPOINT": "promote:after-park"},
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(Path(str(source) + ".chezmoi-sync-backup").is_dir())
            sync(root / "bundle5")
            self.assertEqual((source / "neighbor").read_text(), "keep")
            self.assertEqual((source / "dot_config/test/unowned").read_text(), "keep too")
            self.assertFalse(Path(str(source) + ".chezmoi-sync-backup").exists())
            self.assertTrue(Path(str(source) + ".chezmoi-sync-lock").is_file())
            (payload / "id_ed25519").write_text("not a distributable")
            unsafe = root / "unsafe-content"
            remote_sync.build_bundle(repo, unsafe, "fixture")
            result = subprocess.run(["bash", str(unsafe / "infra/chezmoi/bin/chezmoi-sync"),
                                     "--host", "fixture", "--source-dir", str(root / "isolated-preflight")],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Unsafe distributable artifact", result.stderr)
            self.assertFalse((root / "isolated-preflight").exists())
            package = repo / "packages/test"
            package.rename(root / "outside-package")
            package.symlink_to(root / "outside-package")
            with self.assertRaisesRegex(ValueError, "ancestor is a symlink"):
                remote_sync.build_bundle(repo, root / "unsafe-bundle", "fixture")

    def test_target_path_check_rejects_symlinks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            home = root / "home"
            home.mkdir()
            link = root / "link"
            link.symlink_to(home)
            result = subprocess.run(["python3", str(ROOT / "scripts/lib/target-tuple.py"),
                                     "check-paths", str(link), str(link / ".local/share/chezmoi")],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("symlink", result.stderr)
            result = subprocess.run(["python3", str(ROOT / "scripts/lib/target-tuple.py"),
                                     "check-paths", "/" + str(home), "/" + str(home / ".local/share/chezmoi")],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("lexically canonical", result.stderr)
            source = home / ".local/share/chezmoi"
            source.parent.mkdir(parents=True)
            source.symlink_to(root / "elsewhere")
            result = subprocess.run(["python3", str(ROOT / "scripts/lib/target-tuple.py"),
                                     "check-paths", str(home), str(source)],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("symlink", result.stderr)


if __name__ == "__main__":
    unittest.main()
