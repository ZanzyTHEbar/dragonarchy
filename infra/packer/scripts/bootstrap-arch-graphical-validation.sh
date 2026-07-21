#!/usr/bin/env bash

set -euo pipefail

# Adds a small **Wayland/Hyprland** repo-native set for graphical smoke tests.
# This is not a full manifest bundle; AUR/vendor tiers remain out-of-band.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/bootstrap-arch-validation.sh"

while fuser /var/lib/pacman/db.lck >/dev/null 2>&1
do
    sleep 2
done

pacman -S --noconfirm --needed \
    hypridle \
    hyprland \
    hyprlock \
    kitty \
    mesa \
    pipewire \
    qt5-wayland \
    qt6-wayland \
    spice-vdagent \
    vulkan-tools \
    vulkan-virtio \
    waybar \
    wireplumber \
    wl-clipboard \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-hyprland \
    xorg-xwayland

install -d /etc/environment.d
cat > /etc/environment.d/90-dotfiles-graphical-validation.conf <<'EOF'
WLR_RENDERER_ALLOW_SOFTWARE=1
EOF

systemctl enable spice-vdagentd.service || true
systemctl start spice-vdagentd.service || true
