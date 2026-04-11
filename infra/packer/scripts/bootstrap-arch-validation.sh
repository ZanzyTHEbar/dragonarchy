#!/usr/bin/env bash

set -euo pipefail

# Let first-boot cloud-init settle before we touch pacman.
cloud-init status --wait >/dev/null 2>&1 || true

while fuser /var/lib/pacman/db.lck >/dev/null 2>&1
do
    sleep 2
done

pacman -Sy --noconfirm archlinux-keyring
pacman -S --noconfirm --needed \
    ca-certificates \
    curl \
    git \
    jq \
    python \
    qemu-guest-agent \
    rsync \
    stow \
    sudo \
    unzip \
    zsh

if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent
