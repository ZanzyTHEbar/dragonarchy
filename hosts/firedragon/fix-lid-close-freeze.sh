#!/bin/bash
#
# Fix Lid Close Freeze Issue on FireDragon
#
# This script addresses the lid close suspend/resume freeze by:
# 1. Installing the missing amdgpu-console-restore.service
# 2. Verifying all AMD GPU suspend/resume services are enabled
# 3. Checking hypridle configuration for proper DPMS management
# 4. Rebuilding initramfs if needed
# 5. Verifying logind.conf is properly configured
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
echo "  🔧 FireDragon Lid Close Freeze Fix"
echo "═══════════════════════════════════════════════════════════════"
echo

# Check if we're on firedragon
if [[ "$(hostname)" != "firedragon" ]]; then
    log_warning "This script is designed for the firedragon host"
    log_warning "Current host: $(hostname)"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 1. Install/update AMD GPU systemd services
log_info "Step 1: Installing AMD GPU suspend/resume services..."

DOTFILES_DIR="${HOME}/dotfiles"
SERVICES_SRC="${DOTFILES_DIR}/hosts/firedragon/etc/systemd/system"
SERVICES_DEST="/etc/systemd/system"

if [[ ! -d "$SERVICES_SRC" ]]; then
    log_error "Services source directory not found: $SERVICES_SRC"
    exit 1
fi

# Copy all three services
for service in amdgpu-suspend.service amdgpu-resume.service amdgpu-console-restore.service; do
    if [[ -f "${SERVICES_SRC}/${service}" ]]; then
        log_info "Installing ${service}..."
        sudo cp -f "${SERVICES_SRC}/${service}" "${SERVICES_DEST}/"
        log_success "${service} installed"
    else
        log_error "${service} not found in ${SERVICES_SRC}"
        exit 1
    fi
done

# Reload systemd and enable services
log_info "Reloading systemd daemon..."
sudo systemctl daemon-reload

log_info "Enabling AMD GPU services..."
sudo systemctl enable amdgpu-suspend.service
sudo systemctl enable amdgpu-resume.service
sudo systemctl enable amdgpu-console-restore.service
log_success "All AMD GPU services enabled"

# 2. Verify logind.conf
log_info "Step 2: Verifying systemd-logind configuration..."

LOGIND_CONF="${DOTFILES_DIR}/hosts/firedragon/etc/systemd/logind.conf.d/10-firedragon-lid.conf"
LOGIND_DEST="/etc/systemd/logind.conf.d/10-firedragon-lid.conf"

if [[ -f "$LOGIND_CONF" ]]; then
    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo cp -f "$LOGIND_CONF" "$LOGIND_DEST"
    log_success "logind.conf updated"
else
    log_warning "logind.conf not found in dotfiles"
fi

# 3. Check AMD GPU modprobe configuration
log_info "Step 3: Verifying AMD GPU kernel module configuration..."

AMDGPU_CONF="${DOTFILES_DIR}/hosts/firedragon/etc/modprobe.d/amdgpu.conf"
AMDGPU_DEST="/etc/modprobe.d/amdgpu.conf"

if [[ -f "$AMDGPU_CONF" ]]; then
    sudo mkdir -p /etc/modprobe.d
    sudo cp -f "$AMDGPU_CONF" "$AMDGPU_DEST"
    log_success "amdgpu.conf updated"
    
    # Check if initramfs needs rebuilding
    if ! grep -q "amdgpu.modeset=1" /proc/cmdline 2>/dev/null; then
        log_warning "Kernel module parameters not loaded yet"
        log_info "Rebuilding initramfs..."
        
        if command -v mkinitcpio >/dev/null 2>&1; then
            sudo mkinitcpio -P
            log_success "Initramfs rebuilt"
        elif command -v dracut >/dev/null 2>&1; then
            sudo dracut --force --verbose
            log_success "Initramfs rebuilt"
        else
            log_error "No initramfs tool found (mkinitcpio or dracut)"
            exit 1
        fi
    else
        log_success "Kernel module parameters already loaded"
    fi
else
    log_warning "amdgpu.conf not found in dotfiles"
fi

# 4. Check hypridle configuration
log_info "Step 4: Checking hypridle configuration..."

HYPRIDLE_CONF="${HOME}/.config/hypr/hypridle.conf"

if [[ -f "$HYPRIDLE_CONF" ]]; then
    if grep -q "after_sleep_cmd.*dpms on" "$HYPRIDLE_CONF"; then
        log_success "hypridle has correct after_sleep_cmd"
    else
        log_warning "hypridle missing 'after_sleep_cmd = hyprctl dispatch dpms on'"
        log_info "You may need to add this to your hypridle.conf:"
        echo "    listener {"
        echo "        on-resume = hyprctl dispatch dpms on"
        echo "    }"
    fi
    
    if grep -q "before_sleep_cmd.*loginctl lock-session" "$HYPRIDLE_CONF"; then
        log_success "hypridle has correct before_sleep_cmd"
    else
        log_warning "hypridle missing 'before_sleep_cmd = loginctl lock-session'"
    fi
else
    log_warning "hypridle.conf not found at ${HYPRIDLE_CONF}"
    log_info "Make sure hypridle is configured with proper DPMS management"
fi

# 5. Verify TLP configuration doesn't interfere
log_info "Step 5: Checking TLP configuration..."

TLP_CONF="${DOTFILES_DIR}/hosts/firedragon/etc/tlp.d/01-firedragon.conf"
TLP_DEST="/etc/tlp.d/01-firedragon.conf"

if [[ -f "$TLP_CONF" ]]; then
    sudo mkdir -p /etc/tlp.d
    sudo cp -f "$TLP_CONF" "$TLP_DEST"
    log_success "TLP configuration updated"
    
    # Verify runtime PM settings
    if grep -q "RUNTIME_PM_ON_AC=auto" "$TLP_DEST" && grep -q "RUNTIME_PM_ON_BAT=auto" "$TLP_DEST"; then
        log_success "TLP runtime PM correctly set to 'auto'"
    else
        log_warning "TLP runtime PM may need adjustment"
    fi
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ Fix Applied Successfully"
echo "═══════════════════════════════════════════════════════════════"
echo
log_warning "⚠️  REBOOT REQUIRED for changes to take effect"
log_warning "⚠️  Do NOT restart services manually"
log_warning "⚠️  Do NOT log out before reboot"
echo
log_info "After reboot, run the verification script:"
log_info "    ${DOTFILES_DIR}/hosts/firedragon/verify-suspend-fix.sh"
echo
log_info "Then test in this order:"
log_info "    1. Lock screen: loginctl lock-session"
log_info "    2. Manual suspend: systemctl suspend"
log_info "    3. Lid close: close laptop lid for 5+ seconds"
log_info "    4. TTY test: Ctrl+Alt+F2, then Ctrl+Alt+F7"
echo
echo "═══════════════════════════════════════════════════════════════"

read -p "Reboot now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Rebooting..."
    sudo reboot
fi

