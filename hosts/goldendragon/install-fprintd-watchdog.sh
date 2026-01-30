#!/usr/bin/env bash
# Install fprintd watchdog system to prevent recurring device claim issues
# This creates a multi-layered defense against stuck fingerprint device claims

set -euo pipefail

NON_INTERACTIVE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    *) echo "Usage: $0 [--non-interactive]" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../scripts/lib/logging.sh"

log_step "Installing fprintd watchdog system..."

# 1. Install system-sleep hook (runs on suspend/resume)
log_info "Installing system-sleep hook..."
if [ -f "${SCRIPT_DIR}/etc/systemd/system-sleep/99-fprintd-reset.sh" ]; then
  sudo cp "${SCRIPT_DIR}/etc/systemd/system-sleep/99-fprintd-reset.sh" /usr/lib/systemd/system-sleep/
  sudo chmod +x /usr/lib/systemd/system-sleep/99-fprintd-reset.sh
  log_success "Installed: /usr/lib/systemd/system-sleep/99-fprintd-reset.sh"
else
  log_error "Sleep hook not found: ${SCRIPT_DIR}/etc/systemd/system-sleep/99-fprintd-reset.sh"
  exit 1
fi

# 2. Install watchdog binary
log_info "Installing fprintd-watchdog..."
SOURCE_WATCHDOG="${SCRIPT_DIR}/../../packages/hardware/.local/bin/fprintd-watchdog"
DEST_WATCHDOG="$HOME/.local/bin/fprintd-watchdog"

if [ -f "$SOURCE_WATCHDOG" ]; then
  mkdir -p ~/.local/bin
  
  # Check if already installed (same file or symlink)
  if [ -f "$DEST_WATCHDOG" ]; then
    SOURCE_REAL=$(realpath "$SOURCE_WATCHDOG")
    DEST_REAL=$(realpath "$DEST_WATCHDOG" 2>/dev/null || echo "$DEST_WATCHDOG")
    
    if [ "$SOURCE_REAL" = "$DEST_REAL" ]; then
      log_info "fprintd-watchdog already installed (same file)"
    else
      log_info "Updating existing fprintd-watchdog..."
      cp "$SOURCE_WATCHDOG" "$DEST_WATCHDOG"
      chmod +x "$DEST_WATCHDOG"
      log_success "Updated: ~/.local/bin/fprintd-watchdog"
    fi
  else
    cp "$SOURCE_WATCHDOG" "$DEST_WATCHDOG"
    chmod +x "$DEST_WATCHDOG"
    log_success "Installed: ~/.local/bin/fprintd-watchdog"
  fi
else
  log_error "Watchdog not found: $SOURCE_WATCHDOG"
  exit 1
fi

# 3. Install systemd user service and timer
log_info "Installing systemd user units..."
mkdir -p ~/.config/systemd/user

if [ -f "${SCRIPT_DIR}/etc/systemd/user/fprintd-watchdog.service" ]; then
  cp "${SCRIPT_DIR}/etc/systemd/user/fprintd-watchdog.service" ~/.config/systemd/user/
  log_success "Installed: ~/.config/systemd/user/fprintd-watchdog.service"
else
  log_error "Service file not found"
  exit 1
fi

if [ -f "${SCRIPT_DIR}/etc/systemd/user/fprintd-watchdog.timer" ]; then
  cp "${SCRIPT_DIR}/etc/systemd/user/fprintd-watchdog.timer" ~/.config/systemd/user/
  log_success "Installed: ~/.config/systemd/user/fprintd-watchdog.timer"
else
  log_error "Timer file not found"
  exit 1
fi

# 4. Enable and start timer
log_info "Enabling fprintd-watchdog timer..."
systemctl --user daemon-reload
systemctl --user enable fprintd-watchdog.timer
systemctl --user start fprintd-watchdog.timer

log_success "fprintd-watchdog timer enabled and started"

# 5. Configure sudo for watchdog (optional but recommended)
log_info ""
log_info "For automatic restart without sudo prompt, add to /etc/sudoers.d/fprintd-watchdog:"
log_info ""
echo "# Allow user to restart fprintd service without password (for watchdog)"
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart fprintd.service"
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop fprintd.service"
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start fprintd.service"
log_info ""
if [[ $NON_INTERACTIVE -eq 1 ]]; then
  log_info "Non-interactive mode; skipping sudoers prompt."
  REPLY="n"
elif [[ -t 0 && -t 1 ]]; then
  read -p "Add these rules to /etc/sudoers.d/fprintd-watchdog? (y/N) " -n 1 -r || true
  echo
else
  log_info "Non-interactive session; skipping sudoers prompt."
  REPLY="n"
fi
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sudo tee /etc/sudoers.d/fprintd-watchdog >/dev/null <<EOF
# Allow $USER to restart fprintd service without password (for watchdog)
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart fprintd.service
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop fprintd.service
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start fprintd.service
EOF
  sudo chmod 0440 /etc/sudoers.d/fprintd-watchdog
  log_success "Sudoers rules added"
else
  log_info "Skipped sudoers configuration"
  log_warning "Watchdog will not be able to auto-restart fprintd without manual sudo"
fi

log_info ""
log_success "Fprintd watchdog system installed!"
log_info ""
log_info "The system now includes:"
log_info "  • System-sleep hook: Restarts fprintd on suspend/resume"
log_info "  • Watchdog timer: Checks every 30 minutes for stuck claims"
log_info "  • Auto-recovery: Restarts fprintd if >3 claim errors detected"
log_info ""
log_info "Check status:"
log_info "  systemctl --user status fprintd-watchdog.timer"
log_info ""
log_info "Manual restart if needed:"
log_info "  bash ~/dotfiles/hosts/goldendragon/restart-fprintd.sh"
