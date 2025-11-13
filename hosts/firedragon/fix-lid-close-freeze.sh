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
LOG_LIB="${DOTFILES_DIR}/scripts/lib/logging.sh"
BOOT_LIB="${DOTFILES_DIR}/scripts/lib/bootloader.sh"
FORCE_INITRAMFS="${FORCE_INITRAMFS:-0}"

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
NEED_INITRAMFS_REBUILD=0

if [[ -f "$AMDGPU_CONF" ]]; then
    sudo mkdir -p /etc/modprobe.d
    if sudo test -f "$AMDGPU_DEST"; then
        if sudo cmp -s "$AMDGPU_CONF" "$AMDGPU_DEST"; then
            log_info "amdgpu.conf already up to date"
        else
            log_info "Updating amdgpu.conf..."
            sudo cp -f "$AMDGPU_CONF" "$AMDGPU_DEST"
            NEED_INITRAMFS_REBUILD=1
            log_success "amdgpu.conf installed"
        fi
    else
        log_info "Installing amdgpu.conf..."
        sudo cp -f "$AMDGPU_CONF" "$AMDGPU_DEST"
        NEED_INITRAMFS_REBUILD=1
        log_success "amdgpu.conf installed"
    fi

    if grep -qw "amdgpu.modeset=1" /proc/cmdline; then
        log_success "Kernel parameter amdgpu.modeset=1 already active in current boot"
    else
        log_warning "Kernel parameter amdgpu.modeset=1 not active in current boot"
        LIMINE_DEFAULT_CONF="/etc/default/limine"
        if sudo test -f "$LIMINE_DEFAULT_CONF"; then
            if sudo grep -q "amdgpu.modeset=1" "$LIMINE_DEFAULT_CONF" >/dev/null 2>&1; then
                log_info "/etc/default/limine already includes amdgpu.modeset=1"
            else
                log_info "Adding amdgpu.modeset=1 to /etc/default/limine kernel defaults..."
                if sudo perl -0pi -e 's/(KERNEL_CMDLINE\[default\]\+=\"[^\"]*)(\")/$1 amdgpu.modeset=1$2/' "$LIMINE_DEFAULT_CONF"; then
                    log_success "Updated /etc/default/limine with amdgpu.modeset=1"
                    NEED_INITRAMFS_REBUILD=1
                else
                    log_error "Failed to update /etc/default/limine"
                fi
            fi
        else
            log_warning "/etc/default/limine not found; skipping kernel default update"
        fi
        if [[ -f "$BOOT_LIB" ]]; then
            log_info "Ensuring bootloader configuration includes amdgpu.modeset=1..."
            if sudo env LOG_LIB="$LOG_LIB" BOOT_LIB="$BOOT_LIB" bash -c '
                set -e
                if [[ -f "$LOG_LIB" ]]; then
                    # shellcheck disable=SC1091
                    source "$LOG_LIB"
                fi
                # shellcheck disable=SC1091
                source "$BOOT_LIB"
                boot_append_kernel_params "amdgpu.modeset=1"
                boot_rebuild_if_changed
                BOOT_PARAMS_CHANGED=false
                boot_append_kernel_params "amdgpu.modeset=1"
            '; then
                log_success "Bootloader configuration updated with amdgpu.modeset=1"
                log_warning "Reboot required to load amdgpu.modeset=1 on the next boot"
            else
                log_error "Failed to update bootloader with amdgpu.modeset=1; please add manually"
            fi
        else
            log_warning "Bootloader helper not found at $BOOT_LIB; skipping kernel parameter update"
        fi
    fi
    
    if [[ $FORCE_INITRAMFS -eq 1 ]]; then
        log_info "Force initramfs rebuild requested via FORCE_INITRAMFS=1"
        NEED_INITRAMFS_REBUILD=1
    fi
    
    if [[ $NEED_INITRAMFS_REBUILD -eq 1 ]]; then
        log_info "Rebuilding initramfs to include updated amdgpu.conf..."
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
        log_info "Initramfs rebuild not required (amdgpu.conf unchanged)"
    fi
else
    log_warning "amdgpu.conf not found in dotfiles"
fi

# 4. Check hypridle configuration
log_info "Step 4: Checking hypridle configuration..."

HYPRIDLE_CONF="${HOME}/.config/hypr/hypridle.conf"

if [[ -f "$HYPRIDLE_CONF" ]]; then
    if awk '
        BEGIN { found = 0 }
        /^[[:space:]]*#/ { next }
        {
            line = $0
            sub(/#.*/, "", line)
            gsub(/["'\''`]/, "", line)
            gsub(/^[[:space:]]+/, "", line)
            gsub(/[[:space:]]+$/, "", line)
            n = split(line, tokens, /[[:space:]]+/)
            if (n == 0) {
                next
            }
            if (tokens[1] == "" && n > 1) {
                # Shift tokens left to skip empty leading entry
                for (i = 1; i < n; i++) {
                    tokens[i] = tokens[i + 1]
                }
                n = n - 1
            }
            if (n > 0 && tokens[1] == "after_sleep_cmd") {
                for (i = 2; i <= n; i++) {
                    if (tokens[i] == "=") {
                        continue
                    }
                    if (tokens[i] == "dpms" && i < n && tokens[i + 1] == "on") {
                        found = 1
                        break
                    }
                }
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$HYPRIDLE_CONF"; then
        log_success "hypridle has correct after_sleep_cmd"
    else
        log_warning "hypridle missing or misconfigured 'after_sleep_cmd' that restores DPMS"
        log_info "Example hypridle listener:"
        echo "    listener {"
        echo "        on-resume = hyprctl dispatch dpms on"
        echo "    }"
    fi

    if awk '
        BEGIN { found = 0 }
        /^[[:space:]]*#/ { next }
        {
            line = $0
            sub(/#.*/, "", line)
            gsub(/["'\''`]/, "", line)
            gsub(/^[[:space:]]+/, "", line)
            gsub(/[[:space:]]+$/, "", line)
            n = split(line, tokens, /[[:space:]]+/)
            if (n == 0) {
                next
            }
            if (tokens[1] == "" && n > 1) {
                for (i = 1; i < n; i++) {
                    tokens[i] = tokens[i + 1]
                }
                n = n - 1
            }
            if (n > 0 && tokens[1] == "before_sleep_cmd") {
                have_loginctl = 0
                have_lock = 0
                for (i = 2; i <= n; i++) {
                    if (tokens[i] == "=") {
                        continue
                    }
                    if (tokens[i] == "loginctl") {
                        have_loginctl = 1
                    }
                    if (tokens[i] ~ /^lock-session$/) {
                        have_lock = 1
                    }
                    if (have_loginctl && have_lock) {
                        found = 1
                        break
                    }
                }
            }
        }
        END { exit(found ? 0 : 1) }
    ' "$HYPRIDLE_CONF"; then
        log_success "hypridle has correct before_sleep_cmd"
    else
        log_warning "hypridle missing or misconfigured 'before_sleep_cmd' to lock the session"
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

