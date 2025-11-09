#!/bin/bash
# Complete fix for Firedragon suspend/resume and TTY issues
# This script addresses ALL remaining issues from testing

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  🔧 Complete Firedragon Suspend/Resume Fix (AMD GPU + TTY)"
echo "═══════════════════════════════════════════════════════════════"
echo

log_warning "⚠️  CRITICAL REQUIREMENTS:"
log_warning "  1. This script will rebuild initramfs (takes 1-2 minutes)"
log_warning "  2. You MUST reboot after completion"
log_warning "  3. DO NOT restart services manually"
echo

read -p "Continue with complete fix? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled"
    exit 0
fi

echo
log_info "Starting comprehensive fix..."
echo

# =============================================================================
# STEP 1: AMD GPU Kernel Module Parameters
# =============================================================================

log_info "[1/6] Configuring AMD GPU kernel module parameters..."

sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null << 'EOF'
# AMD GPU power management options - Optimized for laptop suspend/resume
# Critical for preventing freeze on resume

# Enable all power management features
options amdgpu ppfeaturemask=0xffffffff

# Enable GPU recovery on crashes
options amdgpu gpu_recovery=1

# Enable Display Core (DC) for better display management
options amdgpu dc=1

# CRITICAL: Disable GPU reset on suspend (prevents hangs)
options amdgpu gpu_reset=0

# Enable runtime power management
options amdgpu runpm=1

# Set power management policy (auto for best balance)
options amdgpu dpm=1

# Disable audio codec power management (can cause resume issues)
options amdgpu audio=1

# Enable kernel mode setting early for TTY
options amdgpu modeset=1
EOF

log_success "AMD GPU module parameters configured"
echo

# =============================================================================
# STEP 2: Rebuild Initramfs (CRITICAL!)
# =============================================================================

log_info "[2/6] Rebuilding initramfs to load AMD GPU parameters..."
log_warning "⏳ This will take 1-2 minutes..."

# Detect initramfs tool
if command -v dracut > /dev/null; then
    sudo dracut --force --verbose
    log_success "Initramfs rebuilt with dracut"
elif command -v mkinitcpio > /dev/null; then
    sudo mkinitcpio -P
    log_success "Initramfs rebuilt with mkinitcpio"
else
    log_error "No initramfs tool found (dracut or mkinitcpio required)"
    exit 1
fi

echo

# =============================================================================
# STEP 3: AMD GPU Suspend/Resume Hooks (FIXED DEPENDENCIES)
# =============================================================================

log_info "[3/6] Installing AMD GPU suspend/resume hooks..."

# PRE-SUSPEND SERVICE (runs BEFORE suspend)
sudo tee /etc/systemd/system/amdgpu-suspend.service > /dev/null << 'EOF'
[Unit]
Description=AMD GPU Pre-Suspend Fix for Hyprland
Before=sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
User=root
RemainAfterExit=yes
ExecStart=/bin/sh -c 'echo "=== AMD GPU Pre-Suspend ===" >> /tmp/amdgpu-suspend.log'
ExecStart=/bin/sh -c 'date >> /tmp/amdgpu-suspend.log'
ExecStart=/bin/sh -c 'for card in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo "auto" > "$card" 2>/dev/null || true; done'
ExecStart=/bin/sh -c 'echo "GPU power state set to auto" >> /tmp/amdgpu-suspend.log'
ExecStart=/usr/bin/sync
ExecStart=/usr/bin/sleep 0.5

[Install]
WantedBy=sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

# POST-RESUME SERVICE (runs AFTER resume)
sudo tee /etc/systemd/system/amdgpu-resume.service > /dev/null << 'EOF'
[Unit]
Description=AMD GPU Post-Resume Fix for Hyprland
After=sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
User=root
RemainAfterExit=yes
ExecStart=/usr/bin/sleep 1
ExecStart=/bin/sh -c 'echo "=== AMD GPU Post-Resume ===" >> /tmp/amdgpu-resume.log'
ExecStart=/bin/sh -c 'date >> /tmp/amdgpu-resume.log'
ExecStart=/bin/sh -c 'for card in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo "auto" > "$card" 2>/dev/null || true; done'
ExecStart=/bin/sh -c 'echo "GPU power state restored" >> /tmp/amdgpu-resume.log'

[Install]
WantedBy=sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable amdgpu-suspend.service 2>/dev/null || log_warning "Could not enable amdgpu-suspend.service"
sudo systemctl enable amdgpu-resume.service 2>/dev/null || log_warning "Could not enable amdgpu-resume.service"

log_success "AMD GPU suspend/resume hooks installed and enabled"
echo

# =============================================================================
# STEP 4: TTY Console Restoration (NEW!)
# =============================================================================

log_info "[4/6] Installing TTY console restoration service..."

