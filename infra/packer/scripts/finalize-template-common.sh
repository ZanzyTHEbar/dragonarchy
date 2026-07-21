#!/usr/bin/env bash

set -euo pipefail

guest_user="${PACKER_SSH_USERNAME:-dragon}"

if command -v apt-get >/dev/null 2>&1; then
    apt-get clean
    rm -rf /var/lib/apt/lists/*
fi

if command -v pacman >/dev/null 2>&1; then
    pacman -Scc --noconfirm || true
fi

cloud-init clean --logs || true
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
rm -f /etc/ssh/ssh_host_*
rm -f /root/.bash_history /root/.zsh_history
rm -f "/home/${guest_user}/.bash_history" "/home/${guest_user}/.zsh_history"
