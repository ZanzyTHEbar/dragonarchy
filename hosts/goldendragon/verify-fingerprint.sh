#!/usr/bin/env bash
#
# Verify fingerprint setup on goldendragon (fprintd + PAM wiring)
#
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib/logging.sh"

show_pam_status() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    log_warning "PAM file missing: $f"
    return 0
  fi
  if sudo grep -qE '^\s*auth\s+.*pam_fprintd\.so' "$f"; then
    log_success "PAM OK: pam_fprintd enabled in $f"
  else
    log_warning "PAM missing pam_fprintd in $f"
  fi
}

main() {
  log_step "Fingerprint verification (goldendragon)"
  echo

  log_info "Detecting sensor (lsusb best-effort)..."
  if command_exists lsusb; then
    lsusb | grep -Ei 'fingerprint|fprint|synaptics|validity|goodix|elan|egis' || true
  else
    log_warning "lsusb not installed (install usbutils)"
  fi
  echo

  log_info "Checking required tools..."
  if command_exists fprintd-enroll; then
    log_success "fprintd-enroll found"
  else
    log_error "fprintd-enroll not found (install fprintd)"
  fi
  echo

  log_info "Checking fprintd service..."
  if command_exists systemctl && systemctl list-unit-files 2>/dev/null | grep -q '^fprintd\\.service'; then
    # DBus-activated services can be "inactive" until first use; that's OK.
    state="$(systemctl show -p UnitFileState,ActiveState,SubState fprintd.service 2>/dev/null | tr '\n' ' ')"
    log_info "fprintd.service status: ${state}"
    log_info "Tip: run fprintd-verify, then re-check; the service should activate on-demand."
  else
    log_warning "fprintd.service not found"
  fi
  echo

  log_info "Checking PAM wiring (fingerprint with password fallback)..."
  show_pam_status /etc/pam.d/sudo
  show_pam_status /etc/pam.d/polkit-1
  show_pam_status /etc/pam.d/system-local-login
  show_pam_status /etc/pam.d/sddm
  # hyprlock is installed by the installer; goldendragon provides a host-scoped PAM file.
  show_pam_status /etc/pam.d/hyprlock
  echo

  log_step "Interactive tests (run manually)"
  cat <<'EOF'
- Enroll:
  fprintd-enroll
  # If you get permissions errors:
  sudo fprintd-enroll "$USER"

- Verify:
  fprintd-verify

- Validate UX:
  - Run: sudo true   (should prompt for fingerprint; password should still work)
  - Trigger a polkit prompt (e.g., open a settings panel that needs admin)
  - If using SDDM: test after a reboot/session restart
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

