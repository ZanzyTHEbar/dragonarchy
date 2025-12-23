#!/bin/bash
#
# FireDragon Host-Specific Setup
#
# This script configures the FireDragon laptop with AMD chipset and Radeon graphics.
# Optimized for mobile performance, battery life, and thermal management.

set -e

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"
BOOT_LIB="${PROJECT_ROOT}/scripts/lib/bootloader.sh"
STATE_LIB="${PROJECT_ROOT}/scripts/lib/install-state.sh"

# Source utilities
# shellcheck disable=SC1091
source "$LOG_LIB"
# shellcheck disable=SC1091
source "$BOOT_LIB"
# shellcheck disable=SC1091
source "$STATE_LIB"

log_info "Running setup for FireDragon laptop..."

# Handle --reset flag to force re-run all steps
if [[ "${1:-}" == "--reset" ]]; then
    reset_all_steps
    log_info "Installation state reset. All steps will be re-run."
    echo
fi
echo

# Install laptop-specific packages
setup_firedragon_packages() {
    log_info "Installing laptop-specific packages..."
    
    # Remove conflicting package FIRST before attempting to install TLP
    if pacman -Qi power-profiles-daemon &>/dev/null; then
        log_info "Removing conflicting power-profiles-daemon..."
        sudo systemctl stop power-profiles-daemon.service 2>/dev/null || true
        sudo systemctl disable power-profiles-daemon.service 2>/dev/null || true
        sudo pacman -Rdd --noconfirm power-profiles-daemon || log_warning "Failed to remove power-profiles-daemon"
    fi
    
    local laptop_packages=(
        "tlp"                    # Advanced power management
        "tlp-rdw"                # TLP radio device wizard
        "powertop"               # Power consumption monitor
        "acpid"                  # ACPI daemon for power events
        "acpi"                   # ACPI utilities
        "acpi_call"              # ACPI call module
        "lm_sensors"             # Hardware monitoring
        "thermald"               # Thermal daemon
        "brightnessctl"          # Brightness control
        "auto-cpufreq"           # CPU frequency scaling
        "laptop-detect"          # Laptop detection utility
        "libinput"               # Input device management
        "libinput-gestures"      # Gesture recognition library (optional)
        "asusctl"                # ASUS EC/keyboard controls
        "asus-nb-ctrl"           # Additional ASUS laptop integration
    )
    
    local amd_packages=(
        "mesa"                   # AMD graphics drivers
        "vulkan-radeon"          # Vulkan support for AMD
        "libva-mesa-driver"      # VA-API support
        "mesa-vdpau"             # VDPAU support
        "xf86-video-amdgpu"      # AMD GPU DDX driver
        "amd-ucode"              # AMD microcode
        "corectrl"               # AMD GPU/CPU control GUI
        "radeontop"              # AMD GPU monitor
    )
    
    local gesture_build_deps=(
        "glm"                    # OpenGL mathematics library (for hyprgrass)
        "cmake"                  # CMake build system (needed by wf-touch to find GLM)
        "meson"                  # Build system
        "ninja"                  # Build tool
        "git"                    # Version control (for plugin sources)
    )
    
    for package in "${laptop_packages[@]}" "${amd_packages[@]}" "${gesture_build_deps[@]}"; do
        if ! pacman -Qi "$package" &>/dev/null; then
            log_info "Installing $package..."
            sudo pacman -S --noconfirm --needed "$package" || log_warning "Failed to install $package"
        else
            log_success "$package already installed"
        fi
    done
    
    log_success "Laptop-specific packages installed"
}

setup_asus_ec_tools() {
    log_info "Configuring ASUS EC integration..."

    if systemctl list-unit-files | grep -q '^asusd\.service'; then
        sudo systemctl enable --now asusd.service 2>/dev/null || true
    fi

    if command_exists asusctl; then
        if asusctl profile -n Balanced >/dev/null 2>&1; then
            log_success "Set ASUS performance profile to Balanced"
        else
            log_warning "Failed to set ASUS profile via asusctl"
        fi
    else
        log_warning "asusctl not found; skipping profile configuration"
    fi
}

# Setup AMD-specific configurations
setup_amd_graphics() {
    log_info "Configuring AMD Radeon graphics..."
    
    # Create AMD GPU configuration
    sudo mkdir -p /etc/X11/xorg.conf.d
    
    sudo tee /etc/X11/xorg.conf.d/20-amdgpu.conf > /dev/null << 'EOF'
Section "Device"
    Identifier "AMD Radeon"
    Driver "amdgpu"
    Option "TearFree" "true"
    Option "DRI" "3"
    Option "VariableRefresh" "true"
EndSection
EOF
    
    # Enable AMD GPU power management with suspend/resume fixes
    sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null << 'EOF'
# AMD GPU power management options - Optimized for laptop suspend/resume
# ppfeaturemask enables all power management features
options amdgpu ppfeaturemask=0xffffffff
# Enable GPU recovery on crashes
options amdgpu gpu_recovery=1
# Enable Display Core (DC) for better power management
options amdgpu dc=1
# Disable GPU reset on suspend (prevents hangs)
options amdgpu gpu_reset=0
# Enable runtime power management
options amdgpu runpm=1
# Set power management policy (auto for best balance)
options amdgpu dpm=1
# Disable audio codec power management (can cause resume issues)
options amdgpu audio=1
EOF
    
    # AMD microcode is handled by the amd-ucode package, not as a kernel module
    # The package installs /boot/amd-ucode.img which bootloaders load automatically
    log_info "AMD microcode package installed - bootloader will load it automatically"
    
    log_success "AMD graphics configured"
}

