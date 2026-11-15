#!/usr/bin/env python3
"""Isolated remote bundle/transaction checks; no SSH or Ansible execution."""
import importlib.util
import json
import os
import select
import shlex
import shutil
import socket
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
from types import SimpleNamespace
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
        with tempfile.TemporaryDirectory(prefix='theme-installed-') as temporary:
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
            walker_base = root / 'walker-2.17.2.css'
            walker_base.write_text('/* structural provider fixture */\n.box { padding: 12px; }\n')
            environment['WALKER_BASE'] = str(walker_base)
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
            shutil.copytree(source / 'dot_config/hypr/defaults', config / 'hypr/defaults')
            base = config / 'swaync/style-base.css'
            base.parent.mkdir(parents=True)
            shutil.copy2(source / 'dot_config/swaync/style-base.css', base)
            waybar_style = config / 'waybar/style.css'
            waybar_style.parent.mkdir()
            shutil.copy2(source / 'dot_config/waybar/style.css', waybar_style)
            waybar_style_original = waybar_style.read_bytes()
            self.assertTrue(waybar_style_original.startswith(b'@import "colors-theme.css";'))
            self.assertFalse((source / 'dot_config/waybar/colors-theme.css').exists())
            walker_themes = config / 'walker/themes'
            shutil.copytree(source / 'dot_config/walker/themes', walker_themes)
            walker = walker_themes / 'current/style.css'
            walker.parent.mkdir()
            walker.symlink_to('../tokyo-night/style.css')
            walker_layout = walker.parent / 'layout.xml'
            walker_layout.write_text('personal layout\n')
            named_tokyo = walker_themes / 'tokyo-night/style.css'
            named_tokyo_original = named_tokyo.read_bytes()
            self.assertFalse((source / 'dot_config/walker/themes/current').exists())
            base_original = base.read_bytes()
            self.assertFalse((source / 'dot_config/btop').exists())
            installed = home / '.local/bin/theme-bootstrap'
            installed.parent.mkdir(parents=True)
            for name in ('theme-bootstrap', 'theme-set', 'theme-undo',
                         'walker-clipboard', 'clipse-wrapper', 'dragon-clipboard-session',
                         'keybindings-menu', 'keyboard-layout'):
                shutil.copy2(source / ('dot_local/bin/executable_' + name), installed.parent / name)
            keyboard_module = json.loads((source / 'dot_config/waybar/config.jsonc').read_text())['custom/keyboard']
            keyboard_binding = (source / 'dot_config/hypr/lua/bindings.lua').read_text()
            self.assertIn('hl.bind("ALT + SPACE", d.exec_cmd(\'"$HOME/.local/bin/keyboard-layout" switch\')', keyboard_binding)
            keybindings_action = tomllib.loads(
                (source / 'dot_config/elephant/menus/keybindings.toml').read_text()
            )['entries'][0]['actions']['menus:default']
            renderer_source = source / 'dot_local/libexec/dragon/theme-manager'
            renderer_target = home / '.local/libexec/dragon/theme-manager'
            renderer_target.mkdir(parents=True)
            for relative in ('generate-kitty-themes', 'generate-gtk-themes', 'generate-btop-themes',
                             'generate-swaync-themes', 'generate-clipse-themes',
                             'generate-walker-themes', 'lib/theme-utils.sh', 'lib/live.py'):
                path = Path(relative)
                target = renderer_target / path
                target.parent.mkdir(parents=True, exist_ok=True)
                encoded = ('executable_' if (ROOT / 'scripts/theme-manager' / path).stat().st_mode & 0o111 else '') + path.name
                shutil.copy2(renderer_source / path.parent / encoded, target)
            shutil.rmtree(bundle)
            shutil.rmtree(extracted)
            shutil.rmtree(source)

            # Run the installed clipboard helpers without a checkout or a live
            # desktop; substitute only their external session executables.
            fakebin = root / 'session-bin'
            fakebin.mkdir()
            for name, body in {
                'hyprctl': "printf '[{\"focused\":true,\"height\":1080}]\\n'\n",
                'walker': 'printf "%s\\n" "$@" > "$CAPTURE"\n',
                'pgrep': 'exit 0\n',
                'clipse': 'printf "%s\\n" "$@" > "$CAPTURE"\n',
            }.items():
                executable = fakebin / name
                executable.write_text('#!/bin/sh\n' + body)
                executable.chmod(0o755)
            capture = root / 'clipboard-arguments'
            session_env = dict(environment, PATH=str(fakebin) + ':/usr/bin:/bin', CAPTURE=str(capture))
            subprocess.run([str(installed.parent / 'walker-clipboard')], check=True,
                           cwd=home, env=session_env)
            self.assertEqual(capture.read_text().splitlines(),
                             ['-m', 'clipboard', '--width', '900', '--height', '540'])
            # Clipse now requires real installed unit/provider ownership. Keep
            # that guard real and headless here, rather than faking a session.
            # Its pinned external TUI argv is a separate delivery contract.
            clipse = subprocess.run([str(installed.parent / 'clipse-wrapper')],
                                    cwd=home, env=session_env, capture_output=True, text=True)
            self.assertNotEqual(clipse.returncode, 0)
            self.assertIn('a real Wayland session is required', clipse.stderr)
            invocation = shlex.split((installed.parent / 'clipse-wrapper').read_text().splitlines()[-1])
            self.assertEqual(invocation[:2], ['exec', '/usr/local/bin/clipse'])
            self.assertEqual(invocation[2:], ['-enable-real-time'])
            self.assertEqual(capture.read_text().splitlines(),
                             ['-m', 'clipboard', '--width', '900', '--height', '540'])

            # Exercise the configured Waybar commands using the transported
            # helper and synthetic compositor/notification/process boundaries.
            keyboard_bin = root / 'keyboard-bin'
            keyboard_bin.mkdir()
            for name, body in {
                'hyprctl': '''if [ "$1" = devices ]; then
  printf '{"keyboards":[{"name":"fixture-keyboard","active_keymap":"%s"}]}\\n' "$(cat "$LAYOUT")"
else
  printf '%s\\n' "$*" >> "$SWITCHES"
  printf 'Portuguese\\n' > "$LAYOUT"
fi
''',
                'notify-send': 'printf "%s\\n" "$@" > "$NOTIFICATION"\n',
                'pkill': 'printf "%s\\n" "$@" > "$SIGNAL"\n',
            }.items():
                executable = keyboard_bin / name
                executable.write_text('#!/bin/sh\n' + body)
                executable.chmod(0o755)
            layout, switches = root / 'layout', root / 'switches'
            notification, signal = root / 'notification', root / 'signal'
            layout.write_text('English (US)\n')
            keyboard_env = dict(environment, PATH=str(keyboard_bin) + ':/usr/bin:/bin',
                                LAYOUT=str(layout), SWITCHES=str(switches),
                                NOTIFICATION=str(notification), SIGNAL=str(signal))
            def keyboard(command):
                return subprocess.run(['/bin/sh', '-c', command], cwd=home, env=keyboard_env,
                                      check=True, capture_output=True, text=True, timeout=10)
            self.assertIn('EN', json.loads(keyboard(keyboard_module['exec']).stdout)['text'])
            keyboard(keyboard_module['on-click'])
            self.assertIn('PT', json.loads(keyboard(keyboard_module['exec']).stdout)['text'])
            self.assertEqual(switches.read_text().splitlines(), ['switchxkblayout fixture-keyboard next'])
            self.assertIn('Switched to Portuguese (PT)', notification.read_text())
            self.assertEqual(signal.read_text().splitlines(), ['-RTMIN+12', 'waybar'])

            # The installed menu must show both different modifiers and Kitty's
            # separate binding for a combination also used by Hyprland.
            pickerbin = root / 'picker-bin'
            pickerbin.mkdir()
            for name in ('find', 'grep', 'sed', 'awk', 'sort', 'cut', 'cat', 'jq'):
                (pickerbin / name).symlink_to(shutil.which(name, path='/usr/bin:/bin'))
            live_binds = [
                dict(modmask=64, key='V', dispatcher='exec', arg='super-clipboard'),
                dict(modmask=8, key='V', dispatcher='exec', arg='alt-clipboard'),
                dict(modmask=64, key='V', dispatcher='exec', arg='super-clipboard'),
                dict(modmask=64, key='C', description='Clipboard menu', dispatcher='exec', arg='clipboard-menu'),
                dict(modmask=64, key='mouse:275', dispatcher='movewindow'),
                dict(modmask=0, key='XF86AudioRaiseVolume', dispatcher='exec', arg='volume-up'),
                dict(modmask=8, key='K', description='Personal keybinding', dispatcher='exec', arg='personal-command'),
            ]
            compositor = pickerbin / 'hyprctl'
            compositor.write_text('#!/bin/sh\nprintf \'%s\\n\' \'' + json.dumps(live_binds) + '\'\n')
            compositor.chmod(0o755)
            picker = pickerbin / 'walker'
            picker.write_text('#!/bin/sh\ncat > "$CAPTURE"\n')
            picker.chmod(0o755)
            bindings = config / 'hypr/local/bindings.lua'
            bindings.parent.mkdir(parents=True)
            bindings.write_text('-- Bindings are enumerated from the compositor, not parsed from source.\n')
            mappings = config / 'kitty/mappings.conf'
            mappings.parent.mkdir(parents=True)
            mappings.write_text('map super+v paste_from_clipboard\n')
            stow = root / 'stow'
            legacy = stow / 'hyprland/.config/hypr/local/personal.lua'
            legacy.parent.mkdir(parents=True)
            personal_binding = 'hl.bind("ALT + K", hl.dsp.exec_cmd("personal-command"), { description = "Personal keybinding" })\n'
            legacy.write_text(personal_binding)
            subprocess.run(['/usr/bin/stow', '--no-folding', '--dir', str(stow),
                            '--target', str(home), 'hyprland'], check=True,
                           cwd=root, env=environment, capture_output=True)
            legacy_link = bindings.parent / 'personal.lua'
            self.assertTrue(legacy_link.is_symlink())
            picker_env = dict(environment, PATH=str(pickerbin), CAPTURE=str(capture))
            subprocess.run(['/bin/sh', '-c', keybindings_action], check=True,
                           cwd=home, env=picker_env, timeout=10)
            entries = capture.read_text()
            self.assertIn('SUPER + V', entries)
            self.assertIn('ALT + V', entries)
            self.assertIn('[Kitty]', entries)
            self.assertIn('paste_from_clipboard', entries)
            self.assertEqual(entries.count('super-clipboard'), 1)
            self.assertIn('│  Clipboard menu\n', entries)
            self.assertIn('│  Personal keybinding\n', entries)
            self.assertTrue(legacy_link.is_symlink())
            self.assertEqual(legacy.read_text(), personal_binding)
            self.assertIn('MOUSE BUTTON 275', entries)
            self.assertIn('│  volume-up\n', entries)

            def prepare(success=True, command='theme-bootstrap', args=()):
                for path in writable_roots:
                    self.assertTrue(path.resolve().is_relative_to(root) and not path.is_symlink())
                # This scenario qualifies offline publication/recovery. Public
                # live commands additionally own wallpaper/session effects.
                mode = {'theme-set': ('set',), 'theme-undo': ('undo',)}.get(command, ())
                result = subprocess.run([str(installed), *mode, *args], cwd=home, env=environment,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, success, result.stderr)
                return result

            def native_palette(data):
                # Stable installed Lua data contract, derived independently
                # from the fixture palette's ordinary whitespace fields.
                entries = []
                for line in data.decode().splitlines():
                    fields = line.split('#', 1)[0].split()
                    if fields:
                        key, _, value = fields
                        entries.append(f'    ["{key[1:]}"] = "#{value[5:-1]}",\n')
                return ('-- Generated by theme-bootstrap; edits are replaced.\nreturn {\n' +
                        ''.join(entries) + '}\n').encode()

            original = (config / 'dragon/theme-inputs/tokyo-night/hyprland-palette.conf').read_bytes()
            # Conflicting mutable defaults fail before any selection is published.
            conflict = config / 'btop/btop.conf'
            conflict.mkdir(parents=True)
            prepare(False)
            self.assertFalse((config / 'current/theme').exists())
            self.assertFalse((config / 'theme-manager/wallpaper.conf').exists())
            conflict.rmdir()
            # A first automatic bootstrap must not take existing personal CSS
            # or a legacy/user link when there is no selected theme to own it.
            personal_css = config / 'gtk-3.0/gtk.css'
            personal_css.parent.mkdir(exist_ok=True)
            personal_css.write_text('personal CSS\n')
            kitty_target = home / 'personal-kitty.conf'
            kitty_target.write_text('personal colors\n')
            kitty_colors = config / 'kitty/colors.conf'
            kitty_colors.parent.mkdir(exist_ok=True)
            kitty_colors.symlink_to(kitty_target)
            result = prepare(False)
            self.assertIn('Theme output exists without a theme selection', result.stderr)
            self.assertIn(str(kitty_colors), result.stderr)
            self.assertEqual(personal_css.read_text(), 'personal CSS\n')
            self.assertTrue(kitty_colors.is_symlink())
            self.assertEqual(kitty_target.read_text(), 'personal colors\n')
            self.assertFalse((config / 'current/theme').exists())
            self.assertFalse((config / 'hypr/colors-theme.lua').exists())
            kitty_colors.unlink()
            result = prepare(False)
            self.assertIn(str(personal_css), result.stderr)
            self.assertEqual(personal_css.read_text(), 'personal CSS\n')
            self.assertFalse((config / 'current/theme').exists())
            personal_css.unlink()
            # An incumbent generated-output link also refuses initial adoption;
            # its named source and unrelated personal layout remain untouched.
            result = prepare(False)
            self.assertIn(str(walker), result.stderr)
            self.assertTrue(walker.is_symlink())
            self.assertEqual(named_tokyo.read_bytes(), named_tokyo_original)
            self.assertEqual(walker_layout.read_text(), 'personal layout\n')
            walker.unlink()

            # Stop the real installed engine just after it classified the
            # selection as absent, then let another writer create one.
            hook = root / 'race-hook'
            hook.mkdir()
            (hook / 'sitecustomize.py').write_text('''import os, sys
hits = 0
def trace(frame, event, arg):
    global hits
    if (event == "line" and frame.f_code.co_name in ("prepare", "finish_recovery") and
            frame.f_code.co_filename == os.environ["RACE_SCRIPT"] and
            frame.f_lineno == int(os.environ["RACE_LINE"]) and
            (not os.environ.get("RACE_PATH") or
             str(frame.f_locals.get("path")) == os.environ["RACE_PATH"])):
        hits += 1
        if hits < int(os.environ.get("RACE_HIT", "1")):
            return trace
        sys.settrace(None)
        os.write(int(os.environ["RACE_READY"]), b"1")
        os.read(int(os.environ["RACE_CONTINUE"]), 1)
    return trace
sys.settrace(trace)
''')
            lines = installed.read_text().splitlines()
            outsider = home / 'outside-theme'
            outsider.mkdir()
            outsider_file = outsider / 'personal.conf'
            outsider_file.write_text('outside content\n')
            current = config / 'current/theme'

            def race_at(line, action, path='', args=(), restrictive_umask=False, hit=1):
                ready_r, ready_w = os.pipe()
                continue_r, continue_w = os.pipe()
                race_env = dict(environment, PYTHONPATH=str(hook), RACE_SCRIPT=str(installed),
                                RACE_LINE=str(lines.index(line) + 1), RACE_PATH=str(path),
                                RACE_HIT=str(hit), RACE_READY=str(ready_w), RACE_CONTINUE=str(continue_r))
                command = [str(installed), *args]
                if restrictive_umask:
                    command = ['/bin/sh', '-c', 'umask 0400; exec "$@"', 'sh', *command]
                process = subprocess.Popen(command, cwd=home, env=race_env,
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                           pass_fds=(ready_w, continue_r))
                os.close(ready_w)
                os.close(continue_r)
                try:
                    self.assertTrue(select.select([ready_r], [], [], 20)[0], 'bootstrap did not reach checkpoint')
                    ready = os.read(ready_r, 1)
                    self.assertEqual(ready, b'1', process.stderr.read() if not ready else '')
                    action()
                finally:
                    try:
                        os.write(continue_w, b'1')
                    except BrokenPipeError:
                        pass
                    os.close(continue_w)
                    os.close(ready_r)
                    try:
                        _, stderr = process.communicate(timeout=30)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.communicate()
                        raise
                self.assertNotEqual(process.returncode, 0, stderr)
                return stderr

            def insert_selection():
                self.assertFalse(current.exists() or current.is_symlink())
                current.symlink_to(outsider)
            race_at("        selected = inputs / 'tokyo-night'", insert_selection)
            self.assertTrue(current.is_symlink())
            self.assertEqual(current.readlink(), outsider)
            self.assertEqual(outsider_file.read_text(), 'outside content\n')
            self.assertFalse((config / 'hypr/colors-theme.lua').exists())
            self.assertFalse((config / 'theme-manager/wallpaper.conf').exists())
            current.unlink()

            # Replace the selection and edit a published file in place before
            # forcing a later no-replace publication to fail. Rollback must not
            # discard either outside writer's change.
            colors = config / 'hypr/colors-theme.lua'
            def replace_during_publication():
                colors.write_text('outside palette\n')
                current.unlink()
                current.symlink_to(outsider)
                kitty_colors.write_text('outside kitty\n')
            stderr = race_at('                        os.link(new, path)', replace_during_publication, kitty_colors)
            self.assertIn('rollback left changed paths', stderr)
            self.assertEqual(colors.read_text(), 'outside palette\n')
            self.assertEqual(kitty_colors.read_text(), 'outside kitty\n')
            self.assertTrue(current.is_symlink())
            self.assertEqual(current.readlink(), outsider)
            self.assertEqual(outsider_file.read_text(), 'outside content\n')
            recovery, = (config / 'current/.theme-snapshots').glob('.recovery-*')
            record = json.loads((recovery / 'manifest.json').read_text())
            self.assertEqual(record['selection'], str(current))
            self.assertIn('Unresolved theme recovery', prepare(False).stderr)
            # The test owns this synthetic tree; a real user must inspect and
            # recover before removing these preserved records and backups.
            for entry in record['outputs']:
                staging = Path(entry['staging'])
                self.assertTrue(staging.is_relative_to(home) and staging.name.startswith('.theme-recovery-'))
                self.assertFalse(staging.is_symlink())
                shutil.rmtree(staging)
            shutil.rmtree(recovery)
            current.unlink()
            colors.unlink()
            kitty_colors.unlink()
            prepare()
            current = config / 'current/theme'
            colors = config / 'hypr/colors-theme.lua'
            self.assertEqual((current / 'hyprland-palette.conf').read_bytes(), original)
            self.assertEqual(colors.read_bytes(), native_palette(original))
            self.assertEqual(current.resolve().name, 'tokyo-night')
            self.assertFalse(walker.is_symlink())
            self.assertEqual(walker.read_bytes(), (current / 'walker.css').read_bytes())
            self.assertIn(b'.box { padding: 12px; }', walker.read_bytes())
            self.assertEqual(named_tokyo.read_bytes(), named_tokyo_original)
            self.assertEqual(walker_layout.read_text(), 'personal layout\n')
            waybar = config / 'waybar/colors-theme.css'
            self.assertEqual(waybar.read_bytes(), (config / 'dragon/theme-inputs/tokyo-night/waybar.css').read_bytes())
            self.assertIn(b'#cdd6f4', waybar.read_bytes())
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
            unreadable_marker = snapshots / '.recovery-unreadable-fixture'
            unreadable_marker.mkdir()
            (unreadable_marker / 'personal').write_text('preserve marker\n')
            snapshot_mode = snapshots.stat().st_mode & 0o777
            before_palette, before_kitty = colors.read_bytes(), kitty_colors.read_bytes()
            snapshots.chmod(0o300)
            try:
                result = prepare(False)
                self.assertIn('Permission denied', result.stderr)
                self.assertEqual(current.readlink(), initial)
                self.assertEqual(colors.read_bytes(), before_palette)
                self.assertEqual(kitty_colors.read_bytes(), before_kitty)
            finally:
                snapshots.chmod(snapshot_mode)
            self.assertEqual((unreadable_marker / 'personal').read_text(), 'preserve marker\n')
            (unreadable_marker / 'personal').unlink()
            unreadable_marker.rmdir()
            generations = set(snapshots.iterdir())
            prepare()
            self.assertEqual(current.readlink(), initial)
            self.assertEqual(set(snapshots.iterdir()), generations)
            # Generated current CSS is refreshed, without modifying named
            # personal inputs, unrelated layout or an obsolete digest record.
            walker.unlink()
            walker.write_bytes(b'/* personal Walker customization */\n')
            walker_digest = config / 'current/.published-walker'
            walker_digest.write_text('personal digest\n')
            prepare()
            self.assertEqual(walker.read_bytes(), (current / 'walker.css').read_bytes())
            self.assertEqual(named_tokyo.read_bytes(), named_tokyo_original)
            self.assertEqual(walker_digest.read_text(), 'personal digest\n')
            self.assertEqual(current.readlink(), initial)
            walker.unlink()
            walker.symlink_to('../tokyo-night/style.css')
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
            self.assertEqual(colors.read_bytes(), native_palette(updated))
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
            self.assertEqual(colors.read_bytes(), native_palette(custom_palette))
            self.assertIn(b'@define-color background #112233;', waybar.read_bytes())
            self.assertEqual(walker.read_bytes(), (current / 'walker.css').read_bytes())
            self.assertEqual(named_tokyo.read_bytes(), named_tokyo_original)
            self.assertEqual(walker_digest.read_text(), 'personal digest\n')
            self.assertTrue((custom_generation / 'waybar.css').is_file())
            self.assertFalse((custom_generation.parent / 'input/waybar.css').exists())
            self.assertEqual({path: path.read_bytes() for path in sentinel}, sentinel)
            # Old generations may carry shipped COLORS-ONLY SwayNC assets, not
            # complete generated stylesheets. No retained structural base exists.
            legacy = snapshots / '.pre-btop-fixture'
            shutil.copytree(custom_generation.parent, legacy)
            custom_generation = legacy / custom_generation.name
            (custom_generation / 'btop.theme').unlink()
            (custom_generation / 'waybar.css').unlink()
            (legacy / 'style-base.css').unlink()
            (custom_generation / 'swaync.css').write_bytes(b'@define-color background #ffffff;\n')
            current.unlink()
            current.symlink_to(custom_generation)
            retained = {p: (p.stat().st_mode, p.read_bytes()) for p in legacy.rglob('*') if p.is_file()}
            # Real installed selection/rendering and exact-generation undo, with
            # no source checkout and no writes into immutable installed assets.
            static = {p: p.read_bytes() for p in (config / 'dragon').rglob('*') if p.is_file()}
            static[base] = base_original
            static[waybar_style] = waybar_style_original
            prepare(command='theme-set', args=('--no-gui', 'nord'))
            nord = current.readlink()
            self.assertEqual(nord.name, 'nord')
            self.assertFalse(colors.is_symlink())
            for destination, relative in (('kitty/colors.conf', 'kitty.conf'),
                                          ('gtk-3.0/gtk.css', 'gtk-3.0/gtk.css'),
                                          ('gtk-4.0/gtk.css', 'gtk-4.0/gtk.css'),
                                          ('btop/themes/current.theme', 'btop.theme'),
                                          ('swaync/style.css', 'swaync.css'),
                                          ('waybar/colors-theme.css', 'waybar.css')):
                self.assertEqual((config / destination).read_bytes(), (current / relative).read_bytes())
                self.assertFalse((config / destination).is_symlink())
            # A failed undo must retain a unique previous output if another
            # writer changes the published file before rollback under umask 0400.
            kitty_original, kitty_mode = kitty_colors.read_bytes(), kitty_colors.stat().st_mode & 0o777
            kitty_colors.write_bytes(b'unique pre-publication colors\n')
            kitty_colors.chmod(0o640)
            gtk = config / 'gtk-3.0/gtk.css'
            gtk_saved = home / 'fixture-saved-gtk.css'
            old_palette = colors.read_bytes()
            old_gtk = gtk.read_bytes()
            def prevent_recovery_manifest():
                pending_recovery, = snapshots.glob('.recovery-*')
                (pending_recovery / 'manifest.json').mkdir()
            manifest_line = next(line for line in lines if line.strip().startswith('manifest_path.write_text('))
            stderr = race_at(manifest_line, prevent_recovery_manifest, args=('undo',), restrictive_umask=True)
            self.assertIn('Is a directory', stderr)
            self.assertEqual(kitty_colors.read_bytes(), b'unique pre-publication colors\n')
            self.assertEqual(kitty_colors.stat().st_mode & 0o777, 0o640)
            self.assertEqual(gtk.read_bytes(), old_gtk)
            self.assertEqual(current.readlink(), nord)
            self.assertFalse(list(snapshots.glob('.recovery-*')))
            def block_later_output():
                self.assertTrue(kitty_colors.stat().st_mode & 0o400)
                self.assertFalse(kitty_colors.stat().st_mode & 0o022)
                gtk.rename(gtk_saved)
                gtk.mkdir()
            stderr = race_at('                        os.replace(new, path)', block_later_output,
                             gtk, args=('undo',), restrictive_umask=True)
            self.assertIn('Is a directory', stderr)
            self.assertNotIn('recovery retained', stderr)
            self.assertEqual(kitty_colors.read_bytes(), b'unique pre-publication colors\n')
            self.assertEqual(kitty_colors.stat().st_mode & 0o777, 0o640)
            self.assertEqual(colors.read_bytes(), old_palette)
            self.assertEqual(current.readlink(), nord)
            self.assertFalse(list(snapshots.glob('.recovery-*')))
            gtk.rmdir()
            gtk_saved.rename(gtk)

            # A denied rollback must preserve the prior bytes rather than
            # deleting the only backup with the temporary staging directory.
            kitty_parent_mode = kitty_colors.parent.stat().st_mode & 0o777
            def deny_restore():
                gtk.rename(gtk_saved)
                gtk.mkdir()
                kitty_colors.parent.chmod(0o555)
            stderr = race_at('                        os.replace(new, path)', deny_restore,
                             gtk, args=('undo',), restrictive_umask=True)
            self.assertIn('Is a directory', stderr)
            self.assertIn('recovery manifest:', stderr)
            recovery, = snapshots.glob('.recovery-*')
            denied_record = json.loads((recovery / 'manifest.json').read_text())
            self.assertEqual(denied_record['status'], 'rollback-incomplete')
            denied_entry, = [item for item in denied_record['outputs'] if item['destination'] == str(kitty_colors)]
            denied_backup = Path(denied_entry['backup'])
            self.assertEqual(denied_backup.read_bytes(), b'unique pre-publication colors\n')
            self.assertEqual(denied_backup.stat().st_mode & 0o777, 0o640)
            self.assertEqual(current.readlink(), nord)
            self.assertIn('Unresolved theme recovery', prepare(False).stderr)
            kitty_colors.parent.chmod(kitty_parent_mode)
            os.replace(denied_backup, kitty_colors)
            gtk.rmdir()
            gtk_saved.rename(gtk)
            for item in denied_record['outputs']:
                staging = Path(item['staging'])
                self.assertTrue(staging.is_relative_to(home) and staging.name.startswith('.theme-recovery-'))
                shutil.rmtree(staging)
            shutil.rmtree(recovery)
            prior_kitty_inode = kitty_colors.stat().st_ino
            def fail_restrictive_undo():
                self.assertTrue(kitty_colors.stat().st_mode & 0o400)
                self.assertFalse(kitty_colors.stat().st_mode & 0o022)
                kitty_colors.write_bytes(b'outside writer colors\n')
                gtk.rename(gtk_saved)
                gtk.mkdir()
            stderr = race_at('                        os.replace(new, path)', fail_restrictive_undo,
                             gtk, args=('undo',), restrictive_umask=True)
            self.assertIn('Is a directory', stderr)
            self.assertIn('recovery manifest:', stderr)
            self.assertEqual(kitty_colors.read_bytes(), b'outside writer colors\n')
            self.assertEqual(colors.read_bytes(), old_palette)
            self.assertEqual(current.readlink(), nord)
            recovery, = snapshots.glob('.recovery-*')
            self.assertEqual(recovery.stat().st_mode & 0o777, 0o700)
            manifest_file = recovery / 'manifest.json'
            self.assertEqual(manifest_file.stat().st_mode & 0o777, 0o600)
            record = json.loads(manifest_file.read_text())
            self.assertEqual(record['previous_selection'], str(nord))
            entry, = [item for item in record['outputs'] if item['destination'] == str(kitty_colors)]
            backup = Path(entry['backup'])
            self.assertEqual(entry['prior'], 'file')
            self.assertEqual(backup.read_bytes(), b'unique pre-publication colors\n')
            self.assertEqual(backup.stat().st_mode & 0o777, 0o640)
            self.assertEqual(entry['backup_identity']['inode'], backup.stat().st_ino)
            self.assertEqual(entry['previous_identity']['inode'], prior_kitty_inode)
            self.assertEqual(entry['previous_identity']['mode'], 0o640)
            self.assertIn('Unresolved theme recovery', prepare(False).stderr)
            # Explicit fixture-only recovery preserves the outside file rather
            # than allowing the engine to overwrite it automatically.
            kitty_colors.rename(home / 'fixture-outside-kitty')
            os.replace(backup, kitty_colors)
            self.assertEqual((home / 'fixture-outside-kitty').read_bytes(), b'outside writer colors\n')
            gtk.rmdir()
            gtk_saved.rename(gtk)
            for item in record['outputs']:
                staging = Path(item['staging'])
                self.assertTrue(staging.is_relative_to(home) and staging.name.startswith('.theme-recovery-'))
                shutil.rmtree(staging)
            shutil.rmtree(recovery)
            kitty_colors.write_bytes(kitty_original)
            kitty_colors.chmod(kitty_mode)

            # If the commit marker cannot be recorded, publication has already
            # happened but every pre-publication backup must remain intact.
            kitty_colors.write_bytes(b'unique commit-marker backup\n')
            kitty_colors.chmod(0o640)
            marker_root = None
            def deny_commit_marker():
                nonlocal marker_root
                marker_root, = (path for path in snapshots.glob('.recovery-*') if path.is_dir())
                marker_root.chmod(0o500)
            try:
                stderr = race_at("                mark_recovery('committed')", deny_commit_marker,
                                 args=('undo',), restrictive_umask=True)
            finally:
                if marker_root is not None:
                    marker_root.chmod(0o700)
            self.assertIn('Publication completed but committed marker failed', stderr)
            marker_record = json.loads((marker_root / 'manifest.json').read_text())
            self.assertEqual(marker_record['status'], 'prepared')
            self.assertEqual(current.readlink(), custom_generation)
            marker_kitty, = [item for item in marker_record['outputs'] if item['destination'] == str(kitty_colors)]
            self.assertEqual(Path(marker_kitty['backup']).read_bytes(), b'unique commit-marker backup\n')
            self.assertEqual(Path(marker_kitty['backup']).stat().st_mode & 0o777, 0o640)
            for item in marker_record['outputs']:
                if item['backup'] is not None:
                    self.assertTrue(Path(item['backup']).exists() or Path(item['backup']).is_symlink())
            self.assertIn('Unresolved theme recovery', prepare(False).stderr)
            for item in marker_record['outputs']:
                staging = Path(item['staging'])
                self.assertTrue(staging.is_relative_to(home) and staging.name.startswith('.theme-recovery-'))
                shutil.rmtree(staging)
            shutil.rmtree(marker_root)
            prepare(command='theme-set', args=('nord',))
            nord = current.readlink()

            # A failed cleanup-state marker must not start deleting backups.
            before_cleanup_marker = kitty_colors.read_bytes()
            marker_root = None
            try:
                stderr = race_at("                mark_recovery(state + '-cleanup')", deny_commit_marker,
                                 args=('undo',), restrictive_umask=True)
            finally:
                if marker_root is not None:
                    marker_root.chmod(0o700)
            self.assertIn('committed; cleanup not started; preserve all backups', stderr)
            marker_record = json.loads((marker_root / 'manifest.json').read_text())
            self.assertEqual(marker_record['status'], 'committed')
            self.assertEqual(current.readlink(), custom_generation)
            marker_kitty, = [item for item in marker_record['outputs'] if item['destination'] == str(kitty_colors)]
            self.assertEqual(Path(marker_kitty['backup']).read_bytes(), before_cleanup_marker)
            for item in marker_record['outputs']:
                if item['backup'] is not None:
                    self.assertTrue(Path(item['backup']).exists() or Path(item['backup']).is_symlink())
            self.assertIn('Unresolved theme recovery', prepare(False).stderr)
            for item in marker_record['outputs']:
                staging = Path(item['staging'])
                self.assertTrue(staging.is_relative_to(home) and staging.name.startswith('.theme-recovery-'))
                shutil.rmtree(staging)
            shutil.rmtree(marker_root)
            prepare(command='theme-set', args=('nord',))
            nord = current.readlink()

            # After a committed publication, fail cleanup after one staging
            # directory has already gone; the status record must survive.
            parent_modes = {}
            cleanup_record = None
            cleanup_root = None
            def deny_partial_cleanup():
                nonlocal cleanup_record, cleanup_root
                cleanup_root, = (path for path in snapshots.glob('.recovery-*') if path.is_dir())
                cleanup_record = json.loads((cleanup_root / 'manifest.json').read_text())
                self.assertEqual(cleanup_record['status'], 'committed-cleanup')
                staging_dirs = [Path(item['staging']) for item in cleanup_record['outputs']]
                self.assertTrue(any(not path.exists() for path in staging_dirs))
                self.assertTrue(any(path.exists() for path in staging_dirs))
                for staging in staging_dirs:
                    if staging.exists() and staging.parent not in parent_modes:
                        parent_modes[staging.parent] = staging.parent.stat().st_mode & 0o777
                        staging.parent.chmod(0o555)
            try:
                stderr = race_at('                shutil.rmtree(recovery_dir)', deny_partial_cleanup,
                                 args=('undo',), restrictive_umask=True, hit=2)
            finally:
                for parent, old_mode in parent_modes.items():
                    parent.chmod(old_mode)
            self.assertIn('committed; cleanup incomplete', stderr)
            self.assertIn('some staging directories may already be removed', stderr)
            marker = snapshots / (cleanup_root.name + '.cleanup')
            self.assertEqual(json.loads(marker.read_text())['status'], 'committed-cleanup')
            self.assertEqual(current.readlink(), custom_generation)
            self.assertEqual(kitty_colors.read_bytes(), (current / 'kitty.conf').read_bytes())
            self.assertTrue(any(item['backup'] is not None and not Path(item['backup']).exists()
                                and not Path(item['backup']).is_symlink() for item in cleanup_record['outputs']))
            self.assertIn('Unresolved theme recovery', prepare(False).stderr)
            for item in cleanup_record['outputs']:
                staging = Path(item['staging'])
                self.assertTrue(staging.is_relative_to(home) and staging.name.startswith('.theme-recovery-'))
                if staging.exists():
                    shutil.rmtree(staging)
            shutil.rmtree(cleanup_root)
            marker.unlink()
            prepare(command='theme-set', args=('nord',))
            nord = current.readlink()

            # Even if the manifest directory is already removed, failure to
            # remove the final linked status record must keep the gate closed.
            snapshot_mode = snapshots.stat().st_mode & 0o777
            def deny_last_marker_removal():
                remaining, = snapshots.glob('.recovery-*')
                self.assertTrue(remaining.is_file())
                self.assertEqual(json.loads(remaining.read_text())['status'], 'committed-cleanup')
                snapshots.chmod(0o555)
            try:
                stderr = race_at('                marker.unlink()', deny_last_marker_removal,
                                 args=('undo',), restrictive_umask=True)
            finally:
                snapshots.chmod(snapshot_mode)
            self.assertIn('committed; cleanup incomplete', stderr)
            marker, = snapshots.glob('.recovery-*')
            self.assertTrue(marker.is_file())
            self.assertEqual(json.loads(marker.read_text())['status'], 'committed-cleanup')
            self.assertEqual(current.readlink(), custom_generation)
            self.assertIn('Unresolved theme recovery', prepare(False).stderr)
            marker.unlink()
            prepare(command='theme-set', args=('nord',))
            nord = current.readlink()
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
                config / 'gtk-4.0/gtk.css', btop, btop_preferences, swaync, waybar, walker,
                config / 'current/.published-palette',
                config / 'current/.swaync-base-source', *history.iterdir())}
            renderer = renderer_target / 'generate-gtk-themes'
            renderer.rename(renderer.with_suffix('.unavailable'))
            prepare(False, command='theme-set', args=('gruvbox',))
            self.assertEqual(current.readlink(), nord)
            self.assertEqual((history / 'recent-themes').read_bytes(), recent)
            self.assertEqual({path: path.read_bytes() for path in usable}, usable)
            renderer.with_suffix('.unavailable').rename(renderer)
            rejected_waybar = config / 'dragon/theme-inputs/gruvbox/waybar.css'
            original_waybar = rejected_waybar.read_bytes()
            rejected_waybar.write_text('@define-color background #112233;\n')
            prepare(False, command='theme-set', args=('gruvbox',))
            self.assertEqual(current.readlink(), nord)
            self.assertEqual({path: path.read_bytes() for path in usable}, usable)
            rejected_waybar.write_bytes(original_waybar)
            rejected_walker = walker_themes / 'gruvbox/style.css'
            original_walker = rejected_walker.read_bytes()
            rejected_walker.write_bytes(b'@import "personal.css";\n')
            prepare()
            self.assertEqual(rejected_walker.read_bytes(), b'@import "personal.css";\n')
            self.assertEqual(current.readlink(), nord)
            self.assertEqual({path: path.read_bytes() for path in usable}, usable)
            rejected_walker.write_bytes(original_walker)
            private_style = home / 'private-style.css'
            private_style.write_text('.box { color: #123456; }\n')
            rejected_walker.unlink()
            rejected_walker.symlink_to(private_style)
            prepare()
            self.assertEqual(private_style.read_text(), '.box { color: #123456; }\n')
            self.assertEqual(rejected_walker.readlink(), private_style)
            self.assertEqual(current.readlink(), nord)
            self.assertEqual({path: path.read_bytes() for path in usable}, usable)
            rejected_walker.unlink()
            rejected_walker.write_bytes(original_walker)
            # A personal redirected current directory remains untouched.
            saved_walker = walker_themes / 'saved-current'
            walker.parent.rename(saved_walker)
            redirected = home / 'personal-walker'
            redirected.mkdir()
            (redirected / 'style.css').write_text('personal style\n')
            walker.parent.symlink_to(redirected, target_is_directory=True)
            prepare(False)
            self.assertEqual((redirected / 'style.css').read_text(), 'personal style\n')
            self.assertEqual(current.readlink(), nord)
            walker.parent.unlink()
            saved_walker.rename(walker.parent)
            self.assertEqual({path: path.read_bytes() for path in usable}, usable)
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
            self.assertIn(b'@define-color background #112233;', waybar.read_bytes())
            self.assertIn(b'@define-color window_bg_color #112233;', walker.read_bytes())
            self.assertEqual(named_tokyo.read_bytes(), named_tokyo_original)
            self.assertEqual(walker_digest.read_text(), 'personal digest\n')
            self.assertFalse((custom_generation / 'waybar.css').exists())
            self.assertIn(b'@define-color noti-bg rgba(17, 34, 51, 0.9);', swaync.read_bytes())
            self.assertTrue(swaync.read_bytes().endswith(base_original))
            self.assertTrue((config / 'current/.swaync-base-source').read_text().startswith(str(base) + '\n'))
            self.assertEqual(colors.read_bytes(),
                             native_palette((custom_generation / 'hyprland-palette.conf').read_bytes()))
            for destination, relative in (('kitty/colors.conf', 'kitty.conf'),
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
            self.assertEqual(waybar.read_bytes(), (nord / 'waybar.css').read_bytes())
            self.assertEqual(walker.read_bytes(), (nord / 'walker.css').read_bytes())
            self.assertEqual(named_tokyo.read_bytes(), named_tokyo_original)
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
            self.assertEqual(walker_layout.read_text(), 'personal layout\n')
            self.assertEqual(named_tokyo.read_bytes(), named_tokyo_original)
            self.assertEqual({p: p.read_bytes() for p in static}, static)
            previous = current.readlink()
            (custom / 'hyprland-palette.conf').write_text('invalid palette\n')
            prepare(False)
            self.assertEqual(current.readlink(), previous)
            self.assertEqual(colors.read_bytes(), native_palette(custom_palette))
            self.assertEqual(preferences.read_text(), 'WALLPAPER_BACKEND=swaybg\n# personal\n')
            self.assertEqual(gui.read_text(), '[Settings]\ngtk-theme-name=Personal\n')
            self.assertEqual(os.readlink(config / 'current/background'), '/personal/wallpaper.png')
            self.assertEqual((config / 'dragon/theme-inputs/tokyo-night/hyprland-palette.conf').read_bytes(), updated)
            # Preserve custom source assets independently of the generated
            # release-specific Walker output.
            (custom / 'hyprland-palette.conf').write_bytes(custom_palette)
            custom_css = (b'@import "local.css";\n'
                          b'@define-color custom_bg #123456;\n'
                          b'.box-wrapper { background: @custom_bg; border-radius: 7px; }\n')
            (custom / 'walker.css').write_bytes(custom_css)
            (custom / 'local.css').write_bytes(b'.box { color: #abcdef; }\n')
            prepare()
            custom_with_style = current.readlink()
            self.assertEqual(walker.read_bytes(), (current / 'walker.css').read_bytes())
            self.assertEqual(named_tokyo.read_bytes(), named_tokyo_original)
            self.assertEqual(walker_digest.read_text(), 'personal digest\n')
            self.assertEqual((custom_with_style.parent / 'input/walker.css').read_bytes(), custom_css)
            prepare(command='theme-set', args=('nord',))
            (custom / 'walker.css').write_bytes(b'.box-wrapper { color: #abcdef; }\n')
            prepare(command='theme-undo')
            self.assertEqual(current.readlink(), custom_with_style)
            self.assertEqual(walker.read_bytes(), (custom_with_style / 'walker.css').read_bytes())
            self.assertEqual(named_tokyo.read_bytes(), named_tokyo_original)
            self.assertEqual(walker_digest.read_text(), 'personal digest\n')
            self.assertEqual((custom_with_style.parent / 'input/walker.css').read_bytes(), custom_css)
            self.assertEqual(walker_layout.read_text(), 'personal layout\n')
            # A legacy checkout selection points at its named Walker style.
            # The named file differs from the theme's opaque walker.css.
            checkout_theme = home / 'dotfiles/packages/themes/.config/themes/gruvbox'
            checkout_theme.parent.mkdir(parents=True)
            shutil.copytree(ROOT / 'packages/themes/.config/themes/gruvbox', checkout_theme)
            named_gruvbox = walker_themes / 'gruvbox/style.css'
            named_gruvbox_original = named_gruvbox.read_bytes()
            self.assertNotEqual(named_gruvbox_original, (checkout_theme / 'walker.css').read_bytes())
            current.unlink()
            current.symlink_to(checkout_theme)
            colors.write_bytes(native_palette((checkout_theme / 'hyprland-palette.conf').read_bytes()))
            walker.unlink()
            walker.symlink_to('../gruvbox/style.css')
            saved_history = {p: p.read_bytes() for p in history.iterdir()}
            prepare()
            captured = current.readlink()
            self.assertEqual((captured.parent / 'source').read_text(), str(checkout_theme))
            self.assertFalse(walker.is_symlink())
            self.assertEqual(walker.read_bytes(), (captured / 'walker.css').read_bytes())
            self.assertEqual(named_gruvbox.read_bytes(), named_gruvbox_original)
            self.assertEqual(walker_digest.read_text(), 'personal digest\n')
            self.assertEqual({p: p.read_bytes() for p in history.iterdir()}, saved_history)
            generations = set(snapshots.iterdir())
            prepare()
            self.assertEqual(current.readlink(), captured)
            self.assertEqual(set(snapshots.iterdir()), generations)
            self.assertFalse(walker.is_symlink())
            self.assertEqual(walker.read_bytes(), (captured / 'walker.css').read_bytes())
            self.assertEqual(walker_digest.read_text(), 'personal digest\n')
            # An obsolete digest link is not followed, read, removed or replaced.
            digest_target = home / 'personal-digest'
            digest_target.write_text('private digest data\n')
            walker_digest.unlink()
            walker_digest.symlink_to(digest_target)
            prepare()
            self.assertEqual(walker_digest.readlink(), digest_target)
            self.assertEqual(digest_target.read_text(), 'private digest data\n')
            self.assertFalse(walker.is_symlink())
            self.assertEqual(walker.read_bytes(), (captured / 'walker.css').read_bytes())

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
                        self.assertEqual((source / 'dot_config/hypr/hyprland.lua').exists(), desktop)
                        self.assertFalse((source / 'dot_config/hypr/hyprland.conf').exists())
                        self.assertEqual((source / 'dot_config/autostart').exists(), desktop)
                        for helper in ('walker-clipboard', 'clipse-wrapper', 'keyboard-layout', 'disk-usage', 'thermals'):
                            self.assertEqual((source / ('dot_local/bin/executable_' + helper)).exists(), desktop)
                        self.assertEqual((source / 'dot_config/hypr/personal.conf').read_text(), 'personal monitors\n')
                        self.assertEqual((source / 'dot_personal').read_text(), 'unowned\n')
                        self.assertTrue((source / 'dot_zshrc').is_file())
                        self.assertTrue((source / 'dot_gitconfig').is_file())
                        self.assertTrue((source / 'dot_local/bin/executable_dragon-git-pager').is_file())
                        self.assertFalse((source / 'dot_config/omalauncher').exists())
                        outputs.append({str(p.relative_to(source)): (p.stat().st_mode & 0o7777,
                                        p.read_bytes() if p.is_file() else None) for p in source.rglob('*')})
                    self.assertEqual(*outputs)

    def test_shell_startup_preserves_forwarded_ssh_agent(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            home, config, runtime = root / 'home', root / 'home/.config', root / 'runtime'
            env = {'HOME': str(home), 'XDG_CONFIG_HOME': str(config),
                   'XDG_DATA_HOME': str(root / 'data'), 'XDG_STATE_HOME': str(root / 'state'),
                   'XDG_CACHE_HOME': str(root / 'cache'), 'XDG_RUNTIME_DIR': str(runtime),
                   'TMPDIR': str(root / 'tmp'), 'PATH': '/usr/bin:/bin', 'LC_ALL': 'C.UTF-8'}
            for key in ('HOME', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME',
                        'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR', 'TMPDIR'):
                Path(env[key]).mkdir(parents=True, exist_ok=True)
            bundle, archive, extracted = root / 'bundle', root / 'bundle.tar', root / 'extracted'
            with patch.dict(os.environ, env, clear=True):
                remote_sync.build_bundle(ROOT, bundle, 'opencode-runtime')
            remote_sync.create_archive(bundle, archive)
            extracted.mkdir()
            subprocess.run(['/usr/bin/tar', '-xf', str(archive), '-C', str(extracted)],
                           check=True, cwd=root, env=env)
            source = root / 'source'
            subprocess.run(['/bin/bash', str(extracted / 'infra/chezmoi/bin/chezmoi-sync'),
                            '--host', 'opencode-runtime', '--source-dir', str(source)],
                           check=True, cwd=root, env=env, capture_output=True)
            shutil.copy2(source / 'dot_zshrc', home / '.zshrc')
            shutil.copy2(source / 'dot_zshenv', home / '.zshenv')
            fakebin = root / 'bin'
            fakebin.mkdir()
            git = fakebin / 'git'
            git.write_text('#!/bin/sh\nprintf called > "$GIT_CALLED"\nexit 1\n')
            git.chmod(0o755)
            called = root / 'git-called'
            clean_env = dict(env, PATH=str(fakebin) + ':/usr/bin:/bin', GIT_CALLED=str(called))
            clean = subprocess.run(['/usr/bin/zsh', '-ic', 'print -r -- clean-start'],
                                   check=True, cwd=root, env=clean_env, capture_output=True, text=True, timeout=10)
            self.assertEqual(clean.stdout.strip(), 'clean-start')
            self.assertNotIn('.cargo/env', clean.stderr)
            self.assertFalse(called.exists())
            self.assertFalse((root / 'data/zinit').exists())
            (home / '.cargo').mkdir()
            (home / '.cargo/env').write_text('export DRAGON_TEST_CARGO=present\n')
            cargo = subprocess.run(['/usr/bin/zsh', '-c', 'print -r -- "$DRAGON_TEST_CARGO"'],
                                   check=True, cwd=root, env=clean_env, capture_output=True, text=True, timeout=10)
            self.assertEqual(cargo.stdout.strip(), 'present')
            (config / 'zsh').mkdir()
            shutil.copy2(source / 'dot_config/zsh/profile.zsh', config / 'zsh/profile.zsh')
            # Avoid the existing interactive bootstrap; no git/network call.
            (root / 'data/zinit/zinit.git').mkdir(parents=True)
            (runtime / 'gcr').mkdir()
            gcr = runtime / 'gcr/ssh'
            agent = socket.socket(socket.AF_UNIX)
            forwarded_agent = socket.socket(socket.AF_UNIX)
            try:
                agent.bind(str(gcr))
                forwarded = str(runtime / 'ssh-forwarded')
                forwarded_agent.bind(forwarded)

                def startup(value):
                    shell_env = dict(env)
                    if value is not None:
                        shell_env['SSH_AUTH_SOCK'] = value
                    result = subprocess.run(['/usr/bin/zsh', '-ic', 'print -r -- "${SSH_AUTH_SOCK-<unset>}"'],
                                            check=True, cwd=root, env=shell_env,
                                            capture_output=True, text=True, timeout=10)
                    return result.stdout.strip()

                self.assertEqual(startup(forwarded), forwarded)
                self.assertEqual(startup(None), str(gcr))
                self.assertEqual(startup(''), '')
                self.assertEqual(startup('${XDG_RUNTIME_DIR}/gcr/ssh'), str(gcr))
                gcr.unlink()
                self.assertEqual(startup(None), '<unset>')
                self.assertEqual(startup('/run/user/$UID/gcr/ssh'), '/run/user/$UID/gcr/ssh')
            finally:
                agent.close()
                forwarded_agent.close()

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
                'hypr/colors-theme.lua': '-- generated colors\n',
                'hypr/local/keyboard.lua': '-- personal keyboard\n',
                'hypr/local/monitor.lua': '-- personal monitors\n',
                'hypr/local/user.lua': '-- personal bindings\n',
                'hypr/local/host.lua': '-- personal host\n',
                'hypr/monitor-runtime.lua': '-- generated monitors\n',
                'walker/themes/current/style.css': None,
                'walker/themes/current/layout.toml': None,
                'walker/themes/current/personal.xml': 'personal layout\n',
            }
            hyprland = repo / 'packages/hyprland/.config'
            for name, content in runtime.items():
                path = hyprland / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if content is None:
                    path.symlink_to('../nord/' + path.name)
                else:
                    path.write_text(content)
            base = hyprland / 'hypr/defaults/monitor.lua'
            base.write_bytes((ROOT / 'packages/hyprland/.config/hypr/defaults/monitor.lua').read_bytes())
            (repo / 'packages/zsh/.config/zsh/autosuggest-theme.zsh').write_text('generated shell colors\n')
            bundle = root / 'bundle'
            remote_sync.build_bundle(repo, bundle, 'fixture')
            for checkout in (repo, bundle):
                source = root / (checkout.name + '-source')
                subprocess.run(['bash', str(checkout / 'infra/chezmoi/bin/chezmoi-sync'),
                                '--host', 'fixture', '--source-dir', str(source)],
                               check=True, capture_output=True, text=True)
                self.assertEqual((source / 'dot_config/hypr/defaults/monitor.lua').read_bytes(),
                                 base.read_bytes())
                self.assertFalse((source / 'dot_config/walker/themes/current').exists())
                for name in (*runtime, 'zsh/autosuggest-theme.zsh'):
                    path = source / 'dot_config' / name
                    self.assertFalse(path.exists() or path.is_symlink(), name)
            for name in runtime:
                self.assertFalse((bundle / 'packages/hyprland/.config' / name).is_symlink())
                self.assertFalse((bundle / 'packages/hyprland/.config' / name).exists())
            self.assertFalse((bundle / 'packages/hyprland/.config/walker/themes/current').exists())

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
                host_guard, guard = play["pre_tasks"]
                self.assertEqual(host_guard["ansible.builtin.assert"]["that"],
                                 ['ansible_play_hosts_all == ["fixture"]'])
                guard_args = guard["ansible.builtin.command"]["argv"]
                self.assertEqual(guard_args[:2], ["python3", "-c"])
                self.assertEqual(guard_args[3:], ["remoteuser"])
                for uid in (0, 1000, 1001):
                    with patch.object(os, "geteuid", return_value=uid), \
                            patch('pwd.getpwnam', return_value=SimpleNamespace(pw_uid=1000)), \
                            patch.object(sys, 'argv', ['-c', 'remoteuser']):
                        with self.assertRaises(SystemExit) as guarded:
                            exec(guard_args[2], {})
                    self.assertEqual(guarded.exception.code, uid != 1000)
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

    def test_remote_recovery_works_without_desired_payload(self):
        # Real install/tuple/bundle/engine, with only Ansible's SSH transport
        # replaced by a fixture-local executor. No actual remote or apply.
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo, home = root / 'controller', root / 'target-home'
            for name in ('install', 'scripts/lib/remote-sync.py', 'scripts/lib/target-tuple.py',
                         'scripts/lib/logging.sh', 'scripts/lib/manifest-toml.sh'):
                target = repo / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / name, target)
            shutil.copytree(ROOT / 'infra/chezmoi/bin', repo / 'infra/chezmoi/bin')
            shutil.copytree(ROOT / 'infra/chezmoi/lib', repo / 'infra/chezmoi/lib',
                            ignore=shutil.ignore_patterns('__pycache__'))
            ansible_config = repo / 'infra/ansible/ansible.cfg'
            ansible_config.parent.mkdir(parents=True)
            ansible_config.write_text('[defaults]\nretry_files_enabled = False\n')
            manifests = repo / 'infra/chezmoi/manifests'
            manifests.mkdir()
            for name in ('git-ssh', 'session-zsh'):
                (manifests / (name + '.manifest')).touch()
            manifest = manifests / 'devtools-core.manifest'
            manifest.write_text('required|packages/fixture/config|dot_config/fixture\n')
            payload = repo / 'packages/fixture/config'
            payload.parent.mkdir(parents=True)
            payload.write_text('original\n')
            source = home / '.local/share/chezmoi'
            source.mkdir(parents=True)
            (source / 'personal').write_text('personal\n')
            inventory = root / 'inventory.json'
            variables = {
                'host_desktop_stack': 'none', 'target_profile': 'remote-host',
                'target_connection': 'ssh', 'platform_connection_mode': 'remote-ssh',
                'target_home': str(home), 'target_source': str(source),
                'platform_local_connection_policy': 'forbidden', 'platform_container_policy': 'forbidden',
                'platform_remote_connection_policy': 'required', 'platform_container_identity': 'not-applicable',
                'platform_controller_home_policy': 'forbidden', 'platform_unsupported_combination_policy': 'reject',
                'platform_generic_family_fallback': 'forbidden',
                'managed_users': [{'name': 'fixtureuser', 'home': str(home), 'chezmoi_source': str(source)}],
            }
            inventory.write_text(json.dumps({'all': {'hosts': {'fixture': variables},
                                                   'children': {'workstations': {'hosts': {'fixture': {}}}}}}))
            fakebin = root / 'bin'
            fakebin.mkdir()
            transport = fakebin / 'ansible-playbook'
            transport.write_text('''#!/usr/bin/python3
import json, os, pathlib, pwd, subprocess, sys, tarfile, tempfile
play, = json.loads(pathlib.Path(sys.argv[3]).read_text())
assert play['hosts'] == 'fixture' and play['become_user'] == 'fixtureuser'
assert play['pre_tasks'][0]['ansible.builtin.assert']['that'] == ['ansible_play_hosts_all == ["fixture"]']
guard = play['pre_tasks'][1]['ansible.builtin.command']['argv']
assert guard[:2] == ['python3', '-c'] and guard[3:] == ['fixtureuser']
if os.geteuid() != 0:
    current = pwd.getpwuid(os.geteuid()).pw_name
    other = next(p.pw_name for p in pwd.getpwall() if p.pw_uid not in (0, os.geteuid()))
    assert subprocess.run(guard[:3] + [current]).returncode == 0
    assert subprocess.run(guard[:3] + [other]).returncode != 0
else:
    assert subprocess.run(guard[:3] + ['root']).returncode != 0
assert sys.argv[4:] == ['--limit', 'fixture', '--connection', 'ssh']
stage, transaction = play['tasks']
extract, check, recover = transaction['block']
archive = extract['ansible.builtin.unarchive']['src']
with tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as temporary:
    root = pathlib.Path(temporary)
    with tarfile.open(archive) as tar:
        files = {m.name for m in tar if m.isfile()}
        assert files == {'infra/chezmoi/bin/chezmoi-sync', 'infra/chezmoi/lib/sync_engine.py',
                         'infra/chezmoi/lib/sync_manifest.py', 'infra/chezmoi/lib/host_selection.py',
                         'infra/chezmoi/host-selection.json', 'scripts/lib/target-tuple.py'}
        tar.extractall(root, filter='data')
    for item in (check, recover):
        argv = [arg.replace('{{ dotfiles_remote_stage.path }}', str(root))
                for arg in item['ansible.builtin.command']['argv']]
        if item is recover:
            assert argv[2:] == ['--recover-only', '--host', 'fixture', '--source-dir', os.environ['TEST_SOURCE']]
        subprocess.run(argv, check=True, env={**os.environ, 'HOME': play['environment']['HOME']})
with open(os.environ['TRANSPORT_CAPTURE'], 'a') as f:
    f.write('recovery only\\n')
''')
            transport.chmod(0o755)
            environment = {'PATH': str(fakebin) + ':/usr/bin:/bin', 'LC_ALL': 'C.UTF-8',
                           'HOME': str(root / 'controller-home'), 'XDG_CONFIG_HOME': str(root / 'config'),
                           'XDG_CACHE_HOME': str(root / 'cache'), 'XDG_DATA_HOME': str(root / 'data'),
                           'XDG_STATE_HOME': str(root / 'state'), 'XDG_RUNTIME_DIR': str(root / 'runtime'),
                           'TMPDIR': str(root / 'tmp'), 'DOTFILES_INVENTORY': str(inventory),
                           'TEST_SOURCE': str(source), 'TRANSPORT_CAPTURE': str(root / 'transport.log')}
            for key in ('HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME',
                        'XDG_STATE_HOME', 'XDG_RUNTIME_DIR', 'TMPDIR'):
                Path(environment[key]).mkdir(parents=True, exist_ok=True)
            bundle = root / 'bundle'
            with patch.dict(os.environ, environment, clear=True):
                remote_sync.build_bundle(repo, bundle, 'fixture', str(inventory))
            archive = root / 'bundle.tar'
            remote_sync.create_archive(bundle, archive)
            extracted = root / 'extracted'
            extracted.mkdir()
            subprocess.run(['/usr/bin/tar', '-xf', str(archive), '-C', str(extracted)], check=True, env=environment)
            sync = ['/bin/bash', str(extracted / 'infra/chezmoi/bin/chezmoi-sync'),
                    '--host', 'fixture', '--source-dir', str(source)]
            subprocess.run(sync, env=environment, cwd=root, check=True, capture_output=True)
            state = Path(str(source) + '.chezmoi-sync-state')
            before = state.read_bytes()
            payload.write_text('new\n')
            interrupted = subprocess.run(sync, env={**environment, 'CHEZMOI_SYNC_FAILPOINT': 'promote:after-park'},
                                         cwd=root, capture_output=True)
            self.assertNotEqual(interrupted.returncode, 0)
            self.assertFalse(source.exists())
            stage = Path(str(source) + '.chezmoi-sync-stage')
            backup = Path(str(source) + '.chezmoi-sync-backup')
            (stage / 'personal-after-interruption').write_text('stage personal\n')
            (backup / 'personal-after-interruption').write_text('backup personal\n')
            interrupted_state = state.read_bytes()

            # A separate, initially absent source reaches finalizing without a
            # backup. This is a real unambiguous interrupted transaction, not
            # a cleanup or bypass of the ambiguous parked transaction.
            fresh_home = root / 'fresh-target-home'
            fresh_home.mkdir()
            fresh = fresh_home / '.local/share/chezmoi'
            fresh_sync = ['/bin/bash', str(extracted / 'infra/chezmoi/bin/chezmoi-sync'),
                          '--host', 'fixture', '--source-dir', str(fresh)]
            interrupted_fresh = subprocess.run(
                fresh_sync, env={**environment, 'CHEZMOI_SYNC_FAILPOINT': 'finalize:before-backup-delete'},
                cwd=root, capture_output=True)
            self.assertNotEqual(interrupted_fresh.returncode, 0)
            fresh_state = Path(str(fresh) + '.chezmoi-sync-state')
            self.assertEqual(fresh_state.read_bytes(),
                             before.replace(b'\0complete\0', b'\0finalizing\0', 1))
            self.assertFalse(Path(str(fresh) + '.chezmoi-sync-stage').exists())
            self.assertFalse(Path(str(fresh) + '.chezmoi-sync-backup').exists())
            (fresh / 'personal').write_text('fresh personal\n')
            payload.unlink()
            with patch.dict(os.environ, environment, clear=True):
                with self.assertRaisesRegex(ValueError, 'Required source missing'):
                    remote_sync.build_bundle(repo, root / 'invalid-bundle', 'fixture', str(inventory))
            manifest.unlink()  # Recovery also must not require a desired manifest.
            command = ['/bin/bash', str(repo / 'install'), '--host', 'fixture', '--user', 'fixtureuser',
                       '--recover-user-source']
            blocked = subprocess.run(command, env=environment, cwd=root, capture_output=True, text=True)
            self.assertNotEqual(blocked.returncode, 0)
            self.assertIn('needs inspection', blocked.stderr)
            self.assertFalse(source.exists())
            self.assertEqual(state.read_bytes(), interrupted_state)
            self.assertEqual((stage / 'dot_config/fixture').read_text(), 'original\n')
            self.assertEqual((stage / 'personal').read_text(), 'personal\n')
            self.assertEqual((stage / 'personal-after-interruption').read_text(), 'stage personal\n')
            self.assertEqual((backup / 'dot_config/fixture').read_text(), 'original\n')
            self.assertEqual((backup / 'personal').read_text(), 'personal\n')
            self.assertEqual((backup / 'personal-after-interruption').read_text(), 'backup personal\n')

            source, state = fresh, fresh_state
            variables['target_home'] = str(fresh_home)
            variables['target_source'] = str(source)
            variables['managed_users'][0]['home'] = str(fresh_home)
            variables['managed_users'][0]['chezmoi_source'] = str(source)
            environment['TEST_SOURCE'] = str(source)
            inventory.write_text(json.dumps({'all': {'hosts': {'fixture': variables},
                                                   'children': {'workstations': {'hosts': {'fixture': {}}}}}}))
            recovered = subprocess.run(command, env=environment, cwd=root, capture_output=True, text=True)
            self.assertEqual(recovered.returncode, 0, recovered.stdout + recovered.stderr)
            self.assertEqual((source / 'dot_config/fixture').read_text(), 'original\n')
            self.assertEqual((source / 'personal').read_text(), 'fresh personal\n')
            self.assertEqual(state.read_bytes(), before)
            self.assertFalse(Path(str(source) + '.chezmoi-sync-stage').exists())
            self.assertFalse(Path(str(source) + '.chezmoi-sync-backup').exists())
            subprocess.run(command, env=environment, cwd=root, check=True, capture_output=True, text=True)
            self.assertEqual(state.read_bytes(), before)
            self.assertEqual((root / 'transport.log').read_text(), 'recovery only\nrecovery only\n')
            unknown_stage = Path(str(source) + '.chezmoi-sync-stage')
            unknown_stage.mkdir()
            (unknown_stage / 'personal').write_text('do not delete\n')
            blocked = subprocess.run(command, env=environment, cwd=root, capture_output=True, text=True)
            self.assertNotEqual(blocked.returncode, 0)
            self.assertEqual((unknown_stage / 'personal').read_text(), 'do not delete\n')
            self.assertEqual(state.read_bytes(), before)
            invalid = subprocess.run(command + ['--home', str(root / 'other')], env=environment, cwd=root,
                                     capture_output=True, text=True)
            self.assertNotEqual(invalid.returncode, 0)
            direct = subprocess.run(['/usr/bin/python3', str(repo / 'scripts/lib/remote-sync.py'), '--recover-only',
                                     '--inventory', str(inventory), '--host', 'fixture', '--user', 'fixtureuser',
                                     '--home', str(root / 'other'), '--source', str(source)],
                                    env=environment, cwd=root, capture_output=True, text=True)
            self.assertNotEqual(direct.returncode, 0)
            mobile = subprocess.run(['/bin/bash', str(extracted / 'infra/chezmoi/bin/chezmoi-sync'),
                                     '--recover-only', '--host', 'poco-x3-pro', '--source-dir', str(source)],
                                    env=environment, cwd=root, capture_output=True, text=True)
            self.assertNotEqual(mobile.returncode, 0)
            self.assertIn('isolated mobile host', mobile.stderr)
            group_vars = subprocess.run(['/usr/bin/ansible-inventory', '-i', str(inventory),
                                         '--host', 'workstations'], env=environment, cwd=root,
                                        capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(group_vars.stdout)['target_home'], str(fresh_home))
            group = subprocess.run([*command[:3], 'workstations', *command[4:]], env=environment, cwd=root,
                                   capture_output=True, text=True)
            self.assertNotEqual(group.returncode, 0)
            self.assertIn('exact inventory host', group.stderr)
            inventory.write_text(json.dumps({'all': {'hosts': {'fixture': variables},
                                                     'children': {'fixture': {'hosts': {'other': variables}}}}}))
            collision = subprocess.run(command, env=environment, cwd=root, capture_output=True, text=True)
            self.assertNotEqual(collision.returncode, 0)
            self.assertIn('exact inventory host', collision.stderr)
            inventory.write_text(json.dumps({'all': {'hosts': {'fixture': variables},
                                                     'children': {'fixture': {}}}}))
            empty_collision = subprocess.run(command, env=environment, cwd=root, capture_output=True, text=True)
            self.assertNotEqual(empty_collision.returncode, 0)
            self.assertIn('exact inventory host', empty_collision.stderr)
            self.assertEqual((root / 'transport.log').read_text(), 'recovery only\nrecovery only\n')

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
            stage = Path(str(source) + ".chezmoi-sync-stage")
            (stage / "personal-after-interruption").write_text("keep stage edit")
            journal = Path(str(source) + ".chezmoi-sync-state")
            interrupted = journal.read_bytes()
            result = subprocess.run(["bash", str(bundle / "infra/chezmoi/bin/chezmoi-sync"),
                                     "--host", "fixture", "--source-dir", str(source)],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("needs inspection", result.stderr)
            self.assertEqual((stage / "personal-after-interruption").read_text(), "keep stage edit")
            self.assertEqual((source / "dot_config/test/new").read_text(), "new")
            self.assertEqual(journal.read_bytes(), interrupted)

            # A separate clean source exercises the parked-backup boundary;
            # do not erase or force through the ambiguous prior transaction.
            source = home / ".local/share/chezmoi-parked"
            source.mkdir(parents=True)
            (source / "neighbor").write_text("keep")
            sync(root / "bundle4")
            self.assertEqual((source / "dot_config/test/new").read_text(), "changed")
            (source / "dot_config/test/unowned").write_text("keep too")
            result = subprocess.run(["bash", str(bundle / "infra/chezmoi/bin/chezmoi-sync"),
                                     "--host", "fixture", "--source-dir", str(source)],
                                    env={**os.environ, "CHEZMOI_SYNC_FAILPOINT": "promote:after-park"},
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            self.assertNotEqual(result.returncode, 0)
            backup = Path(str(source) + ".chezmoi-sync-backup")
            stage = Path(str(source) + ".chezmoi-sync-stage")
            self.assertTrue(backup.is_dir())
            (stage / "personal-after-interruption").write_text("keep staged edit")
            journal = Path(str(source) + ".chezmoi-sync-state")
            interrupted = journal.read_bytes()
            result = subprocess.run(["bash", str(bundle / "infra/chezmoi/bin/chezmoi-sync"),
                                     "--host", "fixture", "--source-dir", str(source)],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("needs inspection", result.stderr)
            self.assertFalse(source.exists())
            self.assertEqual((backup / "neighbor").read_text(), "keep")
            self.assertEqual((backup / "dot_config/test/unowned").read_text(), "keep too")
            self.assertEqual((stage / "personal-after-interruption").read_text(), "keep staged edit")
            self.assertEqual(journal.read_bytes(), interrupted)
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
