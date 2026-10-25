"""Dependency-free checks for the shared Wayle theme owner."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[2]
APPLY = ROOT / 'scripts/theme-manager/wayle-theme-apply'
THEMES = ROOT / 'packages/themes/.config/themes'


def luminance(color):
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return sum(c * weight for c, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def apply(palette, config, *, check=True, path=None):
    env = dict(os.environ, XDG_CONFIG_HOME=str(config))
    if path is not None:
        env['PATH'] = str(path) + os.pathsep + env['PATH']
    return subprocess.run([str(APPLY), str(palette)], env=env, text=True,
                          capture_output=True, check=check)


with tempfile.TemporaryDirectory(prefix='wayle-theme-', dir='/tmp/opencode') as tmp:
    work = Path(tmp)
    config = work / 'config'
    dest = config / 'wayle/palette.toml'
    dest.parent.mkdir(parents=True)
    shutil.copy2(ROOT / 'packages/wayle/.config/wayle/config.toml', dest.parent / 'config.toml')
    palettes = sorted(THEMES.glob('*/hyprland-palette.conf'))
    assert palettes, 'no theme palettes found'
    for palette in palettes:
        apply(palette, config)
        data = tomllib.loads(dest.read_text())['styling']['palette']
        source = dict(re.findall(r'^\$(\w+)\s*=\s*rgba\(([0-9a-fA-F]{8})\)', palette.read_text(), re.M))
        for key, name in {'bg': 'background', 'fg': 'foreground', 'fg-muted': 'comment',
                          'primary': 'accent', 'red': 'red', 'yellow': 'yellow',
                          'green': 'green', 'blue': 'blue'}.items():
            assert data[key].lower() == '#' + source[name][:6].lower(), (palette, key)
        assert set(data) == {'bg', 'surface', 'elevated', 'fg', 'fg-muted', 'primary', 'red', 'yellow', 'green', 'blue'}
        assert all(re.fullmatch(r'#[0-9a-fA-F]{6}', value) for value in data.values())
        dark, light = sorted((luminance(data['fg']), luminance(data['surface'])))
        assert (light + 0.05) / (dark + 0.05) >= 4.5, f'{palette}: insufficient widget text contrast'
        before = dest.stat().st_mtime_ns
        apply(palette, config)
        assert dest.stat().st_mtime_ns == before, 'unchanged palettes must not trigger a reload'

    previous = dest.read_bytes()
    original = (THEMES / 'gruvbox/hyprland-palette.conf').read_text()
    invalid = work / 'invalid.conf'
    invalid.write_text('$background = rgba(not-a-color)\n')
    assert apply(invalid, config, check=False).returncode != 0
    assert dest.read_bytes() == previous

    invalid.write_text(original + '\n$accent = rgba(broken)\n')
    assert apply(invalid, config, check=False).returncode != 0
    assert dest.read_bytes() == previous

    invalid.write_text(original + '\n$accent = rgba(ffffffff)\n')
    assert apply(invalid, config, check=False).returncode != 0, 'duplicate colors must be rejected'
    assert dest.read_bytes() == previous

    main_config = dest.parent / 'config.toml'
    managed = main_config.read_text()
    for unmanaged in ('imports = []\n', 'imports = "palette.toml"\n'):
        main_config.write_text(unmanaged)
        assert apply(THEMES / 'gruvbox/hyprland-palette.conf', config, check=False).returncode != 0
        assert dest.read_bytes() == previous
    main_config.write_text(managed)

    dest.unlink()
    target = work / 'user-palette'
    target.write_text('do not overwrite')
    dest.symlink_to(target)
    assert apply(THEMES / 'gruvbox/hyprland-palette.conf', config, check=False).returncode != 0
    assert target.read_text() == 'do not overwrite'
    dest.unlink()

    commands = work / 'commands'
    commands.mkdir()
    calls = work / 'calls'
    mock = commands / 'wayle'
    mock.write_text('#!/usr/bin/env python3\nimport sys\nfrom pathlib import Path\n'
                    f'with Path({str(calls)!r}).open("a") as out: out.write(" ".join(sys.argv[1:]) + "\\n")\n')
    mock.chmod(0o755)
    runtime = config / 'wayle/runtime.toml'
    runtime.write_text('[bar]\nscale = 1.1\n[styling]\ntheme-provider = "wayle"\n'
                       '[styling.palette]\nbg = "#ff00ff"\nprimary = "#00ff00"\n')
    apply(THEMES / 'gruvbox/hyprland-palette.conf', config, path=commands)
    assert set(calls.read_text().splitlines()) == {
        'config reset styling.theme-provider', 'config reset styling.palette.bg',
        'config reset styling.palette.primary'}
    assert '[bar]\nscale = 1.1' in runtime.read_text()

    previous = dest.read_bytes()
    runtime.write_text('[invalid runtime TOML')
    assert apply(THEMES / 'gruvbox/hyprland-palette.conf', config, check=False, path=commands).returncode != 0
    assert dest.read_bytes() == previous, 'invalid runtime input replaced the last good palette'

    shared = tomllib.loads((ROOT / 'packages/wayle/.config/wayle/config.toml').read_text())
    assert shared['imports'] == ['palette.toml']
    assert shared['bar']['padding'] >= 0.25
    assert shared['bar']['button-label-padding'] >= 0.75
    assert shared['bar']['button-variant'] == 'basic'
    assert shared['styling']['theme-provider'] == 'wayle'
    manifest = (ROOT / 'infra/chezmoi/manifests/session-core.manifest').read_text()
    assert 'required|packages/wayle/.config/wayle|dot_config/wayle' in manifest.splitlines()
    for name in ('palette.toml', 'runtime.toml'):
        assert f'exclude||dot_config/wayle/{name}' in manifest.splitlines()

    # A failed Wayle palette preflight must not select the new global theme.
    fixture = work / 'repo'
    manager = fixture / 'scripts/theme-manager'
    manager.mkdir(parents=True)
    for name in ('theme-set', 'wayle-theme-apply'):
        shutil.copy2(ROOT / 'scripts/theme-manager' / name, manager / name)
    bad_theme = fixture / 'packages/themes/.config/themes/bad'
    bad_theme.mkdir(parents=True)
    (bad_theme / 'hyprland-palette.conf').write_text('$background = rgba(broken)\n')
    current = config / 'current/theme'
    current.parent.mkdir(parents=True)
    current.symlink_to(THEMES / 'gruvbox')
    (config / 'wayle/config.toml').write_text('imports = ["palette.toml"]\n')
    home = work / 'home'
    home.mkdir()
    failed = subprocess.run([str(manager / 'theme-set'), '--no-gui', 'bad'],
                            env=dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config),
                                     XDG_STATE_HOME=str(work / 'state')), text=True, capture_output=True)
    assert failed.returncode != 0
    assert 'missing or invalid palette colors' in failed.stderr
    assert current.resolve() == THEMES / 'gruvbox', 'failed palette changed selected theme'

print(f'WAYLE_THEME_TESTS_PASS ({len(palettes)} palettes)')
