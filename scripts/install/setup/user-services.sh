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

[Service]
Type=simple
Environment=XDG_RUNTIME_DIR=%t
ExecStartPre=/usr/bin/rm -f /tmp/elephant.sock
ExecStart=/usr/local/bin/elephant
Restart=on-failure
RestartSec=1

[Install]
WantedBy=default.target
EOF
log_ok "Wrote $ELEPHANT_UNIT_PATH"

# --- Reload and enable user service ---
systemctl --user daemon-reload
systemctl --user enable --now elephant || log_warn "Failed to start elephant; ensure /usr/local/bin/elephant exists"

# --- Quick hints ---
log_info "Verify: systemctl --user status elephant"
log_info "If socket busy, ExecStartPre cleans /tmp/elephant.sock"


