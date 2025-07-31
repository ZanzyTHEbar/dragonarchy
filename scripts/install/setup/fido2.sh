#!/bin/bash
# Configures a FIDO2 device for passwordless sudo.

set -e

# --- Header and Logging ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { 
  echo -e "\n${BLUE}[INFO]${NC} $1" 
}

log_success() { 
  echo -e "${GREEN}[SUCCESS]${NC} $1" 
}

log_error() { 
  echo -e "${RED}[ERROR]${NC} $1" 
}

if [[ "--remove" == "$1" ]]; then
  log_info "Removing FIDO2 device setup..."
  yay -Rns --noconfirm libfido2 pam-u2f
  sudo rm -rf /etc/fido2
  sudo sed -i '\|^auth[[:space:]]\+sufficient[[:space:]]\+pam_u2f\.so.*|d' /etc/pam.d/sudo
  log_success "FIDO2 device setup successfully removed."
else
  log_info "Setting up FIDO2 device..."
  yay -S --noconfirm --needed libfido2 pam-u2f

  log_info "Detecting FIDO2 devices..."
  tokens=$(fido2-token -L)

  if [ -z "$tokens" ]; then
    log_error "No FIDO2 device detected. Please plug it in and unlock it if necessary."
  else
    log_info "FIDO2 device detected. Creating configuration..."
    if [ ! -f /etc/fido2/fido2_keys ]; then
      sudo mkdir -p /etc/fido2
      log_info "Please touch your FIDO2 device to register it..."
      pamu2fcfg >/tmp/fido2_keys
      sudo mv /tmp/fido2_keys /etc/fido2/
    fi

    log_info "Adding FIDO2 authentication for sudo..."
    if ! grep -q pam_u2f.so /etc/pam.d/sudo; then
      sudo sed -i '1i auth       sufficient   pam_u2f.so cue authfile=/etc/fido2/fido2_keys' /etc/pam.d/sudo
    fi

    log_info "Testing sudo with FIDO2 device..."
    if sudo -k && sudo echo "Please touch your FIDO2 device to authenticate for this test..."; then
      log_success "FIDO2 setup complete! You can now use your device for sudo."
    else
      log_error "FIDO2 sudo test failed. Please check the device and try again."
    fi
  fi
fi
