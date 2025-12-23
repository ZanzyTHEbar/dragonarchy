#!/bin/bash
# Sets up a seamless boot experience using Plymouth.

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"
BOOT_LIB="${PROJECT_ROOT}/scripts/lib/bootloader.sh"
# shellcheck disable=SC1091
source "$LOG_LIB"
# shellcheck disable=SC1091
source "$BOOT_LIB"

if ! command -v paru &>/dev/null; then
    log_warning "paru not found. Please install it first."
    exit 1
fi
paru -S --noconfirm --needed uwsm plymouth

# --- 2. Configure mkinitcpio ---
log_info "Configuring mkinitcpio for Plymouth hook..."
if ! grep -Eq '^HOOKS=.*plymouth' /etc/mkinitcpio.conf; then
    log_info "Adding Plymouth hook to mkinitcpio.conf..."
    sudo cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak.$(date +%Y%m%d%H%M%S)"

    if grep "^HOOKS=" /etc/mkinitcpio.conf | grep -q "base systemd"; then
        sudo sed -i '/^HOOKS=/s/base systemd/base systemd plymouth/' /etc/mkinitcpio.conf
    elif grep "^HOOKS=" /etc/mkinitcpio.conf | grep -q "base udev"; then
        sudo sed -i '/^HOOKS=/s/base udev/base udev plymouth/' /etc/mkinitcpio.conf
    else
        log_warning "Could not automatically add Plymouth hook. Please add it manually."
    fi

    log_info "Regenerating initramfs..."
    sudo mkinitcpio -P
else
    log_info "Plymouth hook already present in mkinitcpio.conf."
fi

# --- 3. Add Kernel Parameters ---
log_info "Adding kernel parameters for bootloader..."

BOOT_KERNEL_PARAMS="quiet splash"
bootloader="$(detect_bootloader)"
log_info "Detected bootloader: $bootloader"
if [[ "$bootloader" == "unknown" ]]; then
    log_warning "Unable to detect bootloader automatically; attempting best-effort update"
fi

if sudo env BOOT_LIB="$BOOT_LIB" LOG_LIB="$LOG_LIB" KERNEL_PARAMS="$BOOT_KERNEL_PARAMS" bash -c '
    set -e
    # shellcheck disable=SC1091
    source "$LOG_LIB"
    # shellcheck disable=SC1091
    source "$BOOT_LIB"
    boot_append_kernel_params "$KERNEL_PARAMS"
    boot_rebuild_if_changed
'; then
    log_success "Kernel parameters ensured (quiet splash)"
else
    log_warning "Failed to update bootloader automatically. Please add '$BOOT_KERNEL_PARAMS' manually."
fi

# --- 4. Set Default Plymouth Theme ---
log_info "Setting default Plymouth theme to 'dragon'..."
if [ "$(plymouth-set-default-theme)" != "dragon" ]; then
    # Assumes the 'plymouth' package from this repo is stowed
    sudo plymouth-set-default-theme -R dragon
else
    log_info "Default Plymouth theme is already set to 'dragon'."
fi

log_success "Plymouth configuration complete!"
log_info "Hosts that need VT hand-off can run hosts/shared/services/seamless-login/install.sh from their setup script."
