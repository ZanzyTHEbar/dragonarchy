#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Let first-boot cloud-init work finish before we touch apt.
cloud-init status --wait >/dev/null 2>&1 || true

while fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
    || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
    || fuser /var/lib/apt/lists/lock >/dev/null 2>&1
do
    sleep 2
done

apt-get update -qq
apt-get install -y -qq \
    ca-certificates \
    curl \
    git \
    jq \
    python-is-python3 \
    python3 \
    qemu-guest-agent \
    rsync \
    stow \
    sudo \
    unzip \
    zsh

# Install ansible for control-plane convergence
if ! command -v ansible-playbook >/dev/null 2>&1; then
    apt-get install -y -qq ansible-core
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
