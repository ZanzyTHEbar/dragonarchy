#!/bin/bash
# Configure per-user services and user-session app daemons (Walker/Elephant)

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

mkdir -p "$HOME/.config/systemd/user"

# --- Walker theme setup (align with theme-manager expectations) ---
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WALKER_THEMES_ROOT="$HOME/.config/walker/themes"
CURRENT_THEME_LINK="$HOME/.config/current/theme"
ACTIVE_THEME_PATH="$(readlink -f "$CURRENT_THEME_LINK" 2>/dev/null || true)"
ACTIVE_THEME_NAME="default"

mkdir -p "$WALKER_THEMES_ROOT"

if [[ -n "$ACTIVE_THEME_PATH" && -d "$ACTIVE_THEME_PATH" ]]; then
    ACTIVE_THEME_NAME="$(basename "$ACTIVE_THEME_PATH")"
    if [[ -f "$ACTIVE_THEME_PATH/walker.css" ]]; then
        mkdir -p "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME"
        cp "$ACTIVE_THEME_PATH/walker.css" "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/style.css"
        log_success "Copied Walker CSS for theme '$ACTIVE_THEME_NAME'"
    else
        log_warn "Walker CSS not found in $ACTIVE_THEME_PATH; using default theme assets"
        ACTIVE_THEME_NAME="default"
    fi
fi

# Fallback to bundled default if no theme CSS copied
if [[ ! -f "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/style.css" ]]; then
    mkdir -p "$WALKER_THEMES_ROOT/default"
    cp "$DOTFILES_ROOT/vendored/walker/resources/themes/default/style.css" \
    "$WALKER_THEMES_ROOT/default/style.css"
    ACTIVE_THEME_NAME="default"
    log_success "Installed Walker default CSS"
fi

# Optional layout file
if [[ -n "$ACTIVE_THEME_PATH" && -f "$ACTIVE_THEME_PATH/walker.toml" ]]; then
    cp "$ACTIVE_THEME_PATH/walker.toml" "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/layout.toml"
fi

mkdir -p "$WALKER_THEMES_ROOT/current"
ln -snf "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/style.css" "$WALKER_THEMES_ROOT/current/style.css"
if [[ -f "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/layout.toml" ]]; then
    ln -snf "$WALKER_THEMES_ROOT/$ACTIVE_THEME_NAME/layout.toml" "$WALKER_THEMES_ROOT/current/layout.toml"
else
    rm -f "$WALKER_THEMES_ROOT/current/layout.toml"
fi

# Ensure Walker config references the active theme
WALKER_CONFIG="$HOME/.config/walker/config.toml"
if [[ -f "$WALKER_CONFIG" ]]; then
    tmp_cfg=$(mktemp)
    awk -v theme="$ACTIVE_THEME_NAME" '
    BEGIN { updated = 0 }
    /^[[:space:]]*theme[[:space:]]*=/ && !updated {
      printf("theme = \"%s\"\n", theme);
      updated = 1;
      next;
    }
    { print }
    END {
      if (!updated) {
        printf("\ntheme = \"%s\"\n", theme);
      }
    }
    ' "$WALKER_CONFIG" >"$tmp_cfg" && mv "$tmp_cfg" "$WALKER_CONFIG"
    log_success "Walker theme configured to '$ACTIVE_THEME_NAME'"
else
    log_warn "Walker config.toml not found; skipped theme assignment"
fi

# --- Elephant user unit content ---
ELEPHANT_UNIT_PATH="$HOME/.config/systemd/user/elephant.service"
cat > "$ELEPHANT_UNIT_PATH" <<'EOF'
[Unit]
Description=Elephant
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
Environment=XDG_RUNTIME_DIR=%t
Environment="ELEPHANT_RUNPREFIX=uwsm app -- "
Environment=PATH=%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin
ExecStartPre=/usr/bin/systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DESKTOP_SESSION
ExecStartPre=/usr/bin/rm -f /tmp/elephant.sock
ExecStartPre=/usr/bin/bash -lc 'for i in {1..50}; do [ -n "${WAYLAND_DISPLAY}" ] && [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ] && exit 0; sleep 0.2; done; echo "WAYLAND socket not ready"; exit 1'
ExecStart=/usr/bin/elephant
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF
log_success "Wrote $ELEPHANT_UNIT_PATH"

# --- Elephant config: force correct runprefix for app launches ---
ELEPHANT_CFG_DIR="$HOME/.config/elephant"
ELEPHANT_CFG_REAL="$ELEPHANT_CFG_DIR"

if [[ -L "$ELEPHANT_CFG_DIR" ]]; then
    ELEPHANT_CFG_REAL="$(readlink -f "$ELEPHANT_CFG_DIR")"
    log_info "Elephant config symlink detected → $ELEPHANT_CFG_REAL"
fi

mkdir -p "$ELEPHANT_CFG_REAL"
mkdir -p "$ELEPHANT_CFG_REAL/providers"

cat > "$ELEPHANT_CFG_REAL/elephant.toml" <<'EOF'
# Force launcher prefix (overrides autodetect like systemd-run)
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_REAL/elephant.toml (runprefix)"

# Provider-specific overrides (desktop entries and runner)
cat > "$ELEPHANT_CFG_REAL/desktopapplications.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_REAL/desktopapplications.toml (runprefix)"

cat > "$ELEPHANT_CFG_REAL/runner.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_REAL/runner.toml (runprefix)"

# Duplicate provider configs under providers/ (some builds read from providers/*)
cat > "$ELEPHANT_CFG_REAL/providers/desktopapplications.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_REAL/providers/desktopapplications.toml (runprefix)"

cat > "$ELEPHANT_CFG_REAL/providers/runner.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_REAL/providers/runner.toml (runprefix)"

# --- Reload and enable user service ---
systemctl --user daemon-reload
systemctl --user enable --now elephant || log_warn "Failed to start elephant; ensure /usr/bin/elephant exists"

# --- Thermal profile initialization service ---
THERMAL_PROFILE_UNIT="thermal-profile-init.service"
if systemctl --user list-unit-files --no-legend 2>/dev/null | grep -q "^${THERMAL_PROFILE_UNIT}"; then
    if systemctl --user enable --now "${THERMAL_PROFILE_UNIT}" >/dev/null 2>&1; then
        log_success "Thermal profile init service enabled"
    else
        log_warn "Failed to enable thermal-profile-init.service; ensure ~/.local/bin/thermal-profile-init exists"
    fi
else
    log_info "thermal-profile-init.service not present; skipping enablement"
fi

# --- Quick hints ---
log_info "Verify: systemctl --user status elephant"
log_info "If socket busy, ExecStartPre cleans /tmp/elephant.sock"


