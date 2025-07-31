#!/usr/bin/env bash

# Host-specific setup for Hyprland

set -euo pipefail

# Logging functions (assuming they are available from the main script)
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_step() {
    echo -e "\033[0;36m[STEP]\033[0m $1"
}

configure_system() {
    log_step "Configuring system settings for Hyprland..."

    # Setup GPG configuration
    sudo mkdir -p /etc/gnupg
    if [ ! -f /etc/gnupg/dirmngr.conf ]; then
        echo "keyserver hkp://keyserver.ubuntu.com" | sudo tee /etc/gnupg/dirmngr.conf >/dev/null
    fi
    sudo gpgconf --kill dirmngr || true
    sudo gpgconf --launch dirmngr || true

    # Increase PAM lockout limit
    sudo sed -i 's/^\(auth\s\+required\s\+pam_faillock.so\)\s\+preauth.*$/\1 preauth silent deny=10 unlock_time=120/' "/etc/pam.d/system-auth"
    sudo sed -i 's/^\(auth\s\+\[default=die\]\s\+pam_faillock.so\)\s\+authfail.*$/\1 authfail deny=10 unlock_time=120/' "/etc/pam.d/system-auth"

    # Set common git aliases
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.st status
    git config --global pull.rebase true
    git config --global init.defaultBranch master

    # Configure Apple keyboard
    if [[ ! -f /etc/modprobe.d/hid_apple.conf ]]; then
        echo "options hid_apple fnmode=2" | sudo tee /etc/modprobe.d/hid_apple.conf
    fi

    log_success "System settings configured."
}

