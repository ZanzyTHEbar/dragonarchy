#!/bin/bash
# Applies cosmetic tweaks to /etc/pacman.conf.

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

if ! grep -q "ILoveCandy" /etc/pacman.conf; then
  log_info "Adding 'ILoveCandy' to pacman.conf..."
  sudo sed -i '/^#Color/a ILoveCandy' /etc/pacman.conf
  sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
else
  log_info "'ILoveCandy' already present in pacman.conf."
fi

log_info "Pacman tweaks complete."
