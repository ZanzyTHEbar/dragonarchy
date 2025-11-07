#!/bin/bash
# FireDragon: AMD GPU Console/TTY Fix Script
# Fixes blank TTY and framebuffer issues after suspend/resume

set -e

echo "=== FireDragon AMD GPU Console/TTY Fix ==="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# 1. Add kernel parameters for better console support
echo "[1/4] Configuring kernel parameters for AMD GPU console support..."

# Create kernel parameter file for console fixes
cat > /etc/modprobe.d/amdgpu-console.conf << 'EOF'
# AMD GPU Console/Framebuffer Fixes for TTY
# These options improve console stability during suspend/resume

# Enable atomic modesetting (required for proper TTY handling)
options amdgpu modeset=1

# Disable hardware cursor (can cause TTY blank screen)
options amdgpu hw_cursor=0

# Enable early KMS (Kernel Mode Setting) for console
# This ensures console is available early in boot and after resume
options amdgpu kms=1
EOF

echo "✓ Created /etc/modprobe.d/amdgpu-console.conf"

# 2. Update mkinitcpio to include amdgpu module early
echo "[2/4] Configuring early amdgpu module loading..."

# Backup mkinitcpio.conf
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup.$(date +%Y%m%d_%H%M%S)

# Check if amdgpu is already in MODULES
if ! grep -q "^MODULES=.*amdgpu" /etc/mkinitcpio.conf; then
    # Add amdgpu to MODULES array
    sed -i '/^MODULES=/ s/)/ amdgpu)/' /etc/mkinitcpio.conf
    sed -i 's/( amdgpu/(amdgpu/' /etc/mkinitcpio.conf  # Clean up double space
    echo "✓ Added amdgpu to mkinitcpio MODULES"
else
    echo "✓ amdgpu already in mkinitcpio MODULES"
fi

# 3. Create systemd service to fix TTY after resume
echo "[3/4] Creating TTY restore service..."

cat > /etc/systemd/system/fix-tty-after-resume.service << 'EOF'
[Unit]
Description=Fix TTY Console After Resume
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
# Reset all TTYs
ExecStart=/usr/bin/chvt 1
ExecStart=/usr/bin/sleep 0.5
ExecStart=/usr/bin/chvt 7
# Force DRM device refresh
ExecStart=/bin/sh -c 'for card in /sys/class/drm/card*/device/driver/*/drm/card*/status; do cat "$card" > /dev/null 2>&1 || true; done'
# Restart getty on all TTYs
ExecStart=/bin/systemctl restart getty@tty1.service
ExecStart=/bin/systemctl restart getty@tty2.service

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

echo "✓ Created fix-tty-after-resume.service"

# 4. Rebuild initramfs and enable services
echo "[4/4] Rebuilding initramfs and enabling services..."

# Rebuild initramfs
mkinitcpio -P

# Enable the TTY fix service
systemctl enable fix-tty-after-resume.service

echo
echo "=== AMD GPU Console/TTY Fix Complete ==="
echo
echo "Changes made:"
echo "  • Created /etc/modprobe.d/amdgpu-console.conf"
echo "  • Updated mkinitcpio.conf to load amdgpu early"
echo "  • Created fix-tty-after-resume.service"
echo "  • Rebuilt initramfs"
echo
echo "⚠️  IMPORTANT: Reboot required for changes to take effect!"
echo

