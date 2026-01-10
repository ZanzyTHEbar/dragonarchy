# GoldenDragon-specific ZSH configuration - ThinkPad P16s Gen 4 (Intel)

# Power management aliases
alias battery='battery-status'
alias powersave='sudo tlp bat'
alias powerperf='sudo tlp ac'
alias powertop-cal='sudo powertop --calibrate'
alias tlpstat='sudo tlp-stat'

# Network aliases
alias wifi='nmcli device wifi'
alias wifi-connect='nmcli device wifi connect'
alias wifi-list='nmcli device wifi list'
alias bluetooth='bluetoothctl'

# System monitoring
alias temp='sensors'
alias thermals='watch -n 2 sensors'
alias power='upower -i $(upower -e | grep BAT)'

# Brightness control (if available)
alias bright='brightnessctl'
alias bright-up='brightnessctl set +10%'
alias bright-down='brightnessctl set 10%-'
alias bright-max='brightnessctl set 100%'
alias bright-min='brightnessctl set 10%'

# GPU helpers (auto-adapt to Intel-only vs hybrid NVIDIA)
if command -v nvidia-smi >/dev/null 2>&1; then
    alias nv='nvidia-smi'
    alias nvmon='watch -n 1 nvidia-smi'
fi

if command -v intel_gpu_top >/dev/null 2>&1; then
    alias igpu='intel_gpu_top'
fi

# GoldenDragon environment markers
export LAPTOP_MODE=true
export POWER_PROFILE="balanced"

# Intel video acceleration (intel-media-driver)
export LIBVA_DRIVER_NAME=iHD

