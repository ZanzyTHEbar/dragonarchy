#!/bin/bash
# Quick manual installation of suspend/resume fixes
# Run this after the main install-suspend-fix.sh failed to install services

set -e

echo "Installing suspend/resume service files..."
echo

# 1. Install logind config
echo "[1/4] Installing systemd-logind configuration..."
sudo mkdir -p /etc/systemd/logind.conf.d
sudo cp ~/dotfiles/hosts/firedragon/etc/systemd/logind.conf.d/10-firedragon-lid.conf /etc/systemd/logind.conf.d/
echo "✓ Logind config installed"
echo

# 2. Install AMD GPU services
echo "[2/4] Installing AMD GPU suspend/resume services..."
sudo cp ~/dotfiles/hosts/firedragon/etc/systemd/system/amdgpu-suspend.service /etc/systemd/system/
sudo cp ~/dotfiles/hosts/firedragon/etc/systemd/system/amdgpu-resume.service /etc/systemd/system/
echo "✓ Services copied"
echo

# 3. Enable services
echo "[3/4] Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable amdgpu-suspend.service
sudo systemctl enable amdgpu-resume.service
echo "✓ Services enabled"
echo

# 4. Verify
echo "[4/4] Verifying installation..."
systemctl status amdgpu-suspend.service amdgpu-resume.service --no-pager | head -20
echo
cat /etc/systemd/logind.conf.d/10-firedragon-lid.conf
echo

echo "═══════════════════════════════════════════════"
echo "✓ Installation complete!"
echo "═══════════════════════════════════════════════"
echo
echo "⚠️  REBOOT REQUIRED for changes to take effect"
echo
echo "After reboot:"
echo "  • check-suspend     (should show services enabled)"
echo "  • Test lid close/open"
echo "  • Test lock screen"
echo "  • Test suspend/resume"
echo
read -p "Reboot now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting in 3 seconds..."
    sleep 3
    systemctl reboot
else
    echo "Remember to reboot: systemctl reboot"
fi

