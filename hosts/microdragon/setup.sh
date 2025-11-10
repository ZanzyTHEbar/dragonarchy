#!/bin/bash
#
# Microdragon Host-Specific Setup
#
# This script configures the Raspberry Pi as a NetBird routing peer.

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../scripts/lib/logging.sh"
source "${SCRIPT_DIR}/../../scripts/lib/install-state.sh"

log_info "Running setup for microdragon (Raspberry Pi)..."

# Handle --reset flag to force re-run all steps
if [[ "${1:-}" == "--reset" ]]; then
    reset_all_steps
    log_info "Installation state reset. All steps will be re-run."
    echo
fi

# Install NetBird
if ! is_step_completed "microdragon-install-netbird"; then
    log_step "Installing NetBird..."
    if bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"; then
        mark_step_completed "microdragon-install-netbird"
    fi
else
    log_info "✓ NetBird already installed (skipped)"
fi
echo

# Enable IP forwarding
if ! is_step_completed "microdragon-enable-ip-forwarding"; then
    log_step "Enabling IP forwarding..."
    sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
    echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-netbird.conf >/dev/null
    log_success "IP forwarding enabled"
    mark_step_completed "microdragon-enable-ip-forwarding"
else
    log_info "✓ IP forwarding already enabled (skipped)"
fi
echo

log_success "Microdragon setup complete!"
