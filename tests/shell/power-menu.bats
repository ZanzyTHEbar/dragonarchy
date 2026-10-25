#!/usr/bin/env bats

setup() {
  ORIGINAL_PATH="$PATH"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/custom config"
  export PATH="$BATS_TEST_TMPDIR/bin"
  unset DRAGON_TUI_ONLY
  /bin/mkdir -p "$PATH" "$HOME"
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
exit "${MENU_EXIT:-0}"
EOF
  /bin/chmod +x "$PATH/$1"
}

@test "prefers wleave and explicitly selects the managed layout and stylesheet" {
  mock_menu wleave
  mock_menu wlogout
  run /bin/bash "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = wleave ]
  [ "${lines[1]}" = --layout ]
  [ "${lines[2]}" = "$XDG_CONFIG_HOME/wleave/layout.json" ]
  [ "${lines[3]}" = --css ]
  [ "${lines[4]}" = "$XDG_CONFIG_HOME/wleave/style.css" ]
}

@test "retains wlogout when wleave is not installed" {
  mock_menu wlogout
  run /bin/bash "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 0 ]
  [ "$output" = wlogout ]
}

@test "TUI-only mode bypasses both graphical menus" {
  mock_menu wleave
  mock_menu wlogout
  export DRAGON_TUI_ONLY=1
  run /bin/bash "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "uses the TUI when neither graphical menu is installed" {
  run /bin/bash "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "propagates wleave failures without launching a second menu" {
  mock_menu wleave
  mock_menu wlogout
  export MENU_EXIT=23
  run /bin/bash "$REPO_ROOT/scripts/theme-manager/power-menu"
  [ "$status" -eq 23 ]
  [ "${lines[0]}" = wleave ]
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
keybinds = (root / "packages/hyprland/.config/hypr/config/keybinds.conf").read_text()
assert "bindd = CTRL ALT, DELETE, Open logout/power menu, exec, $HOME/dotfiles/scripts/theme-manager/power-menu" in keybinds.splitlines()
PY
  [ "$status" -eq 0 ]
}
