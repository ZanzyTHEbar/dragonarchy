#!/bin/bash
# Configure per-user services and user-session app daemons (Walker/Elephant)

set -euo pipefail

# --- Header and Logging ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log_info()  { echo -e "\n${BLUE}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}  $1"; }

# --- Ensure config dirs ---
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
log_ok "Walker theme linked to ~/.config/walker/themes/current/"

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
log_ok "Wrote $ELEPHANT_UNIT_PATH"

# --- Elephant config: force correct runprefix for app launches ---
ELEPHANT_CFG_DIR="$HOME/.config/elephant"
mkdir -p "$ELEPHANT_CFG_DIR"
mkdir -p "$ELEPHANT_CFG_DIR/providers"
cat > "$ELEPHANT_CFG_DIR/elephant.toml" <<'EOF'
# Force launcher prefix (overrides autodetect like systemd-run)
runprefix = "uwsm app -- "
EOF
log_ok "Wrote $ELEPHANT_CFG_DIR/elephant.toml (runprefix)"

# Provider-specific overrides (desktop entries and runner)
cat > "$ELEPHANT_CFG_DIR/desktopapplications.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_ok "Wrote $ELEPHANT_CFG_DIR/desktopapplications.toml (runprefix)"

cat > "$ELEPHANT_CFG_DIR/runner.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_ok "Wrote $ELEPHANT_CFG_DIR/runner.toml (runprefix)"

# Duplicate provider configs under providers/ (some builds read from providers/*)
cat > "$ELEPHANT_CFG_DIR/providers/desktopapplications.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_ok "Wrote $ELEPHANT_CFG_DIR/providers/desktopapplications.toml (runprefix)"

cat > "$ELEPHANT_CFG_DIR/providers/runner.toml" <<'EOF'
runprefix = "uwsm app -- "
EOF
log_ok "Wrote $ELEPHANT_CFG_DIR/providers/runner.toml (runprefix)"

# --- Reload and enable user service ---
systemctl --user daemon-reload
systemctl --user enable --now elephant || log_warn "Failed to start elephant; ensure /usr/bin/elephant exists"

# --- Quick hints ---
log_info "Verify: systemctl --user status elephant"
log_info "If socket busy, ExecStartPre cleans /tmp/elephant.sock"


