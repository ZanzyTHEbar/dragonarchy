#!/bin/bash
# Update kernel cmdline for AMD GPU suspend/resume fix
# For systems using /etc/kernel/cmdline (unified kernel images)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  🔧 Update Kernel Cmdline for AMD GPU Suspend/Resume Fix"
echo "═══════════════════════════════════════════════════════════════"
echo

log_info "Current kernel cmdline:"
cat /etc/kernel/cmdline
echo

log_info "Required AMD GPU parameters for suspend/resume:"
echo "  • amdgpu.gpu_reset=0    - Prevent GPU reset hangs on suspend"
echo "  • amdgpu.runpm=1        - Enable runtime power management"
echo "  • amdgpu.modeset=1      - Early kernel mode setting (for TTY)"
echo "  • amdgpu.dpm=1          - Dynamic power management"
echo

log_warning "⚠️  This will:"
log_warning "  1. Backup current /etc/kernel/cmdline"
log_warning "  2. Add missing AMD GPU parameters"
log_warning "  3. Rebuild unified kernel image with mkinitcpio"
log_warning "  4. Require a REBOOT"
echo

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Update cancelled"
    exit 0
fi

echo
log_info "[1/4] Backing up current kernel cmdline..."
sudo cp /etc/kernel/cmdline /etc/kernel/cmdline.bak.$(date +%Y%m%d-%H%M%S)
log_success "Backup created"
echo

log_info "[2/4] Updating kernel cmdline with AMD GPU parameters..."

# Read current cmdline
CURRENT_CMDLINE=$(cat /etc/kernel/cmdline)

# Add missing parameters if not already present
NEW_CMDLINE="$CURRENT_CMDLINE"

# Check and add each parameter
if ! echo "$CURRENT_CMDLINE" | grep -q "amdgpu.gpu_reset="; then
    NEW_CMDLINE="$NEW_CMDLINE amdgpu.gpu_reset=0"
    log_info "  + Added: amdgpu.gpu_reset=0"
fi

if ! echo "$CURRENT_CMDLINE" | grep -q "amdgpu.runpm="; then
    NEW_CMDLINE="$NEW_CMDLINE amdgpu.runpm=1"
    log_info "  + Added: amdgpu.runpm=1"
fi

if ! echo "$CURRENT_CMDLINE" | grep -q "amdgpu.modeset="; then
    NEW_CMDLINE="$NEW_CMDLINE amdgpu.modeset=1"
    log_info "  + Added: amdgpu.modeset=1"
fi

if ! echo "$CURRENT_CMDLINE" | grep -q "amdgpu.dpm="; then
    NEW_CMDLINE="$NEW_CMDLINE amdgpu.dpm=1"
    log_info "  + Added: amdgpu.dpm=1"
fi

# Write updated cmdline
echo "$NEW_CMDLINE" | sudo tee /etc/kernel/cmdline > /dev/null

log_success "Kernel cmdline updated"
echo
log_info "New kernel cmdline:"
cat /etc/kernel/cmdline
echo

log_info "[3/4] Rebuilding unified kernel image with mkinitcpio..."
log_warning "⏳ This will take 1-2 minutes..."
echo

sudo mkinitcpio -P

log_success "Kernel image rebuilt"
echo

log_info "[4/4] Verifying changes..."
echo

# Show what will be loaded on next boot
log_info "Kernel cmdline that will be used on next boot:"
cat /etc/kernel/cmdline
echo

log_info "Checking for backup files:"
ls -lh /etc/kernel/cmdline.bak.* 2>/dev/null || log_info "No backups found"
echo

echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ Kernel Cmdline Update Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo

log_warning "⚠️  CRITICAL NEXT STEPS:"
log_warning "  1. REBOOT NOW - changes require a reboot to take effect"
log_warning "  2. After reboot, run: ~/dotfiles/hosts/firedragon/verify-suspend-fix.sh"
log_warning "  3. You should see: '✅ amdgpu.modeset=1 loaded'"
log_warning "  4. Then test suspend/resume and TTY"
echo

log_info "📝 If something goes wrong, restore from backup:"
log_info "   sudo cp /etc/kernel/cmdline.bak.XXXXXX /etc/kernel/cmdline"
log_info "   sudo mkinitcpio -P"
log_info "   reboot"
echo

read -p "Reboot now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Rebooting in 5 seconds..."
    sleep 5
    systemctl reboot
else
    log_warning "⚠️  REMEMBER TO REBOOT! Changes won't work until reboot."
fi


