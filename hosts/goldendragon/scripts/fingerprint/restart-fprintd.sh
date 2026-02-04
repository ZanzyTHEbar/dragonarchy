#!/usr/bin/env bash
# Restart fprintd service to release device claim
# Run this if fingerprint authentication stops working

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../scripts/lib/logging.sh"

log_step "Restarting fprintd service..."

# Stop the service
log_info "Stopping fprintd.service..."
sudo systemctl stop fprintd.service 2>/dev/null || {
  log_warning "Could not stop fprintd.service (may not be running)"
}

# Wait a moment for device to be released
sleep 2

# Start the service
log_info "Starting fprintd.service..."
sudo systemctl start fprintd.service

# Check status
if systemctl is-active --quiet fprintd.service; then
  log_success "fprintd.service is now running"
else
  log_warning "fprintd.service may not be running properly"
  systemctl status fprintd.service --no-pager | head -15
fi

# Test fingerprint
log_info ""
log_info "Testing fingerprint reader..."
if fprintd-list "$USER" >/dev/null 2>&1; then
  log_success "Fingerprint reader is accessible"
  log_info ""
  log_info "Enrolled fingerprints:"
  fprintd-list "$USER"
  log_info ""
  log_info "Try: fprintd-verify"
else
  log_error "Fingerprint reader is still not accessible"
  log_info "Check logs: sudo journalctl -u fprintd.service -n 50"
fi
