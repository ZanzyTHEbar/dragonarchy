# Dragon-specific ZSH configuration
# Additional configuration for the dragon machine

# AIO Cooler management (custom liquidctl service)
alias aio-status='sudo systemctl status liquidctl-dragon.service'
alias aio-restart='sudo systemctl restart liquidctl-dragon.service'
alias aio-logs='sudo journalctl -u liquidctl-dragon.service -f'
alias aio-check='liquidctl status --match h100i'
alias aio-temp='liquidctl status --match h100i | grep -E "(Liquid temperature|Fan speed|Pump speed)"'

# Manual liquidctl commands for debugging
alias liquidctl-init='sudo liquidctl initialize --match h100i'
alias liquidctl-status='sudo liquidctl status --match h100i'
alias liquidctl-fans='sudo liquidctl set fan speed --match h100i'
alias liquidctl-pump='sudo liquidctl set pump speed --match h100i'
alias liquidctl-led='sudo liquidctl set led color --match h100i'

# Dragon system monitoring
alias dragon-temps='sensors | grep -E "(Package|Core|Tctl)" && echo "=== AIO Status ===" && aio-temp'
alias dragon-fans='sensors | grep fan && echo "=== AIO Fans ===" && aio-temp'

# Dragon-specific environment
export AIO_DEVICE="h100i"
export DRAGON_AIO_SERVICE="liquidctl-dragon.service" 