sudo tee /etc/systemd/system/amdgpu-console-restore.service > /dev/null << 'EOF'
[Unit]
Description=AMD GPU TTY Console Restore after Suspend
After=amdgpu-resume.service suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
User=root
RemainAfterExit=yes
ExecStart=/usr/bin/sleep 1
# Force TTY switch to reinitialize framebuffer
ExecStart=/bin/sh -c 'chvt 1 && sleep 0.3 && chvt 7'
ExecStart=/bin/sh -c 'echo "TTY console restored" >> /tmp/amdgpu-console.log'

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable amdgpu-console-restore.service 2>/dev/null || log_warning "Could not enable amdgpu-console-restore.service"

log_success "TTY console restoration service installed"
echo

# =============================================================================
# STEP 5: DPMS Fix for Hypridle (Enhanced)
# =============================================================================

log_info "[5/6] Verifying hypridle DPMS configuration..."

# Check if hypridle config has proper DPMS restore
if grep -q "after_sleep_cmd = hyprctl dispatch dpms on" ~/.config/hypr/hypridle.conf; then
    log_success "hypridle DPMS restore already configured"
else
    log_warning "hypridle config may need updating - check hypridle.conf"
fi

echo

# =============================================================================
# STEP 6: Create Verification Script
# =============================================================================

log_info "[6/6] Creating verification script..."

tee ~/dotfiles/hosts/firedragon/verify-suspend-fix.sh > /dev/null << 'EOF'
#!/bin/bash
# Verify suspend/resume fix is working

echo "═══════════════════════════════════════════════════════════════"
echo "  🔍 Suspend/Resume Fix Verification"
echo "═══════════════════════════════════════════════════════════════"
echo

echo "1️⃣  Checking kernel module parameters..."
if grep -q "amdgpu.modeset=1" /proc/cmdline; then
    echo "   ✅ amdgpu.modeset=1 loaded"
else
    echo "   ❌ amdgpu.modeset=1 NOT loaded (did you rebuild initramfs?)"
fi

if grep -q "options amdgpu gpu_reset=0" /etc/modprobe.d/amdgpu.conf; then
    echo "   ✅ amdgpu.conf configured"
else
    echo "   ❌ amdgpu.conf missing or incomplete"
fi

echo
echo "2️⃣  Checking systemd services..."
systemctl is-enabled amdgpu-suspend.service >/dev/null 2>&1 && echo "   ✅ amdgpu-suspend.service enabled" || echo "   ❌ amdgpu-suspend.service NOT enabled"
systemctl is-enabled amdgpu-resume.service >/dev/null 2>&1 && echo "   ✅ amdgpu-resume.service enabled" || echo "   ❌ amdgpu-resume.service NOT enabled"
systemctl is-enabled amdgpu-console-restore.service >/dev/null 2>&1 && echo "   ✅ amdgpu-console-restore.service enabled" || echo "   ❌ amdgpu-console-restore.service NOT enabled"

echo
echo "3️⃣  Checking GPU power state..."
GPU_STATE=$(cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null)
echo "   Current state: $GPU_STATE"
if [ "$GPU_STATE" = "auto" ]; then
    echo "   ✅ GPU power state is correct (auto)"
else
    echo "   ⚠️  GPU power state is not 'auto'"
fi

echo
echo "4️⃣  Checking recent suspend/resume logs..."
if [ -f /tmp/amdgpu-resume.log ]; then
    echo "   Last resume event:"
    tail -3 /tmp/amdgpu-resume.log | sed 's/^/   /'
else
    echo "   ⚠️  No resume logs yet (haven't suspended since reboot)"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  💡 Test Procedure:"
echo "═══════════════════════════════════════════════════════════════"
echo "  1. Test lock: loginctl lock-session"
echo "  2. Test suspend: systemctl suspend"
echo "  3. Test lid close: close laptop lid"
echo "  4. Test TTY: Ctrl+Alt+F2, then Ctrl+Alt+F7"
echo "═══════════════════════════════════════════════════════════════"
EOF

chmod +x ~/dotfiles/hosts/firedragon/verify-suspend-fix.sh

log_success "Verification script created: ~/dotfiles/hosts/firedragon/verify-suspend-fix.sh"
echo

# =============================================================================
# COMPLETION
# =============================================================================

echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ Complete Suspend/Resume Fix Installation Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo

log_warning "⚠️  CRITICAL NEXT STEPS:"
log_warning "  1. REBOOT NOW - changes require a reboot to take effect"
log_warning "  2. After reboot, run: ~/dotfiles/hosts/firedragon/verify-suspend-fix.sh"
log_warning "  3. Then test suspend/resume and TTY"
echo

log_info "📝 Service logs will be written to:"
log_info "   - /tmp/amdgpu-suspend.log"
log_info "   - /tmp/amdgpu-resume.log"
log_info "   - /tmp/amdgpu-console.log"
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



