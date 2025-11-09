#!/bin/bash
# Enables the multilib repository for 32-bit compatibility, required by Steam.

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

if grep -q "^\s*#\s*\[multilib\]" /etc/pacman.conf; then
  sudo sed -i '/^\s*#\[multilib\]/,/^$/{s/^\s*#//}' /etc/pacman.conf
  log_info "Multilib repository enabled. Updating pacman..."
  sudo pacman -Sy
else
  log_info "Multilib repository already enabled."
fi

log_info "Steam setup complete. You can install Steam via the main install script or manually."
