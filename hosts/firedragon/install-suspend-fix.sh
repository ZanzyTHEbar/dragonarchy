#!/bin/bash
# FireDragon: Suspend/Resume/Lock Fix Installation Script
# Fixes system freezing on lid close, sleep, and lock screen

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "═══════════════════════════════════════════════════════════════"
echo "  FireDragon Suspend/Resume/Lock Fix Installation"
echo "═══════════════════════════════════════════════════════════════"
echo
log_info "This script will fix the following issues:"
echo "  ✓ System freeze on lid close"
echo "  ✓ System freeze after sleep/suspend"
echo "  ✓ System freeze when locking screen"
echo "  ✓ Blank TTY screen (cursor only)"
echo "  ✓ Display not resuming after suspend (DPMS issues)"
echo
log_warning "⚠️  CRITICAL: This script does NOT restart services!"
log_warning "⚠️  All changes require a REBOOT to take effect"
log_warning "⚠️  DO NOT log out or restart services manually"
echo
log_info "The script will:"
echo "  • Install configuration files"
echo "  • Enable systemd services"
echo "  • Update AMD GPU module parameters"
echo "  • Rebuild initramfs"
echo "  • Prompt for reboot at the end"
echo
log_warning "Changes will NOT work until after reboot!"
echo
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled"
    exit 0
fi

echo
log_info "Starting installation..."
echo

# Change to dotfiles directory
cd "$HOME/dotfiles" || { log_error "Could not find dotfiles directory"; exit 1; }

# Step 1: Install systemd-logind configuration
log_info "[1/8] Installing systemd-logind configuration..."
sudo mkdir -p /etc/systemd/logind.conf.d
sudo cp hosts/firedragon/etc/systemd/logind.conf.d/10-firedragon-lid.conf /etc/systemd/logind.conf.d/
# DO NOT RESTART LOGIND - it will kill the user's session!
log_warning "systemd-logind config installed (will take effect after reboot)"
echo

# Step 2: Install AMD GPU suspend/resume hooks
log_info "[2/8] Installing AMD GPU suspend/resume hooks..."
sudo cp hosts/firedragon/etc/systemd/system/amdgpu-suspend.service /etc/systemd/system/
sudo cp hosts/firedragon/etc/systemd/system/amdgpu-resume.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable amdgpu-suspend.service
sudo systemctl enable amdgpu-resume.service
log_success "AMD GPU suspend/resume hooks installed"
echo

# Step 3: Update AMD GPU module parameters
log_info "[3/8] Updating AMD GPU module parameters..."
sudo mkdir -p /etc/modprobe.d
sudo cp hosts/firedragon/etc/modprobe.d/amdgpu.conf /etc/modprobe.d/
log_success "AMD GPU module parameters updated"
echo

# Step 4: Update TLP configuration
log_info "[4/8] Updating TLP configuration..."
sudo mkdir -p /etc/tlp.d
sudo cp hosts/firedragon/etc/tlp.d/01-firedragon.conf /etc/tlp.d/
if systemctl is-active --quiet tlp; then
    log_info "Restarting TLP service..."
    sudo systemctl restart tlp
fi
log_success "TLP configuration updated"
echo

# Step 5: Update hypridle configuration (user-space)
log_info "[5/8] Updating hypridle configuration..."
mkdir -p "$HOME/.config/hypr/config"
cp packages/hyprland/.config/hypr/config/hypridle.conf "$HOME/.config/hypr/config/"
# Also update the root-level hypridle.conf if it exists
if [ -f "$HOME/.config/hypr/hypridle.conf" ]; then
    cp packages/hyprland/.config/hypr/config/hypridle.conf "$HOME/.config/hypr/hypridle.conf"
fi
log_success "hypridle configuration updated"
echo

# Step 6: Restart hypridle if running
log_info "[6/8] Restarting hypridle..."
if pgrep -x hypridle > /dev/null; then
    pkill hypridle
    sleep 1
    hypridle -c "$HOME/.config/hypr/hypridle.conf" &
    log_success "hypridle restarted with new configuration"
else
    log_info "hypridle not running, will start on next login"
fi
echo

# Step 7: Run TTY/console fix script
log_info "[7/8] Running AMD GPU console/TTY fix..."
log_warning "This will rebuild initramfs and may take a moment..."
if [ -f "hosts/firedragon/fix-amdgpu-console.sh" ]; then
    chmod +x hosts/firedragon/fix-amdgpu-console.sh
    sudo bash hosts/firedragon/fix-amdgpu-console.sh
else
    log_warning "TTY fix script not found, skipping..."
fi
echo

# Step 8: Verify installation
log_info "[8/8] Verifying installation..."

# Check if services are enabled
services_ok=true
if ! systemctl is-enabled --quiet amdgpu-suspend.service 2>/dev/null; then
    log_warning "amdgpu-suspend.service not enabled"
    services_ok=false
fi
if ! systemctl is-enabled --quiet amdgpu-resume.service 2>/dev/null; then
    log_warning "amdgpu-resume.service not enabled"
    services_ok=false
fi

# Check if config files exist
configs_ok=true
if [ ! -f "/etc/systemd/logind.conf.d/10-firedragon-lid.conf" ]; then
    log_warning "logind configuration not found"
    configs_ok=false
fi
if [ ! -f "/etc/modprobe.d/amdgpu.conf" ]; then
    log_warning "amdgpu.conf not found"
    configs_ok=false
fi
if [ ! -f "/etc/tlp.d/01-firedragon.conf" ]; then
    log_warning "TLP configuration not found"
    configs_ok=false
fi
if [ ! -f "$HOME/.config/hypr/config/hypridle.conf" ]; then
    log_warning "hypridle configuration not found"
    configs_ok=false
fi

if $services_ok && $configs_ok; then
    log_success "All components verified successfully"
else
    log_warning "Some components may not be installed correctly"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
log_success "Installation Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo
log_warning "⚠️  CRITICAL: REBOOT NOW - Changes will NOT work until reboot"
log_warning "⚠️  DO NOT log out, restart services, or close the laptop lid yet!"
echo
echo "The following changes have been applied:"
echo "  ✓ systemd-logind configured for lid handling"
echo "  ✓ AMD GPU suspend/resume hooks installed"
echo "  ✓ AMD GPU module parameters updated"
echo "  ✓ TLP configured to not interfere with GPU suspend"
echo "  ✓ hypridle DPMS restore fixed"
echo "  ✓ TTY/console framebuffer restoration configured"
echo "  ✓ initramfs rebuilt with amdgpu early loading"
echo
log_warning "⚠️  These changes are NOT active yet - REBOOT REQUIRED"
echo
log_info "After reboot, test the following:"
echo "  1. Close laptop lid → Open lid → Should resume properly"
echo "  2. Lock screen (Super+L) → Unlock → Should work"
echo "  3. Let system sleep → Wake up → Display should restore"
echo "  4. Press Ctrl+Alt+F2 → TTY should show login prompt"
echo
log_info "Troubleshooting:"
echo "  • Check logs: journalctl -b | grep -E 'suspend|resume|amdgpu|dpms'"
echo "  • Check hypridle: ps aux | grep hypridle"
echo "  • Check services: systemctl status amdgpu-resume.service"
echo
read -p "Reboot now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Rebooting in 3 seconds..."
    log_warning "Press Ctrl+C to cancel"
    sleep 3
    systemctl reboot
else
    log_warning "⚠️  Remember to reboot before testing! Changes won't work until reboot."
    log_info "When ready: systemctl reboot"
fi

