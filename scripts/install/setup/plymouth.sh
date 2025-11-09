#!/bin/bash
# Sets up a seamless boot experience using Plymouth.

set -e

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"

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

# Function to add kernel parameters to a config file
add_kernel_parameters() {
    local config_file="$1"
    local parameters="$2"
    if ! grep -q "$parameters" "$config_file"; then
        log_info "Adding '$parameters' to $(basename "$config_file")"
        sudo sed -i "/^options/ s/$/ $parameters/" "$config_file"
    else
        log_info "'$parameters' already present in $(basename "$config_file")"
    fi
}

# Unified Kernel Image (UKI) detection
is_uki_boot() {
    # If a .conf file in /boot/loader/entries/ points to a UKI in /boot/efi/EFI/Linux
    if [ -d "/boot/loader/entries" ] && [ -d "/boot/efi/EFI/Linux" ]; then
        for entry in /boot/loader/entries/*.conf; do
            if [ -f "$entry" ] && grep -q "/boot/efi/EFI/Linux" "$entry"; then
                return 0 # UKI boot detected
            fi
        done
    fi
    # If UKI is directly in /boot/efi
    if [ -f "/boot/efi/EFI/Linux/linux.efi" ]; then
        return 0
    fi
    return 1 # Not a UKI boot
}

if is_uki_boot; then
    log_info "Detected a UKI setup with systemd-boot. Adding kernel parameters..."
    # UKI with systemd-boot typically uses /etc/kernel/cmdline
    if [ -f "/etc/kernel/cmdline" ]; then
        add_kernel_parameters "/etc/kernel/cmdline" "splash quiet"
        sudo mkinitcpio -P
        log_info "Updated UKI kernel command line and regenerated initramfs."
    elif [ -d "/etc/cmdline.d" ]; then
        if ! grep -q "splash" /etc/cmdline.d/*.conf 2>/dev/null; then
            echo "splash" | sudo tee -a /etc/cmdline.d/dragon.conf
        fi
        if ! grep -q "quiet" /etc/cmdline.d/*.conf 2>/dev/null; then
            echo "quiet" | sudo tee -a /etc/cmdline.d/dragon.conf
        fi
        sudo mkinitcpio -P
        log_info "Updated UKI kernel command line and regenerated initramfs."
    else
        log_warning "Could not determine how to set kernel parameters for this UKI setup."
    fi
elif [ -d "/boot/loader/entries" ]; then
    log_info "Detected systemd-boot. Adding kernel parameters..."
    for entry in /boot/loader/entries/*.conf; do
        if [ -f "$entry" ] && [[ ! "$(basename "$entry")" == *"fallback"* ]]; then
            add_kernel_parameters "$entry" "splash quiet"
        fi
    done
elif [ -f "/boot/limine.conf" ] || [ -f "/boot/limine/limine.conf" ]; then
    log_info "Detected Limine. Adding kernel parameters..."
    
    # Determine the correct path for limine.conf
    limine_cfg_path=""
    if [ -f "/boot/limine.conf" ]; then
        limine_cfg_path="/boot/limine.conf"
    else
        limine_cfg_path="/boot/limine/limine.conf"
    fi

    if ! grep -q "quiet splash" "$limine_cfg_path"; then
        sudo sed -i '/^CMDLINE/ s/"$/ quiet splash"/' "$limine_cfg_path"
        log_info "Added 'quiet splash' to $limine_cfg_path"
    else
        log_info "'quiet splash' already present in $limine_cfg_path"
    fi
elif [ -f "/etc/default/grub" ]; then
    log_info "Detected GRUB. Adding kernel parameters..."
    if ! grep -q "GRUB_CMDLINE_LINUX_DEFAULT.*splash" /etc/default/grub; then
        current_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | cut -d'"' -f2)
        new_cmdline="$current_cmdline"
        if [[ ! "$current_cmdline" =~ splash ]]; then new_cmdline="$new_cmdline splash"; fi
        if [[ ! "$current_cmdline" =~ quiet ]]; then new_cmdline="$new_cmdline quiet"; fi
        new_cmdline=$(echo "$new_cmdline" | xargs)
        sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"/" /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        log_info "Updated GRUB config and regenerated grub.cfg"
    else
        log_info "GRUB already configured with splash parameters."
    fi
else
    log_warning "No supported bootloader (systemd-boot, Limine, GRUB, UKI) detected. Please add 'splash quiet' to your kernel parameters manually."
fi

# --- 4. Set Default Plymouth Theme ---
log_info "Setting default Plymouth theme to 'dragon'..."
if [ "$(plymouth-set-default-theme)" != "dragon" ]; then
    # Assumes the 'plymouth' package from this repo is stowed
    sudo plymouth-set-default-theme -R dragon
else
    log_info "Default Plymouth theme is already set to 'dragon'."
fi

# --- 5. Compile and Install Seamless Login Helper ---
log_info "Compiling and installing seamless login helper..."
if [ ! -x /usr/local/bin/seamless-login ]; then
    cat <<'CCODE' >/tmp/seamless-login.c
/*
* Seamless Login - Minimal SDDM-style Plymouth transition
* Replicates SDDM's VT management for seamless auto-login
*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/kd.h>
#include <linux/vt.h>
#include <sys/wait.h>
#include <string.h>

int main(int argc, char *argv[]) {
    int vt_fd;
    int vt_num = 1; // TTY1
    char vt_path[32];
    
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <session_command>\n", argv[0]);
        return 1;
    }
    
    // Open the VT (simple approach like SDDM)
    snprintf(vt_path, sizeof(vt_path), "/dev/tty%d", vt_num);
    vt_fd = open(vt_path, O_RDWR);
    if (vt_fd < 0) {
        perror("Failed to open VT");
        return 1;
    }
    
    // Activate the VT
    if (ioctl(vt_fd, VT_ACTIVATE, vt_num) < 0) {
        perror("VT_ACTIVATE failed");
        close(vt_fd);
        return 1;
    }
    
    // Wait for VT to be active
    if (ioctl(vt_fd, VT_WAITACTIVE, vt_num) < 0) {
        perror("VT_WAITACTIVE failed");
        close(vt_fd);
        return 1;
    }
    
    // Critical: Set graphics mode to prevent console text
    if (ioctl(vt_fd, KDSETMODE, KD_GRAPHICS) < 0) {
        perror("KDSETMODE KD_GRAPHICS failed");
        close(vt_fd);
        return 1;
    }
    
    // Clear VT and close (like SDDM does)
    const char *clear_seq = "\33[H\33[2J";
    if (write(vt_fd, clear_seq, strlen(clear_seq)) < 0) {
        perror("Failed to clear VT");
    }
    
    close(vt_fd);
    
    // Set working directory to user's home
    const char *home = getenv("HOME");
    if (home) chdir(home);
    
    // Now execute the session command
    execvp(argv[1], &argv[1]);
    perror("Failed to exec session");
    return 1;
}
CCODE
    gcc -o /tmp/seamless-login /tmp/seamless-login.c
    sudo mv /tmp/seamless-login /usr/local/bin/seamless-login
    sudo chmod +x /usr/local/bin/seamless-login
    rm /tmp/seamless-login.c
    log_success "Seamless login helper installed."
else
    log_info "Seamless login helper already installed."
fi

# --- 6. Configure systemd Services ---
log_info "Configuring systemd services for seamless boot..."

# Create the main seamless login service
if [ ! -f /etc/systemd/system/dragon-seamless-login.service ]; then
    sudo tee /etc/systemd/system/dragon-seamless-login.service >/dev/null <<EOF
[Unit]
Description=Dragon Seamless Auto-Login
Documentation=https://github.com/ZanzyTHEbar/dotfiles
Conflicts=getty@tty1.service
After=systemd-user-sessions.service getty@tty1.service plymouth-quit.service systemd-logind.service
PartOf=graphical.target

[Service]
Type=simple
ExecStart=/usr/local/bin/seamless-login uwsm start -- hyprland.desktop
Restart=always
RestartSec=2
User=$USER
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty
StandardOutput=journal
StandardError=journal+console
PAMName=login

[Install]
WantedBy=graphical.target
EOF
    log_info "Created dragon-seamless-login.service."
fi

# Ensure plymouth waits for the graphical session
if [ ! -f /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf ]; then
    sudo mkdir -p /etc/systemd/system/plymouth-quit.service.d
    sudo tee /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf >/dev/null <<'EOF'
[Unit]
After=multi-user.target
EOF
    log_info "Configured plymouth-quit.service to wait for graphical session."
fi

# Enable/disable the necessary services
log_info "Managing systemd services..."
if ! systemctl is-enabled plymouth-quit-wait.service | grep -q masked; then
    sudo systemctl mask plymouth-quit-wait.service
fi
if ! systemctl is-enabled dragon-seamless-login.service | grep -q enabled; then
    sudo systemctl enable dragon-seamless-login.service
fi
if systemctl is-enabled getty@tty1.service | grep -q enabled; then
    sudo systemctl disable getty@tty1.service
fi
sudo systemctl daemon-reload

log_success "Plymouth seamless boot setup complete!"
log_warning "A reboot is required for all changes to take effect."
