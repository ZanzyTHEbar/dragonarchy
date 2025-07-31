#!/bin/bash
# Sets up a seamless boot experience using Plymouth.

set -e

# --- Header and Logging ---
BLUE='\033[0[34m'
GREEN='\033[0[32m'
YELLOW='\033[1[33m'
NC='\033[0m' # No Color
log_info() { echo -e "\n${BLUE}[INFO]${NC} $1" }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" }

# --- 1. Install Dependencies ---
log_info "Installing Plymouth and UWSM..."
yay -S --noconfirm --needed uwsm plymouth

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

# --- 3. Add Kernel Parameters for systemd-boot ---
log_info "Adding kernel parameters for systemd-boot..."
if [ -d "/boot/loader/entries" ]; then
  for entry in /boot/loader/entries/*.conf; do
    if [ -f "$entry" ] && [[ ! "$(basename "$entry")" == *"fallback"* ]]; then
      if ! grep -q "splash" "$entry"; then
        log_info "Adding 'splash quiet' to $(basename "$entry")"
        sudo sed -i '/^options/ s/$/ splash quiet/' "$entry"
      else
        log_info "'splash quiet' already present in $(basename "$entry")"
      fi
    fi
  done
else
  log_warning "systemd-boot directory not found. Please add 'splash quiet' to your kernel parameters manually."
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
/* Seamless Login - Minimal Plymouth transition helper */
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
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <session_command>\n", argv[0]);
        return 1;
    }
    int vt_fd = open("/dev/tty1", O_RDWR);
    if (vt_fd < 0) {
        perror("Failed to open VT"); return 1;
    }
    if (ioctl(vt_fd, VT_ACTIVATE, 1) < 0) {
        perror("VT_ACTIVATE failed"); close(vt_fd); return 1;
    }
    if (ioctl(vt_fd, VT_WAITACTIVE, 1) < 0) {
        perror("VT_WAITACTIVE failed"); close(vt_fd); return 1;
    }
    if (ioctl(vt_fd, KDSETMODE, KD_GRAPHICS) < 0) {
        perror("KDSETMODE failed"); close(vt_fd); return 1;
    }
    close(vt_fd);
    const char *home = getenv("HOME");
    if (home) chdir(home);
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
sudo tee /etc/systemd/system/dragon-seamless-login.service >/dev/null <<EOF
[Unit]
Description=Dragon Seamless Auto-Login
Conflicts=getty@tty1.service
After=systemd-user-sessions.service getty@tty1.service plymouth-quit.service systemd-logind.service
PartOf=graphical.target
[Service]
ExecStart=/usr/local/bin/seamless-login uwsm start -- hyprland.desktop
User=$USER
TTYPath=/dev/tty1
StandardInput=tty
PAMName=login
[Install]
WantedBy=graphical.target
EOF

# Ensure plymouth waits for the graphical session
sudo mkdir -p /etc/systemd/system/plymouth-quit.service.d
sudo tee /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf >/dev/null <<'EOF'
[Unit]
After=multi-user.target
EOF

# Enable/disable the necessary services
log_info "Enabling dragon-seamless-login.service and disabling getty@tty1.service..."
sudo systemctl mask plymouth-quit-wait.service
sudo systemctl enable dragon-seamless-login.service
sudo systemctl disable getty@tty1.service
sudo systemctl daemon-reload

log_success "Plymouth seamless boot setup complete!"
log_warning "A reboot is required for all changes to take effect."
