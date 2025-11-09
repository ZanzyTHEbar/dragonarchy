
# System aliases
alias temp='sensors'
alias gpu-temp='radeontop -d -'

# Development aliases
alias docker-clean='docker system prune -af'
alias vm-list='virsh list --all'

# Gaming aliases
alias steam-start='steam-runtime'
alias lutris-start='lutris'

# Snapshot management
alias snap-list='sudo snapper list'
alias snap-create='sudo snapper create --description'

# Performance monitoring
alias cpu-freq='watch -n1 "cat /proc/cpuinfo | grep MHz"'
alias mem-usage='free -h && echo && ps aux --sort=-%mem | head -10'

# Dragon-specific environment variables
export GAMING_MODE=true
export GPU_TYPE="AMD"
export DESKTOP_SESSION="wayland"

# Load gaming-specific functions
if [[ -f "$HOME/.config/functions/gaming-utils.zsh" ]]; then
    source "$HOME/.config/functions/gaming-utils.zsh"
fi

# Dragon system monitoring
alias firedragon-temps='sensors | grep -E "(Package|Core|Tctl)"'
alias firedragon-fans='sensors | grep fan'