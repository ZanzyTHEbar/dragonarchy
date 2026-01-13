#!/bin/bash
#
# NetBird Installation
#
# This script installs and configures NetBird for both GUI and headless systems.

set -e

# Ensure we don't leave the machine with /etc/resolv.conf pointing at the
# systemd-resolved stub (127.0.0.53) when systemd-resolved isn't running.
ensure_systemd_resolved_stub_resolvconf() {
    # If systemd isn't present, do nothing.
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "systemctl not found; skipping systemd-resolved DNS stub configuration."
        return 0
    fi

    # If the unit exists, try to enable+start it (best-effort).
    if systemctl list-unit-files 2>/dev/null | grep -q '^systemd-resolved\.service'; then
        sudo systemctl enable --now systemd-resolved.service >/dev/null 2>&1 || true
    fi

    # Only touch /etc/resolv.conf if systemd-resolved is actually running.
    if ! systemctl is-active --quiet systemd-resolved.service 2>/dev/null; then
        echo "WARNING: systemd-resolved is not running; leaving /etc/resolv.conf unchanged."
        echo "         (If you want to use the stub resolver, enable/start systemd-resolved first.)"
        return 0
    fi

    local stub="/run/systemd/resolve/stub-resolv.conf"
    if [[ ! -e "$stub" ]]; then
        echo "WARNING: Expected stub resolv.conf not found at $stub; leaving /etc/resolv.conf unchanged."
        return 0
    fi

    # Idempotent handling:
    # - If already symlinked to the stub, do nothing.
    # - Otherwise, backup the current file once and link to the stub.
    if [[ -L /etc/resolv.conf ]]; then
        local target
        target="$(readlink -f /etc/resolv.conf 2>/dev/null || true)"
        if [[ "$target" == "$stub" ]]; then
            return 0
        fi
        sudo mv /etc/resolv.conf /etc/resolv.conf.bak >/dev/null 2>&1 || true
    else
        if [[ -f /etc/resolv.conf && ! -f /etc/resolv.conf.bak ]]; then
            sudo mv /etc/resolv.conf /etc/resolv.conf.bak
        elif [[ -f /etc/resolv.conf ]]; then
            sudo mv /etc/resolv.conf /etc/resolv.conf.bak.latest >/dev/null 2>&1 || true
        fi
    fi

    sudo ln -sf "$stub" /etc/resolv.conf
}

# Check if NetBird is already installed to make the script idempotent.
if command -v netbird &> /dev/null; then
    echo "NetBird is already installed. Skipping core installation."
else
    echo "Installing NetBird using the official script..."
    # Create a temporary directory to run the installer in, to avoid conflicts
    # with existing directories. The official script clones a 'netbird' git repo.
    INSTALL_DIR=$(mktemp -d)
    (
        cd "$INSTALL_DIR" || exit 1
        # The official script adds the repository and installs the 'netbird' package.
        # NOTE! As of 0.52.1 The install script is not working, so we need to install the package manually.
        # curl -fsSL https://pkgs.netbird.io/install.sh | sh
        
        git clone https://aur.archlinux.org/netbird.git
        cd netbird

        # Checkout the correct version
        git checkout 3f463ca9af98b620a652639e1a16cb83b3df3127

        # Install the package
        makepkg -si

        # Check that the package is installed with the correct version 0.51.2
        if ! command -v netbird &> /dev/null; then
            echo "NetBird is not installed. Please check the installation."
            exit 1
        fi
        if ! netbird version | grep -q "0.51.2"; then
            echo "NetBird is not installed with the correct version. Please check the installation."
            exit 1
        fi

    )
    # Clean up the temporary directory
    rm -rf "$INSTALL_DIR"

    # Now that the package is installed, we need to ensure the service is running.
    echo "Ensuring the NetBird service is enabled and running..."

    # Install the service
    sudo netbird service install
    sudo netbird service start

    sudo systemctl enable netbird

    # We need to fix systemd-resolved to use the correct DNS servers.
    # Ref: https://github.com/netbirdio/netbird/issues/1483#issuecomment-2774324545
    ensure_systemd_resolved_stub_resolvconf

    sudo systemctl restart netbird
fi

echo "NetBird installation complete."
echo
echo "IMPORTANT: To connect this machine to your network, run: netbird up"
echo "You will be prompted to log in via your browser to authorize the new peer."