# Setup power management with TLP
setup_power_management() {
    log_info "Setting up TLP power management..."
    
    if command_exists tlp; then
        log_info "Configuring TLP services..."
        # Mask conflicting systemd services
        sudo systemctl mask systemd-rfkill.service 2>/dev/null || true
        sudo systemctl mask systemd-rfkill.socket 2>/dev/null || true
        
        # Enable TLP services
        sudo systemctl enable tlp.service 2>/dev/null || true
        sudo systemctl enable tlp-sleep.service 2>/dev/null || true
        
        # Create TLP configuration optimized for AMD laptop
        sudo tee /etc/tlp.d/01-firedragon.conf > /dev/null << 'EOF'
# FireDragon TLP Configuration - AMD Laptop Optimized
# Updated to fix suspend/resume issues

# CPU Energy Performance Policies
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# AMD P-State EPP (Energy Performance Preference)
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# CPU Min/Max Performance
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=50

# AMD Radeon GPU Power Management
# CRITICAL FIX: Don't force GPU state during suspend/resume
# Let amdgpu driver handle power states automatically
RADEON_DPM_PERF_LEVEL_ON_AC=auto
RADEON_DPM_PERF_LEVEL_ON_BAT=auto
RADEON_DPM_STATE_ON_AC=performance
RADEON_DPM_STATE_ON_BAT=battery
RADEON_POWER_PROFILE_ON_AC=default
RADEON_POWER_PROFILE_ON_BAT=low

# Platform Profile
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power

# WiFi Power Saving
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# PCIe Active State Power Management
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave

# USB Auto-suspend
USB_AUTOSUSPEND=1
USB_EXCLUDE_AUDIO=1
USB_EXCLUDE_BTUSB=1
USB_EXCLUDE_PHONE=0
USB_EXCLUDE_PRINTER=1
USB_EXCLUDE_WWAN=0

# Runtime Power Management
# CRITICAL FIX: Use 'auto' for both AC and battery to let kernel manage properly
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto

# Battery thresholds (if supported)
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80

# Disk settings
DISK_DEVICES="nvme0n1"
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"

# SATA link power management
SATA_LINKPWR_ON_AC="med_power_with_dipm max_performance"
SATA_LINKPWR_ON_BAT="min_power"

# Audio power saving
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y

# CRITICAL FIX: Restore devices on wakeup
# Ensure TLP doesn't prevent GPU from waking up properly
RESTORE_DEVICE_STATE_ON_STARTUP=1
EOF
        
        log_success "TLP configured for AMD laptop"
    else
        log_warning "TLP not installed, skipping power management setup"
    fi
    
    # Setup acpid for power events
    if command_exists acpid; then
        sudo systemctl enable acpid.service
        log_success "ACPI daemon enabled"
    fi
    
    # Configure thermald for thermal management
    if command_exists thermald; then
        sudo systemctl enable thermald.service
        log_success "Thermald enabled"
    fi
}

# Setup wireless and networking
setup_networking() {
    log_info "Setting up wireless and networking..."
    
    # Enable NetworkManager
    if command_exists nmcli; then
        if ! systemctl is-enabled NetworkManager.service &>/dev/null; then
            sudo systemctl enable NetworkManager.service
            log_success "NetworkManager enabled"
        else
            log_info "NetworkManager already enabled"
        fi
    fi
    
    # Enable Bluetooth
    if command_exists bluetoothctl; then
        if ! systemctl is-enabled bluetooth.service &>/dev/null; then
            sudo systemctl enable bluetooth.service
            log_success "Bluetooth enabled"
        else
            log_info "Bluetooth already enabled"
        fi
    fi
    
    # Install NetBird for secure networking
    if ! is_step_completed "firedragon-install-netbird"; then
        log_info "Installing NetBird VPN..."
        bash "$HOME/dotfiles/scripts/utilities/netbird-install.sh"
        mark_step_completed "firedragon-install-netbird"
    else
        log_info "NetBird already installed"
    fi
    
    # Copy host-specific system configs (DNS)
    if ! is_step_completed "firedragon-copy-system-configs"; then
        log_info "Copying host-specific system configs (DNS)..."
        if copy_dir_if_changed "$HOME/dotfiles/hosts/firedragon/etc/" /etc/; then
            log_success "System configs updated"
            mark_step_completed "firedragon-copy-system-configs"
            # Reset DNS restart step since configs changed
            reset_step "firedragon-restart-resolved"
        else
            log_info "System configs unchanged"
            mark_step_completed "firedragon-copy-system-configs"
        fi
    else
        # Check if configs need updating even if step was completed
        if copy_dir_if_changed "$HOME/dotfiles/hosts/firedragon/etc/" /etc/; then
            log_info "System configs updated (configs changed)"
            reset_step "firedragon-restart-resolved"
        else
            log_info "System configs already applied"
        fi
    fi
    
    # Apply DNS changes (only if configs changed or first time)
    if ! is_step_completed "firedragon-restart-resolved"; then
        log_info "Restarting systemd-resolved to apply DNS changes..."
        if restart_if_running systemd-resolved; then
            log_success "systemd-resolved restarted"
        fi
        mark_step_completed "firedragon-restart-resolved"
    else
        log_info "DNS configuration already applied"
    fi
    
    log_success "Networking configured (NetBird VPN + Custom DNS)"
}

