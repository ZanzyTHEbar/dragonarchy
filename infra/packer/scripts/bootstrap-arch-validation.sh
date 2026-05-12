#!/usr/bin/env bash

set -euo pipefail

# Minimal **repo-native** toolchain for disposable Arch validation (SSH, git, chezmoi).
# Full host package composition is defined in ../../scripts/install/deps.manifest.toml
# and inspected via scripts/install/export-package-plan.sh (tiers: pacman/apt vs paru/script).

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

# Install ansible for control-plane convergence
if ! command -v ansible-playbook >/dev/null 2>&1; then
    pacman -S --noconfirm --needed ansible-core
fi

if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

# TODO: After bootstrap, clone repo and run full convergence:
#   git clone https://github.com/ZanzyTHEbar/dragonarchy ~/dotfiles
#   cd ~/dotfiles
#   ./install --host <validation-host> --dry-run
