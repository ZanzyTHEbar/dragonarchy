#!/bin/bash
#
# Compile and install the seamless-login helper + service.
# Hosts can call this script with their desired session command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LOG_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"
# shellcheck disable=SC1091
source "$LOG_LIB"

SESSION_COMMAND="uwsm start -- hyprland.desktop"
SERVICE_NAME="seamless-login"
SERVICE_DESCRIPTION="Seamless Auto-Login"
SERVICE_USER="$USER"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --user USER                 User account that owns the session (default: $SERVICE_USER)
  --session COMMAND           Command executed after Plymouth (default: "$SESSION_COMMAND")
  --service-name NAME         Systemd service name (default: $SERVICE_NAME)
  --description TEXT          Systemd unit description
  -h, --help                  Show this message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            SERVICE_USER="$2"
            shift 2
            ;;
        --session)
            SESSION_COMMAND="$2"
            shift 2
            ;;
        --service-name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --description)
            SERVICE_DESCRIPTION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$SERVICE_USER" ]]; then
    log_error "--user is required"
    exit 1
fi

log_step "Compiling seamless-login helper"
TMP_BIN="$(mktemp)"
gcc -O2 -o "$TMP_BIN" "$SCRIPT_DIR/seamless-login.c"
sudo mv "$TMP_BIN" /usr/local/bin/seamless-login
sudo chmod +x /usr/local/bin/seamless-login
log_success "Helper installed to /usr/local/bin/seamless-login"

SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
log_step "Installing ${SERVICE_NAME}.service"
sed \
    -e "s|@USER@|$SERVICE_USER|g" \
    -e "s|@SESSION_COMMAND@|$SESSION_COMMAND|g" \
    -e "s|@DESCRIPTION@|$SERVICE_DESCRIPTION|g" \
    "$SCRIPT_DIR/seamless-login.service" | sudo tee "$SERVICE_PATH" >/dev/null

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME".service
sudo systemctl restart "$SERVICE_NAME".service
log_success "${SERVICE_NAME}.service enabled"

# Supporting tweaks for Plymouth hand-off
log_step "Configuring Plymouth wait behavior"
sudo mkdir -p /etc/systemd/system/plymouth-quit.service.d
sudo tee /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf >/dev/null <<'EOF'
[Unit]
After=multi-user.target
EOF
sudo systemctl daemon-reload

log_step "Masking plymouth-quit-wait.service and disabling getty@tty1.service"
sudo systemctl mask plymouth-quit-wait.service >/dev/null 2>&1 || true
sudo systemctl disable getty@tty1.service >/dev/null 2>&1 || true

log_success "Seamless login installation complete. Reboot recommended."