# Setup display and touchpad
setup_display_input() {
    log_info "Setting up display and input devices..."
    
    # Create libinput configuration for touchpad with gesture support
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee /etc/X11/xorg.conf.d/30-touchpad.conf > /dev/null << 'EOF'
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "TappingButtonMap" "lrm"
    Option "NaturalScrolling" "true"
    Option "ScrollMethod" "twofinger"
    Option "HorizontalScrolling" "true"
    Option "DisableWhileTyping" "true"
    Option "AccelProfile" "adaptive"
    Option "AccelSpeed" "0.3"
    # Enable gesture support
    Option "SendEventsMode" "enabled"
    Option "MiddleEmulation" "off"
    Option "TappingDrag" "on"
    Option "DragLock" "off"
EndSection
EOF
    
    # Verify touchpad has multi-touch support
    log_info "Verifying touchpad capabilities..."
    if command_exists libinput; then
        log_info "Checking for touchpad devices..."
        if sudo libinput list-devices | grep -q "Touchpad"; then
            log_success "Touchpad detected with libinput support"
        else
            log_warning "No touchpad detected - may not be needed for desktop systems"
        fi
    fi
    
    log_success "Touchpad configuration created with gesture support"
}

# Setup battery monitoring
setup_battery_monitoring() {
    log_info "Setting up battery monitoring..."
    
    # Create battery status script
    mkdir -p "$HOME/.local/bin"
    
    cat > "$HOME/.local/bin/battery-status" << 'EOF'
#!/bin/bash
# Battery status script for firedragon

BAT_PATH="/sys/class/power_supply/BAT0"
AC_PATH="/sys/class/power_supply/AC"

if [[ -f "$BAT_PATH/capacity" ]]; then
    CAPACITY=$(cat "$BAT_PATH/capacity")
    STATUS=$(cat "$BAT_PATH/status")
    
    echo "Battery: ${CAPACITY}% (${STATUS})"
    
    if [[ -f "$AC_PATH/online" ]]; then
        AC_ONLINE=$(cat "$AC_PATH/online")
        if [[ "$AC_ONLINE" == "1" ]]; then
            echo "Power: AC Connected"
        else
            echo "Power: On Battery"
        fi
    fi
    
    # Show time remaining if available
    if command -v upower >/dev/null 2>&1; then
        upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -E "time to|energy-rate"
    fi
else
    echo "No battery found"
fi
EOF
    
    chmod +x "$HOME/.local/bin/battery-status"
    
    # Check if battery-monitor timer exists from hardware package
    if systemctl --user list-unit-files | grep -q "battery-monitor.timer"; then
        systemctl --user enable battery-monitor.timer 2>/dev/null || true
        log_info "Battery monitor timer enabled"
    else
        log_info "Battery monitoring script installed at ~/.local/bin/battery-status"
        log_info "Run 'battery-status' to check battery info"
    fi
    
    log_success "Battery monitoring configured"
}

# Create Hyprland host-specific configuration for laptops
setup_hyprland_host_config() {
    log_info "Creating Hyprland laptop-specific configuration..."
    mkdir -p "$HOME/.config/hypr/config"
    
    # Only create if it doesn't exist or isn't a symlink (managed by stow)
    if [[ ! -e "$HOME/.config/hypr/config/host-config.conf" ]] || [[ ! -L "$HOME/.config/hypr/config/host-config.conf" ]]; then
        log_info "Creating host-config.conf for laptop..."
        cat > "$HOME/.config/hypr/config/host-config.conf" << 'EOF'
# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃              FireDragon Laptop-Specific Configuration       ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
# This file is created by the FireDragon host setup
# It sources laptop-specific configurations like touchpad gestures

# Enable touchpad gesture support
source = ~/.config/hypr/config/gestures.conf

# You can add other laptop-specific Hyprland settings here
# For example:
# - Laptop-specific monitor configurations
# - Battery-aware rules
# - Touch screen settings
EOF
    else
        log_info "host-config.conf already exists (managed by stow or previous run)"
    fi
    
    log_success "FireDragon-specific configuration created"
}

