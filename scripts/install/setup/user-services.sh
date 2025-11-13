#!/bin/bash
# Configure per-user services and user-session app daemons (Walker/Elephant)

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

mkdir -p "$HOME/.config/systemd/user"
mkdir -p "$HOME/.config/walker/themes/current"

# --- Walker theme wiring (idempotent) ---
if [ -f "$HOME/.config/current/theme/walker.css" ]; then
  ln -snf "$HOME/.config/current/theme/walker.css" "$HOME/.config/walker/themes/current/style.css"
fi
if [ -f "$HOME/.config/current/theme/walker.toml" ]; then
  ln -snf "$HOME/.config/current/theme/walker.toml" "$HOME/.config/walker/themes/current/layout.toml"
else
  [ -f "$HOME/.config/walker/themes/default.toml" ] && ln -snf "$HOME/.config/walker/themes/default.toml" "$HOME/.config/walker/themes/current/layout.toml" || true
fi
log_success "Walker theme linked to ~/.config/walker/themes/current/"

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
mkdir -p "$ELEPHANT_CFG_DIR"
mkdir -p "$ELEPHANT_CFG_DIR/providers"
cat > "$ELEPHANT_CFG_DIR/elephant.toml" <<'EOF'
# Force launcher prefix (overrides autodetect like systemd-run)
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_DIR/elephant.toml (runprefix)"

# Provider-specific overrides (desktop entries and runner)
cat > "$ELEPHANT_CFG_DIR/desktopapplications.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_DIR/desktopapplications.toml (runprefix)"

cat > "$ELEPHANT_CFG_DIR/runner.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_DIR/runner.toml (runprefix)"

# Duplicate provider configs under providers/ (some builds read from providers/*)
cat > "$ELEPHANT_CFG_DIR/providers/desktopapplications.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_DIR/providers/desktopapplications.toml (runprefix)"

cat > "$ELEPHANT_CFG_DIR/providers/runner.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_success "Wrote $ELEPHANT_CFG_DIR/providers/runner.toml (runprefix)"

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


