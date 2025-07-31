#!/bin/bash
# Configures fingerprint authentication.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1" }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" }
log_error() { echo -e "${RED}[ERROR]${NC} $1" }

if [[ "--remove" == "$1" ]]; then
  log_info "Removing fingerprint authentication..."
  yay -Rns --noconfirm fprintd
  sudo rm -f /etc/pam.d/polkit-1
  sudo sed -i '/pam_fprintd\.so/d' /etc/pam.d/sudo
  log_success "Fingerprint setup successfully removed."
else
  log_info "Setting up fingerprint authentication..."
  yay -S --noconfirm --needed fprintd usbutils

  if ! lsusb | grep -Eiq 'fingerprint|synaptics|goodix'; then
    log_error "No fingerprint sensor detected."
  else
    log_info "Adding fingerprint authentication for sudo and polkit..."
    if ! grep -q pam_fprintd.so /etc/pam.d/sudo; then
      sudo sed -i '1i auth    sufficient pam_fprintd.so' /etc/pam.d/sudo
    fi

    if [ ! -f /etc/pam.d/polkit-1 ] || ! grep -q pam_fprintd.so /etc/pam.d/polkit-1; then
      sudo tee /etc/pam.d/polkit-1 >/dev/null <<'EOF'
auth      required pam_unix.so
auth      optional pam_fprintd.so
account   required pam_unix.so
password  required pam_unix.so
session   required pam_unix.so
EOF
    fi

    log_info "Enrolling the first finger. Please follow the prompts."
    log_info "Keep touching the sensor until the process completes."
    sudo fprintd-enroll "$USER"

    log_info "Verifying fingerprint..."
    if fprintd-verify; then
      log_success "Fingerprint verification successful! You can now use it for sudo and the lock screen."
    else
      log_error "Fingerprint verification failed. Please try again."
    fi
  fi
fi