# Setup laptop-specific optimizations
setup_laptop_optimizations() {
    log_info "Setting up laptop optimizations..."
    
    # Reduce swappiness for laptop use with SSD
    sudo tee /etc/sysctl.d/99-laptop-swappiness.conf > /dev/null << 'EOF'
# Reduce swap usage (better for battery and SSD life)
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
    
    # Setup laptop mode for disk
    sudo tee /etc/sysctl.d/99-laptop-mode.conf > /dev/null << 'EOF'
# Laptop mode for better power management
vm.laptop_mode=5
vm.dirty_writeback_centisecs=6000
EOF
    
    # Create udev rules for power management
    sudo tee /etc/udev/rules.d/50-powersave.rules > /dev/null << 'EOF'
# PCI Runtime PM
ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"

# USB Runtime PM
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"

# SATA power management
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="med_power_with_dipm"
EOF
    
    log_success "Laptop optimizations configured"
}

# Setup corectrl for AMD GPU/CPU control
setup_corectrl() {
    log_info "Setting up CoreCtrl for AMD control..."
    
    if command_exists corectrl; then
        # Add polkit rule for CoreCtrl
        sudo tee /etc/polkit-1/rules.d/90-corectrl.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.corectrl.helper.init" ||
         action.id == "org.corectrl.helperkiller.init") &&
        subject.local == true &&
        subject.active == true &&
        subject.isInGroup("wheel")) {
            return polkit.Result.YES;
    }
});
EOF
        
        log_success "CoreCtrl polkit rules configured"
        log_info "You can start CoreCtrl from your application menu"
    else
        log_warning "CoreCtrl not installed"
    fi
}

# Setup suspend/resume fixes for AMD GPU and display
setup_suspend_resume_fixes() {
    log_info "Setting up suspend/resume and lock screen fixes..."
    
    # 1. Configure systemd-logind for lid handling
    log_info "Configuring systemd-logind for lid switch handling..."
    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo cp -f "$HOME/dotfiles/hosts/firedragon/etc/systemd/logind.conf.d/10-firedragon-lid.conf" /etc/systemd/logind.conf.d/ 2>/dev/null || {
        log_warning "Could not copy logind config from dotfiles, creating directly..."
        sudo tee /etc/systemd/logind.conf.d/10-firedragon-lid.conf > /dev/null << 'EOF'
# FireDragon Laptop - systemd-logind Configuration
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
HandlePowerKey=suspend
HandleSuspendKey=suspend
HandleHibernateKey=ignore
IdleAction=ignore
IdleActionSec=30min
InhibitDelayMaxSec=5
KillUserProcesses=no
RemoveIPC=yes
EOF
    }
    
    # 2. Install AMD GPU suspend/resume systemd services
    log_info "Installing AMD GPU suspend/resume hooks..."
    sudo cp -f "$HOME/dotfiles/hosts/firedragon/etc/systemd/system/amdgpu-suspend.service" /etc/systemd/system/ 2>/dev/null || {
        log_warning "amdgpu-suspend.service not found in dotfiles, skipping..."
    }
    sudo cp -f "$HOME/dotfiles/hosts/firedragon/etc/systemd/system/amdgpu-resume.service" /etc/systemd/system/ 2>/dev/null || {
        log_warning "amdgpu-resume.service not found in dotfiles, skipping..."
    }
    sudo cp -f "$HOME/dotfiles/hosts/firedragon/etc/systemd/system/amdgpu-console-restore.service" /etc/systemd/system/ 2>/dev/null || {
        log_warning "amdgpu-console-restore.service not found in dotfiles, skipping..."
    }
    
    # 3. Enable services
    sudo systemctl daemon-reload
    sudo systemctl enable amdgpu-suspend.service 2>/dev/null || true
    sudo systemctl enable amdgpu-resume.service 2>/dev/null || true
    sudo systemctl enable amdgpu-console-restore.service 2>/dev/null || true
    
    # 4. Ensure kernel command line includes required AMD parameters
    if grep -qw "amdgpu.modeset=1" /proc/cmdline; then
        log_success "Kernel parameter amdgpu.modeset=1 already active in current boot"
    else
        log_info "Installing Limine kernel parameter drop-in for amdgpu.modeset=1..."
        local limine_dropin_src="$HOME/dotfiles/hosts/firedragon/etc/limine-entry-tool.d/10-amdgpu.conf"
        local limine_dropin_dest="/etc/limine-entry-tool.d/10-amdgpu.conf"
        if [[ -f "$limine_dropin_src" ]]; then
            sudo mkdir -p /etc/limine-entry-tool.d
            sudo cp -f "$limine_dropin_src" "$limine_dropin_dest"
            log_success "Copied Limine drop-in"
        else
            log_warning "Limine drop-in not found at $limine_dropin_src"
        fi

        if [[ -f "$BOOT_LIB" ]]; then
            sudo env LOG_LIB="$LOG_LIB" BOOT_LIB="$BOOT_LIB" bash -c '
                set -e
                # shellcheck disable=SC1091
                source "$LOG_LIB"
                # shellcheck disable=SC1091
                source "$BOOT_LIB"
                boot_dedupe_kernel_params
            '
        fi

        if command -v limine-update >/dev/null 2>&1; then
            if sudo limine-update; then
                log_success "Regenerated Limine configuration via limine-update"
            else
                log_warning "limine-update failed; run it again manually to apply amdgpu.modeset=1"
            fi
        elif command -v limine-mkinitcpio >/dev/null 2>&1; then
            if sudo limine-mkinitcpio; then
                log_success "Executed limine-mkinitcpio to refresh boot entries"
            else
                log_warning "limine-mkinitcpio failed; regenerate Limine entries manually"
            fi
        else
            log_warning "Limine regeneration tool not found; run limine-update or limine-mkinitcpio manually"
        fi

        log_warning "Reboot required for amdgpu.modeset=1 to take effect"
    fi
    
    # 5. DO NOT restart systemd-logind during active session!
    # It will kill the user's session and cause a black screen
    log_warning "systemd-logind changes require REBOOT to take effect"
    log_warning "DO NOT restart systemd-logind manually - it will kill your session!"

    if [[ -f "$HOME/dotfiles/hosts/firedragon/etc/systemd/system-sleep/99-runtime-pm.sh" ]]; then
        sudo install -m 755 "$HOME/dotfiles/hosts/firedragon/etc/systemd/system-sleep/99-runtime-pm.sh" /etc/systemd/system-sleep/99-runtime-pm.sh
        log_info "Installed runtime PM override script"
    fi

    if [[ -f "$HOME/dotfiles/hosts/firedragon/etc/systemd/system-sleep/98-ax210-bt-recover.sh" ]]; then
        sudo install -m 755 "$HOME/dotfiles/hosts/firedragon/etc/systemd/system-sleep/98-ax210-bt-recover.sh" /etc/systemd/system-sleep/98-ax210-bt-recover.sh
        log_info "Installed Intel AX210 Bluetooth recover script"
    fi
    
    log_success "Suspend/resume fixes installed"
    log_warning "⚠️  REBOOT REQUIRED - Changes will not work until reboot!"
}