configure_plymouth() {
    log_step "Configuring Plymouth..."

    if ! grep -Eq '^HOOKS=.*plymouth' /etc/mkinitcpio.conf; then
        sudo sed -i '/^HOOKS=/s/base systemd/base systemd plymouth/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
    fi

    if [ -d "/boot/loader/entries" ]; then
        for entry in /boot/loader/entries/*.conf; do
            if [ -f "$entry" ] && [[ ! "$(basename "$entry")" == *"fallback"* ]] && ! grep -q "splash" "$entry"; then
                sudo sed -i '/^options/ s/$/ splash quiet/' "$entry"
            fi
        done
    elif [ -f "/etc/default/grub" ]; then
        if ! grep -q "GRUB_CMDLINE_LINUX_DEFAULT.*splash" /etc/default/grub; then
            sudo sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT=\"\)/\1splash quiet /" /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
    fi
    
    log_success "Plymouth configured."
}

configure_seamless_login() {
    log_step "Configuring seamless login..."

    if [ ! -x /usr/local/bin/seamless-login ]; then
        cat <<'CCODE' >/tmp/seamless-login.c
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
    int vt_num = 1;
    char vt_path[32];
    
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <session_command>\n", argv[0]);
        return 1;
    }
    
    snprintf(vt_path, sizeof(vt_path), "/dev/tty%d", vt_num);
    vt_fd = open(vt_path, O_RDWR);
    if (vt_fd < 0) {
        perror("Failed to open VT");
        return 1;
    }
    
    if (ioctl(vt_fd, VT_ACTIVATE, vt_num) < 0) {
        perror("VT_ACTIVATE failed");
        close(vt_fd);
        return 1;
    }
    
    if (ioctl(vt_fd, VT_WAITACTIVE, vt_num) < 0) {
        perror("VT_WAITACTIVE failed");
        close(vt_fd);
        return 1;
    }
    
    if (ioctl(vt_fd, KDSETMODE, KD_GRAPHICS) < 0) {
        perror("KDSETMODE KD_GRAPHICS failed");
        close(vt_fd);
        return 1;
    }
    
    const char *clear_seq = "\33[H\33[2J";
    if (write(vt_fd, clear_seq, strlen(clear_seq)) < 0) {
        perror("Failed to clear VT");
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
    fi

    if [ ! -f /etc/systemd/system/hyprland-seamless-login.service ]; then
        cat <<EOF | sudo tee /etc/systemd/system/hyprland-seamless-login.service
[Unit]
Description=Seamless Auto-Login for Hyprland
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
    fi

    sudo systemctl enable hyprland-seamless-login.service
    sudo systemctl disable getty@tty1.service

    log_success "Seamless login configured."
}

configure_networking() {
    log_step "Configuring networking..."
    sudo systemctl enable --now iwd.service
    sudo mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
    sudo tee /etc/systemd/system/systemd-networkd-wait-online.service.d/wait-for-only-one-interface.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any
EOF
    log_success "Networking configured."
}

configure_firewall() {
    log_step "Configuring firewall..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 53317/udp
    sudo ufw allow 53317/tcp
    sudo ufw allow 22/tcp
    sudo ufw allow in on docker0 to any port 53
    echo "y" | sudo ufw enable
    if command -v ufw-docker &>/dev/null; then
        sudo ufw-docker install
    fi
    sudo ufw reload
    log_success "Firewall configured."
}

configure_power_management() {
    log_step "Configuring power management..."
    if ls /sys/class/power_supply/BAT* &>/dev/null; then
        powerprofilesctl set balanced || true
    else
        powerprofilesctl set performance || true
    fi
    log_success "Power management configured."
}

configure_timezone() {
    log_step "Configuring timezone..."
    if command -v tzupdate &>/dev/null; then
        sudo tee /etc/sudoers.d/hyprland-tzupdate >/dev/null <<EOF
%wheel ALL=(root) NOPASSWD: /usr/bin/tzupdate, /usr/bin/timedatectl
EOF
        sudo chmod 0440 /etc/sudoers.d/hyprland-tzupdate
    fi
    log_success "Timezone configured."
}

configure_nvidia() {
    log_step "Configuring NVIDIA drivers..."
    if lspci | grep -i 'nvidia' &>/dev/null; then
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
            sudo pacman -Syy
        fi
        echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null
        local mkinitcpio_conf="/etc/mkinitcpio.conf"
        local nvidia_modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
        if ! grep -q "$nvidia_modules" "$mkinitcpio_conf"; then
            sudo sed -i -E "s/^(MODULES=\\()/\\1${nvidia_modules} /" "$mkinitcpio_conf"
            sudo mkinitcpio -P
        fi
        sudo tee /etc/profile.d/nvidia.sh >/dev/null <<'EOF'
export NVD_BACKEND=direct
export LIBVA_DRIVER_NAME=nvidia
export __GLX_VENDOR_LIBRARY_NAME=nvidia
EOF
    else
        log_info "No NVIDIA card detected, skipping NVIDIA configuration."
    fi
    log_success "NVIDIA drivers configured."
}

configure_desktop() {
    log_step "Configuring desktop and applications..."
    
    # Configure asdcontrol for Apple displays
    if [ -d /sys/class/backlight/gmux_backlight ]; then
        if ! command -v asdcontrol &>/dev/null; then
            git clone https://github.com/nikosdion/asdcontrol.git /tmp/asdcontrol
            (cd /tmp/asdcontrol && make && sudo make install)
            rm -rf /tmp/asdcontrol
            echo "$USER ALL=(ALL) NOPASSWD: /usr/local/bin/asdcontrol" | sudo tee /etc/sudoers.d/asdcontrol
            sudo chmod 440 /etc/sudoers.d/asdcontrol
        fi
    fi

    # Enable Bluetooth
    sudo systemctl enable --now bluetooth.service

    # Enable CUPS for printing
    sudo systemctl enable --now cups.service

    # Set MIME type defaults
    xdg-mime default imv.desktop image/png image/jpeg image/gif image/webp image/bmp image/tiff
    xdg-mime default org.gnome.Evince.desktop application/pdf
    xdg-settings set default-web-browser chromium.desktop
    xdg-mime default chromium.desktop x-scheme-handler/http x-scheme-handler/https
    xdg-mime default mpv.desktop video/mp4 video/x-msvideo video/x-matroska video/x-flv video/x-ms-wmv video/mpeg video/ogg video/webm video/quicktime video/3gpp video/3gpp2 video/x-ms-asf video/x-ogm+ogg video/x-theora+ogg application/ogg
    update-desktop-database -q ~/.local/share/applications

    # Set GTK theme
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

    log_success "Desktop and applications configured."
}

configure_themes() {
    log_step "Configuring themes..."

    mkdir -p ~/.config/hypr/themes
    ln -snf ~/.config/themes/tokyo-night ~/.config/hypr/themes/current

    log_success "Themes configured."
}


log_step "Starting Hyprland host-specific setup..."

configure_system
configure_plymouth
configure_seamless_login
configure_networking
configure_firewall
configure_power_management
configure_timezone
configure_nvidia
configure_desktop
configure_themes

log_success "Hyprland host-specific setup completed."
