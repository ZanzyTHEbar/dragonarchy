#!/usr/bin/env bats

setup() {
  ORIGINAL_PATH="$PATH"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/custom config"
  export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/runtime"
  export WAYLAND_DISPLAY=fixture-wayland
  export MENU_CSS="$BATS_TEST_TMPDIR/menu.css"
  export PATH="$BATS_TEST_TMPDIR/bin"
  unset DRAGON_TUI_ONLY
  /bin/mkdir -p "$PATH" "$HOME"
  /bin/mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME/wlogout"
  printf '[]\n' >"$XDG_CONFIG_HOME/wlogout/layout"
  printf '/* static style */\n' >"$XDG_CONFIG_HOME/wlogout/style.css"
  /bin/ln -s /usr/bin/dirname "$PATH/dirname"
  /bin/ln -s /usr/bin/readlink "$PATH/readlink"
  /bin/cat >"$PATH/gum" <<'EOF'
#!/bin/bash
while read -r line; do :; done
echo Cancel
EOF
  /bin/chmod +x "$PATH/gum"
}

teardown() {
  export PATH="$ORIGINAL_PATH"
}

mock_menu() {
  /bin/cat >"$PATH/$1" <<'EOF'
#!/bin/bash
printf '%s\n' "${0##*/}" "$@"
[[ "$1" != --layout ]] || /bin/cat "$4" >"$MENU_CSS"
exit "${MENU_EXIT:-0}"
EOF
  /bin/chmod +x "$PATH/$1"
}

@test "selects native wlogout even when wleave exists with explicit managed layout and stylesheet" {
  mock_menu wleave
  mock_menu wlogout
  run /usr/bin/python3 "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = wlogout ]
  [ "${lines[1]}" = --layout ]
  [ "${lines[2]}" = "$XDG_CONFIG_HOME/wlogout/layout" ]
  [ "${lines[3]}" = -C ]
  [[ "${lines[4]}" == "$XDG_RUNTIME_DIR"/dragon-power-*.css ]]
  /bin/grep -q 'wlogout/style.css' "$MENU_CSS"
  [ "${lines[5]}" = --buttons-per-row ]
  [ "${lines[6]}" = 3 ]
}

@test "native wlogout failure propagates without launching another menu" {
  mock_menu wlogout
  export MENU_EXIT=23
  run /usr/bin/python3 "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = wlogout ]
  [[ "$output" == *'returned non-zero exit status 23'* ]]
}

@test "TUI-only mode bypasses both graphical menus" {
  mock_menu wleave
  mock_menu wlogout
  export DRAGON_TUI_ONLY=1
  run /usr/bin/python3 "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "missing selected native UI refuses rather than silently using TUI" {
  run /usr/bin/python3 "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 1 ]
  [[ "$output" == *'selected native UI wlogout is missing'* ]]
}

@test "a wleave incumbent is not a fallback for missing selected native UI" {
  mock_menu wleave
  run /usr/bin/python3 "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 1 ]
  [[ "$output" == *'selected native UI wlogout is missing'* ]]
}

@test "hyprlock setup preserves personal paths and snapshots selected palette" {
  export PATH="$ORIGINAL_PATH"
  /bin/mkdir -p "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/current/theme"
  printf 'personal config\n' > "$HOME/personal-lock"
  /bin/ln -s "$HOME/personal-lock" "$XDG_CONFIG_HOME/hypr/hyprlock.conf"
  run /bin/bash "$REPO_ROOT/scripts/theme-manager/hyprlock-setup"
  [ "$status" -eq 0 ]
  [ "$(/bin/cat "$HOME/personal-lock")" = 'personal config' ]
  [ -L "$XDG_CONFIG_HOME/hypr/hyprlock.conf" ]

  /bin/rm "$XDG_CONFIG_HOME/hypr/hyprlock.conf"
  printf '$foreground = rgba(112233ff) # rgba(999999ff)\n$accent = rgba(abcdef88) # rgba(000000ff)\n' > "$XDG_CONFIG_HOME/current/theme/hyprland-palette.conf"
  run /bin/bash "$REPO_ROOT/scripts/theme-manager/hyprlock-setup"
  [ "$status" -eq 0 ]
  /bin/grep -q 'color = rgba(112233ff)' "$XDG_CONFIG_HOME/hypr/hyprlock.conf"
  /bin/grep -q 'check_color = rgba(abcdef88)' "$XDG_CONFIG_HOME/hypr/hyprlock.conf"

  /bin/rm "$XDG_CONFIG_HOME/hypr/hyprlock.conf"
  /usr/bin/mkfifo "$XDG_CONFIG_HOME/hypr/hyprlock.conf"
  run /usr/bin/timeout 5 /bin/bash "$REPO_ROOT/scripts/theme-manager/hyprlock-setup"
  [ "$status" -eq 1 ]
  [ -p "$XDG_CONFIG_HOME/hypr/hyprlock.conf" ]
}

@test "hyprlock setup reports a replaced config directory without touching its new contents" {
  export PATH="$BATS_TEST_TMPDIR/bin:$ORIGINAL_PATH"
  /bin/mkdir -p "$XDG_CONFIG_HOME/hypr"
  /bin/cat > "$BATS_TEST_TMPDIR/bin/ln" <<'EOF'
#!/bin/bash
/bin/mv "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/hypr-moved"
/bin/mkdir "$XDG_CONFIG_HOME/hypr"
printf 'personal replacement\n' > "$XDG_CONFIG_HOME/hypr/hyprlock.conf"
exec /usr/bin/ln "$@"
EOF
  /bin/chmod +x "$BATS_TEST_TMPDIR/bin/ln"
  run /bin/bash "$REPO_ROOT/scripts/theme-manager/hyprlock-setup"
  [ "$status" -eq 1 ]
  [[ "$output" == *'config directory changed'* ]]
  [ "$(/bin/cat "$XDG_CONFIG_HOME/hypr/hyprlock.conf")" = 'personal replacement' ]
  [ -f "$XDG_CONFIG_HOME/hypr-moved/hyprlock.conf" ]
}

@test "shared manifests provision wleave and retain session-safe actions" {
  run /usr/bin/python3 - "$REPO_ROOT" <<'PY'
import json
import sys
import tomllib
from pathlib import Path

root = Path(sys.argv[1])
layout = json.loads((root / "packages/wleave/.config/wleave/layout.json").read_text())
buttons = layout["buttons"]
assert {b["label"]: b["action"] for b in buttons} == {
    "lock": "hyprlock", "hibernate": "systemctl hibernate", "logout": "uwsm stop",
    "shutdown": "systemctl poweroff", "suspend": "systemctl suspend", "reboot": "systemctl reboot",
}
assert len({b["keybind"] for b in buttons}) == len(buttons) == 6
assert all(b["text"] and b["icon"].startswith("/usr/share/wleave/icons/") for b in buttons)
manifest = (root / "infra/chezmoi/manifests/session-shell.manifest").read_text()
assert "required|packages/wleave/.config/wleave|dot_config/wleave" in manifest.splitlines()
deps = tomllib.loads((root / "scripts/install/deps.manifest.toml").read_text())
group = deps["platforms"]["arch"]["paru"]["hyprland_aur"]
assert "hyprland" in group["requires_features"] and "wleave-git" in group["packages"]
keybinds = (root / "packages/hyprland/.config/hypr/lua/bindings.lua").read_text()
assert 'hl.bind("CTRL ALT + DELETE", d.exec_cmd(\'"$HOME/.local/bin/power-menu"\'), { description = "Power menu" })' in keybinds.splitlines()
PY
  [ "$status" -eq 0 ]
}