# Setup Asus VivoBook-specific configurations
setup_asus_vivobook() {
    log_info "Configuring Asus VivoBook-specific settings..."
    
    # Enable asus-nb-wmi module for keyboard backlight and special keys
    log_info "Enabling Asus notebook WMI driver..."
    sudo tee /etc/modprobe.d/asus-vivobook.conf > /dev/null << 'EOF'
# Asus VivoBook specific configurations
options asus-nb-wmi kbd_backlight=1
options asus_wmi enable_fs=1
EOF
    
    # Load asus-wmi and asus-nb-wmi modules
    echo "asus_wmi" | sudo tee -a /etc/modules-load.d/asus.conf > /dev/null
    echo "asus_nb_wmi" | sudo tee -a /etc/modules-load.d/asus.conf > /dev/null
    
    # ACPI fixes for Asus VivoBook
    log_info "Applying ACPI fixes for Asus VivoBook..."

    # Kernel parameters for Asus ACPI fixes
    local asus_params="acpi_osi=! acpi_osi='Windows 2020' acpi_backlight=native"

    # Check if parameters are already in the current kernel cmdline
    if grep -q "acpi_osi=!" /proc/cmdline; then
        log_success "ACPI parameters already applied in current boot"
        return 0
    fi

    local bootloader
    bootloader="$(detect_bootloader)"
    log_info "Detected bootloader: $bootloader"
    if [[ "$bootloader" == "unknown" ]]; then
        log_warning "Unable to detect bootloader automatically; attempting best-effort update"
    fi

    # Ensure sudo access before applying changes
    log_info "Escalating privileges to update bootloader configuration..."
    if ! sudo -v 2>/dev/null; then
        log_warning "Cannot access bootloader files (sudo required)"
        log_info "Run manually after setup: bash ~/dotfiles/hosts/firedragon/fix-acpi-boot.sh"
        return 0
    fi

    if sudo env ASUS_PARAMS="$asus_params" LOG_LIB="$LOG_LIB" BOOT_LIB="$BOOT_LIB" bash -c '
        set -e
        # shellcheck disable=SC1091
        source "$LOG_LIB"
        # shellcheck disable=SC1091
        source "$BOOT_LIB"
        boot_append_kernel_params "$ASUS_PARAMS"
        boot_rebuild_if_changed
    '; then
        log_success "ACPI kernel parameters ensured across bootloader configuration"
        log_warning "Reboot recommended to apply ACPI changes"
    else
        log_warning "Failed to apply ACPI parameters automatically"
        log_info "You can retry manually with: bash ~/dotfiles/hosts/firedragon/fix-acpi-boot.sh"
    fi

    # Add keyboard backlight control via udev
    log_info "Setting up keyboard backlight controls..."
    sudo tee /etc/udev/rules.d/90-asus-kbd-backlight.rules > /dev/null << 'EOF'
# Allow users in video group to control keyboard backlight
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="asus::kbd_backlight", RUN+="/bin/chgrp video /sys/class/leds/%k/brightness"
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="asus::kbd_backlight", RUN+="/bin/chmod g+w /sys/class/leds/%k/brightness"
EOF
    
    # Add user to video group for backlight control
    sudo usermod -aG video "$USER"
    
    # Create keyboard backlight control script
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/kbd-backlight" << 'EOF'
#!/bin/bash
# Keyboard backlight control for Asus VivoBook

KBD_BACKLIGHT="/sys/class/leds/asus::kbd_backlight/brightness"
MAX_BRIGHTNESS="/sys/class/leds/asus::kbd_backlight/max_brightness"

if [[ ! -f "$KBD_BACKLIGHT" ]]; then
    echo "Keyboard backlight not found"
    exit 1
fi

MAX=$(cat "$MAX_BRIGHTNESS" 2>/dev/null || echo "3")
CURRENT=$(cat "$KBD_BACKLIGHT")

case "$1" in
    up)
        NEW=$((CURRENT + 1))
        [[ $NEW -gt $MAX ]] && NEW=$MAX
        echo $NEW > "$KBD_BACKLIGHT"
        ;;
    down)
        NEW=$((CURRENT - 1))
        [[ $NEW -lt 0 ]] && NEW=0
        echo $NEW > "$KBD_BACKLIGHT"
        ;;
    toggle)
        if [[ $CURRENT -eq 0 ]]; then
            echo $MAX > "$KBD_BACKLIGHT"
        else
            echo 0 > "$KBD_BACKLIGHT"
        fi
        ;;
    *)
        echo "Usage: $0 {up|down|toggle}"
        echo "Current: $CURRENT / $MAX"
        ;;
