# FireDragon-specific ZSH configuration - AMD Laptop

# Power management aliases
alias battery='battery-status'
alias powersave='sudo tlp bat'
alias powerperf='sudo tlp ac'
alias powertop-cal='sudo powertop --calibrate'
alias tlpstat='sudo tlp-stat'

# AMD GPU monitoring and control
alias gpuinfo='radeontop'
alias gpumon='watch -n 1 radeontop -d-'
alias gputemp='sensors | grep -E "(edge|junction|mem)"'
alias gpufreq='cat /sys/class/drm/card0/device/pp_dpm_*clk'

# Network aliases
alias wifi='nmcli device wifi'
alias wifi-connect='nmcli device wifi connect'
alias wifi-list='nmcli device wifi list'
alias bluetooth='bluetoothctl'

# System monitoring for laptop
alias temp='sensors | grep -E "(Tctl|Tdie|edge)"'
alias fans='sensors | grep fan'
alias power='upower -i $(upower -e | grep BAT)'
alias thermals='watch -n 2 sensors'

# Brightness control
alias bright='brightnessctl'
alias bright-up='brightnessctl set +10%'
alias bright-down='brightnessctl set 10%-'
alias bright-max='brightnessctl set 100%'
alias bright-min='brightnessctl set 10%'

# CPU frequency info
alias cpufreq='watch -n 1 grep MHz /proc/cpuinfo'
alias cpuinfo='lscpu | grep -E "Model name|MHz|Core"'

# Development aliases optimized for laptop
alias dev-start='docker-compose up -d'
alias dev-stop='docker-compose down'

# Quick system info
alias sysinfo='echo "Battery: $(cat /sys/class/power_supply/BAT0/capacity)% | Temp: $(sensors | grep Tctl | awk "{print \$2}") | Load: $(uptime | cut -d, -f3-)"'

# Laptop mode shortcuts
alias laptop-mode='sudo tlp bat && echo "Switched to battery profile"'
alias performance-mode='sudo tlp ac && echo "Switched to performance profile"'

# FireDragon-specific environment variables
export LAPTOP_MODE=true
export POWER_PROFILE="balanced"
export GPU_VENDOR="AMD"
export GPU_DRIVER="amdgpu"

# AMD-specific optimizations
export RADV_PERFTEST=aco        # Use ACO shader compiler
export AMD_VULKAN_ICD=RADV      # Use RADV for Vulkan
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json

# Enable hardware video acceleration
export LIBVA_DRIVER_NAME=radeonsi
export VDPAU_DRIVER=radeonsi

# Enable touchpad gestures in Wayland
export WLR_NO_HARDWARE_CURSORS=1  # Fixes cursor issues on some AMD laptops

# Auto-set power profile based on AC status
if [[ -f /sys/class/power_supply/AC/online ]]; then
    AC_STATUS=$(cat /sys/class/power_supply/AC/online)
    if [[ "$AC_STATUS" == "0" ]]; then
        export POWER_PROFILE="battery"
    else
        export POWER_PROFILE="ac"
    fi
fi

# Display current power status on shell startup
if command -v tlp-stat >/dev/null 2>&1; then
    #echo "🔋 FireDragon Laptop - Power: $POWER_PROFILE mode"
fi

# Touchpad gesture status
#echo "👆 Touchpad gestures enabled (3-finger swipe to switch workspaces)"