esac
EOF
    chmod +x "$HOME/.local/bin/kbd-backlight"
    
    log_success "Asus VivoBook configuration completed"
    log_info "Keyboard backlight control: kbd-backlight {up|down|toggle}"
}

# Setup MT7902 WiFi driver (MediaTek WiFi 6E)
setup_mt7902_wifi() {
    log_info "Checking MT7902 WiFi chip..."
    
    # Check if MT7902 is present
    if lspci -nn | grep -qi "14c3:0608\|14c3:7902\|Network.*MT7902"; then
        log_info "MT7902 WiFi chip detected"
        
        # Check if WiFi is already working
        if ip link show | grep -q "wlan\|wlp"; then
            log_success "WiFi interface already present and working"
            log_info "Skipping MT7902 driver installation"
            return 0
        fi
        
        log_info "WiFi not functional, will setup MT7902 driver..."
        log_warning "MT7902 driver setup is optional and uses community-developed drivers"
        log_info "The setup script is available at: ~/dotfiles/hosts/firedragon/setup-mt7902-wifi.sh"
        log_info "Run it manually after the main setup if needed: bash ~/dotfiles/hosts/firedragon/setup-mt7902-wifi.sh"
        
        # Don't run automatically - let user decide
        # Uncomment the line below to run automatically:
        # bash "$HOME/dotfiles/hosts/firedragon/setup-mt7902-wifi.sh"
    else
        log_info "MT7902 chip not detected, skipping driver setup"
    fi
}

# Setup advanced touchpad gesture plugins
setup_gesture_plugins() {
    log_info "Setting up advanced touchpad gesture plugins..."
    
    # Check build dependencies
    if ! command -v meson >/dev/null 2>&1 || ! command -v cmake >/dev/null 2>&1; then
        log_warning "Build tools (meson/cmake) not fully installed"
        log_info "CMake is required by wf-touch submodule to detect GLM"
        log_info "Gesture plugins are optional - touchpad still works without them"
        return 0
    fi
    
    log_info "Building hyprgrass gesture plugin..."
    log_info "CMake installed - wf-touch should be able to find GLM"
    
    local plugin_dir="$HOME/.local/share/hyprland-plugins"
    mkdir -p "$plugin_dir"
    
    # Install hyprgrass for advanced touchpad/touchscreen gestures
    if [[ ! -d "$plugin_dir/hyprgrass" ]]; then
        cd "$plugin_dir"
        if git clone https://github.com/horriblename/hyprgrass.git; then
            cd hyprgrass
            log_info "Building hyprgrass with cmake support..."
            if meson setup build && ninja -C build; then
                log_success "✓ Hyprgrass plugin built successfully!"
                
                # Create autostart script to load plugin
                mkdir -p "$HOME/.config/hypr/scripts"
                cat > "$HOME/.config/hypr/scripts/load-gesture-plugins.sh" << 'EOF'
#!/bin/bash
# Load Hyprland gesture plugins

PLUGIN_DIR="$HOME/.local/share/hyprland-plugins"

# Load hyprgrass plugin
if [[ -f "$PLUGIN_DIR/hyprgrass/build/hyprgrass.so" ]]; then
    hyprctl plugin load "$PLUGIN_DIR/hyprgrass/build/hyprgrass.so"
fi
EOF
                chmod +x "$HOME/.config/hypr/scripts/load-gesture-plugins.sh"
                log_success "Hyprgrass plugin installed and ready to load"
                log_info "Plugin location: $plugin_dir/hyprgrass/build/hyprgrass.so"
            else
                log_error "⚠ Hyprgrass build failed"
                log_info "Check build output above for errors"
                log_info "Touchpad gestures will still work via Hyprland's built-in support"
                # Clean up failed build
                cd "$HOME"
                rm -rf "$plugin_dir/hyprgrass" 2>/dev/null
            fi
        else
            log_info "Could not clone hyprgrass (optional feature)"
        fi
    else
        log_info "hyprgrass directory exists - skipping rebuild"
        if [[ -f "$plugin_dir/hyprgrass/build/hyprgrass.so" ]]; then
            log_success "Hyprgrass plugin already built"
        else
            log_info "Previous build incomplete - remove and re-run to retry"
        fi
    fi
    
    # Note: hyprexpo is built into Hyprland 0.40+
    log_info "Note: hyprexpo gesture support is built into Hyprland 0.40+"
    
    cd "$HOME"
    log_success "Gesture configuration completed"
}

# Rebuild initramfs to apply module changes
rebuild_initramfs() {
    log_info "Rebuilding initramfs to apply kernel module changes..."
    
    # Check for any bad module references in mkinitcpio.conf
    if grep -q "amd.ucode\|amd_ucode" /etc/mkinitcpio.conf 2>/dev/null; then
        log_warning "Found incorrect amd_ucode module reference in mkinitcpio.conf"
        log_info "Cleaning up mkinitcpio.conf..."
        sudo sed -i 's/amd.ucode//g; s/amd_ucode//g' /etc/mkinitcpio.conf
        sudo sed -i 's/  \+/ /g' /etc/mkinitcpio.conf  # Clean up double spaces
    fi
    
    # Rebuild initramfs for all installed kernels
    log_info "Rebuilding initramfs for all kernels..."
    if sudo mkinitcpio -P; then
        log_success "Initramfs rebuilt successfully"
    else
        log_warning "Initramfs rebuild had warnings - this is usually okay"
        log_info "The consolefont and Limine warnings are expected and can be ignored"
    fi
}

# Setup SDDM theme
setup_sddm_theme() {
    log_info "Setting up SDDM theme..."
    
    # Check if SDDM is installed
    if ! command -v sddm &>/dev/null; then
        log_info "SDDM not installed, skipping theme setup"
        return 0
    fi
    
    local theme_scripts_dir="$HOME/dotfiles/scripts/theme-manager"
    
    # Refresh SDDM themes (copies from packages/sddm to /usr/share/sddm/themes)
    if [[ -x "$theme_scripts_dir/refresh-sddm" ]]; then
        log_info "Refreshing SDDM themes..."
        bash "$theme_scripts_dir/refresh-sddm"
    else
        log_warning "refresh-sddm script not found"
    fi
    
    # Set the catppuccin theme
    if [[ -x "$theme_scripts_dir/sddm-set" ]]; then
        log_info "Setting SDDM theme to catppuccin-mocha-sky-sddm..."
        bash "$theme_scripts_dir/sddm-set" "catppuccin-mocha-sky-sddm"
        log_success "SDDM theme configured"
    else
        log_warning "sddm-set script not found"
    fi
}

# Main setup function
main() {
    log_info "🚀 Setting up FireDragon AMD Laptop..."
    echo
    
    # Run each setup function with idempotency tracking
    if ! is_step_completed "firedragon-packages"; then
        setup_firedragon_packages && mark_step_completed "firedragon-packages"
    else
        log_info "✓ Packages already installed (skipped)"
    fi
    echo

    if ! is_step_completed "firedragon-asus-ec-tools"; then
        setup_asus_ec_tools && mark_step_completed "firedragon-asus-ec-tools"
    else
        log_info "✓ ASUS EC tools already configured (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-amd-graphics"; then
        setup_amd_graphics && mark_step_completed "firedragon-amd-graphics"
    else
        log_info "✓ AMD graphics already configured (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-power-management"; then
        setup_power_management && mark_step_completed "firedragon-power-management"
    else
        log_info "✓ Power management already configured (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-suspend-resume"; then
        setup_suspend_resume_fixes && mark_step_completed "firedragon-suspend-resume"
    else
        log_info "✓ Suspend/resume fixes already applied (skipped)"
    fi
    echo
    
    setup_networking  # Has its own idempotency checks
    echo
    
    if ! is_step_completed "firedragon-display-input"; then
        setup_display_input && mark_step_completed "firedragon-display-input"
    else
        log_info "✓ Display/input already configured (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-hyprland-host-config"; then
        setup_hyprland_host_config && mark_step_completed "firedragon-hyprland-host-config"
    else
        log_info "✓ Hyprland host configuration already created (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-battery-monitoring"; then
        setup_battery_monitoring && mark_step_completed "firedragon-battery-monitoring"
    else
        log_info "✓ Battery monitoring already configured (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-laptop-optimizations"; then
        setup_laptop_optimizations && mark_step_completed "firedragon-laptop-optimizations"
    else
        log_info "✓ Laptop optimizations already applied (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-corectrl"; then
        setup_corectrl && mark_step_completed "firedragon-corectrl"
    else
        log_info "✓ CoreCtrl already configured (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-asus-vivobook"; then
        setup_asus_vivobook && mark_step_completed "firedragon-asus-vivobook"
    else
        log_info "✓ Asus VivoBook settings already configured (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-mt7902-wifi"; then
        setup_mt7902_wifi && mark_step_completed "firedragon-mt7902-wifi"
    else
        log_info "✓ MT7902 WiFi check already done (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-gesture-plugins"; then
        setup_gesture_plugins && mark_step_completed "firedragon-gesture-plugins"
    else
        log_info "✓ Gesture plugins already configured (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-initramfs"; then
        rebuild_initramfs && mark_step_completed "firedragon-initramfs"
    else
        log_info "✓ Initramfs already rebuilt (skipped)"
    fi
    echo
    
    if ! is_step_completed "firedragon-sddm-theme"; then
        setup_sddm_theme && mark_step_completed "firedragon-sddm-theme"
    else
        log_info "✓ SDDM theme already configured (skipped)"
    fi
    
    echo
    log_success "🎉 FireDragon setup completed!"
    echo
    log_info "📋 Post-Setup Instructions:"
    echo "  1. Reboot to apply all kernel module and power management changes"
    echo "  2. Run 'tlp-stat' to check TLP power management status"
    echo "  3. Run 'sensors-detect' and follow prompts to detect sensors"
    echo "  4. Use 'corectrl' GUI to fine-tune AMD GPU/CPU settings"
    echo "  5. Check battery status with: battery-status"
    echo "  6. Monitor GPU with: radeontop"
    echo "  7. Test suspend/resume:"
    echo "     • Close laptop lid → Open → Should resume properly"
    echo "     • Lock screen (Super+L) → Unlock → Should work smoothly"
    echo "     • Test TTY: Ctrl+Alt+F2 → Should show login prompt"
    echo "  8. Test touchpad gestures:"
    echo "     • 3-finger swipe left/right → Switch workspaces"
    echo "     • 3-finger swipe up → Toggle fullscreen"
    echo "     • 3-finger swipe down → Minimize window"
    echo "     • 4-finger swipe left/right → Move window between workspaces"
    echo
    log_info "⚡ Quick Commands:"
    echo "  • battery        - Show battery status"
    echo "  • gpuinfo        - AMD GPU monitor"
    echo "  • temp           - Show temperatures"
    echo "  • powersave      - Switch to battery profile"
    echo "  • powerperf      - Switch to performance profile"
    echo "  • kbd-backlight  - Control keyboard backlight (up/down/toggle)"
    echo
    log_info "👆 Touchpad Gesture Tips:"
    echo "  • Verify multi-touch support: libinput list-devices"
    echo "  • Test gestures in real-time: libinput debug-events"
    echo "  • Adjust gesture sensitivity in ~/.config/hypr/config/gestures.conf"
    echo
    log_info "📶 Asus VivoBook Specific:"
    echo "  • Keyboard backlight: kbd-backlight {up|down|toggle}"
    echo "  • Bootloader settings updated for ACPI fixes"
    if [ -f "/etc/default/grub" ]; then
        echo "  • GRUB detected: Run 'sudo grub-mkconfig -o /boot/grub/grub.cfg' and reboot"
    elif [ -f "/boot/limine.conf" ] || [ -f "/boot/limine/limine.conf" ]; then
        echo "  • Limine detected: Configuration updated, reboot to apply"
    elif [ -d "/boot/loader/entries" ]; then
        echo "  • systemd-boot detected: Configuration updated, reboot to apply"
    fi
    echo
    if lspci -nn | grep -qi "14c3:0608\|14c3:7902\|Network.*MT7902"; then
        log_warning "📡 MT7902 WiFi Detected:"
        if ip link show | grep -q "wlan\|wlp"; then
            echo "  ✅ WiFi is working! No driver installation needed."
        else
            echo "  ⚠️  WiFi not detected. To install MT7902 driver:"
            echo "  bash ~/dotfiles/hosts/firedragon/setup-mt7902-wifi.sh"
            echo "  Note: Uses community-developed driver (may have stability issues)"
        fi
    fi
    echo
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
