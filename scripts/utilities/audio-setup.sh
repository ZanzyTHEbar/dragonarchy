#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Audio Configuration Setup for Professional Audio Interfaces
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configures PipeWire for professional audio interfaces like
# the Audient iD22, including stereo proxy setup and default routing.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../lib/logging.sh"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PIPEWIRE_CONFIG_DIR="$HOME/.config/pipewire/pipewire.conf.d"
DOTFILES_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Detect current host
CURRENT_HOST=$(hostname | cut -d. -f1)
HOST_AUDIO_DIR="$DOTFILES_ROOT/hosts/$CURRENT_HOST/pipewire"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_pipewire_running() {
    if ! systemctl --user is-active --quiet pipewire; then
        log_error "PipeWire is not running!"
        log_info "Start PipeWire: systemctl --user start pipewire pipewire-pulse wireplumber"
        return 1
    fi
    log_success "PipeWire is running"
    return 0
}

check_device_exists() {
    local device_pattern="$1"
    local device_type="$2"  # "sink" or "source"
    
    if pactl list "${device_type}s" short | grep -q "$device_pattern"; then
        log_success "Device detected: $device_pattern"
        return 0
    else
        log_warning "Device not found: $device_pattern"
        return 1
    fi
}

install_pipewire_configs() {
    log_info "Installing PipeWire configurations for host: $CURRENT_HOST"
    
    # Check if this host has audio configs
    if [[ ! -d "$HOST_AUDIO_DIR" ]]; then
        log_info "No host-specific audio configuration found for $CURRENT_HOST"
        log_info "This host will use system default audio setup"
        log_info "Location checked: $HOST_AUDIO_DIR"
        return 0  # Not an error, just no custom config
    fi
    
    # Create config directory if it doesn't exist
    mkdir -p "$PIPEWIRE_CONFIG_DIR"
    
    # Copy configuration files from host directory
    local files_copied=0
    for config_file in "$HOST_AUDIO_DIR"/*.conf; do
        if [[ -f "$config_file" ]]; then
            local basename_file
            basename_file=$(basename "$config_file")
            local target_file="$PIPEWIRE_CONFIG_DIR/$basename_file"
            
            # Backup existing file if it exists and is different
            if [[ -f "$target_file" ]]; then
                if ! diff -q "$config_file" "$target_file" &>/dev/null; then
                    log_info "Backing up existing config: $basename_file"
                    cp "$target_file" "${target_file}.backup.$(date +%Y%m%d_%H%M%S)"
                fi
            fi
            
            # Copy new config
            cp "$config_file" "$target_file"
            log_success "Installed: $basename_file"
            ((files_copied++))
        fi
    done
    
    if [[ $files_copied -eq 0 ]]; then
        log_warning "No configuration files found in $HOST_AUDIO_DIR"
        return 1
    fi
    
    log_success "Installed $files_copied configuration file(s) from host config"
}

restart_pipewire() {
    log_info "Restarting PipeWire services..."
    
    # Stop services in reverse order
    systemctl --user stop wireplumber pipewire-pulse pipewire 2>/dev/null || true
    
    # Small delay to ensure clean shutdown
    sleep 1
    
    # Start services in correct order
    if systemctl --user start pipewire pipewire-pulse wireplumber; then
        # Wait for services to fully initialize
        sleep 2
        
        if check_pipewire_running; then
            log_success "PipeWire services restarted successfully"
            return 0
        else
            log_error "PipeWire failed to start properly"
            return 1
        fi
    else
        log_error "Failed to restart PipeWire services"
        return 1
    fi
}

verify_audio_setup() {
    log_info "Verifying audio configuration..."
    
    # If no host-specific config, nothing to verify
    if [[ ! -d "$HOST_AUDIO_DIR" ]]; then
        log_info "No host-specific audio configuration - using system defaults"
        log_success "Standard audio setup verified"
        return 0
    fi
    
    # Determine what to check based on config files present
    local has_audient_config=false
    if [[ -f "$HOST_AUDIO_DIR/20-stereo-audient.conf" ]]; then
        has_audient_config=true
    fi
    
    # If we have Audient-specific config, verify it
    if [[ "$has_audient_config" == "true" ]]; then
        log_info "Checking for Audient iD22..."
        if ! check_device_exists "Audient_iD22" "sink"; then
            log_warning "Audient iD22 not detected"
            log_info "Configuration is installed but hardware not connected"
            log_info "Audio will work normally once device is plugged in"
            return 0  # Not a failure, just hardware not present
        fi
        
        # Check for stereo proxy
        log_info "Checking for stereo proxy..."
        if ! check_device_exists "audient-stereo-proxy" "sink"; then
            log_warning "Stereo proxy not created"
            log_info "This may be because:"
            log_info "  - PipeWire hasn't fully initialized yet"
            log_info "  - Audient iD22 was just connected"
            log_info "Try: systemctl --user restart pipewire"
            return 0  # Not a hard failure
        fi
        
        # Check default sink
        local default_sink
        default_sink=$(pactl get-default-sink)
        log_info "Default sink: $default_sink"
        
        if [[ "$default_sink" == "audient-stereo-proxy" ]]; then
            log_success "Default sink correctly set to stereo proxy"
        else
            log_info "Default sink is: $default_sink"
            log_info "Expected: audient-stereo-proxy"
            log_info "This may auto-correct when iD22 is connected"
        fi
        
        # Check default source
        local default_source
        default_source=$(pactl get-default-source)
        log_info "Default source: $default_source"
        
        if [[ "$default_source" =~ Audient.*iD22 ]]; then
            log_success "Default source correctly set to Audient iD22"
        else
            log_info "Default source is: $default_source"
            log_info "Will switch to iD22 when connected"
        fi
    fi
    
    log_success "Audio verification complete"
    return 0
}

show_audio_status() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Audio Configuration Status"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    log_info "PipeWire Server:"
    pactl info | grep "Server Name:" | sed 's/^/  /'
    pactl info | grep "Server Version:" | sed 's/^/  /'
    echo
    
    log_info "Audio Devices:"
    log_info "  Sinks (Outputs):"
    pactl list sinks short | while read -r line; do
        echo "    - $line"
    done
    echo
    
    log_info "  Sources (Inputs):"
    pactl list sources short | grep -v "\.monitor" | while read -r line; do
        echo "    - $line"
    done
    echo
    
    log_info "Defaults:"
    echo "  Default Sink:   $(pactl get-default-sink)"
    echo "  Default Source: $(pactl get-default-source)"
    echo
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Function
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Audio Setup - Host: $CURRENT_HOST"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    # Check PipeWire is running
    if ! check_pipewire_running; then
        log_error "Cannot proceed without PipeWire running"
        exit 1
    fi
    echo
    
    # Check if this host has custom audio config
    if [[ ! -d "$HOST_AUDIO_DIR" ]]; then
        log_info "No custom audio configuration for this host"
        log_info "Using system default audio setup"
        echo
        show_audio_status
        exit 0
    fi
    
    log_info "Found host-specific audio configuration"
    log_info "Configuration directory: $HOST_AUDIO_DIR"
    echo
    
    # Install configurations
    install_pipewire_configs
    echo
    
    # Restart PipeWire to apply configs
    if restart_pipewire; then
        echo
        
        # Verify setup
        verify_audio_setup
        echo
        
        show_audio_status
        
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_success "Audio setup completed!"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        log_info "Next steps:"
        log_info "  • Test audio playback: speaker-test -c 2"
        log_info "  • Adjust levels: pavucontrol or wiremix"
        log_info "  • Monitor connections: pw-top"
        echo
    else
        log_error "Failed to restart PipeWire services"
        exit 1
    fi
}

# Handle arguments
case "${1:-}" in
    --status)
        check_pipewire_running && show_audio_status
        ;;
    --restart)
        restart_pipewire
        ;;
    --verify)
        check_pipewire_running && verify_audio_setup
        ;;
    --help|-h)
        echo "Audio Setup Script"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  (no args)   Full setup - install configs and restart PipeWire"
        echo "  --status    Show current audio configuration status"
        echo "  --restart   Restart PipeWire services"
        echo "  --verify    Verify audio setup is working"
        echo "  --help      Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0               # Run full setup"
        echo "  $0 --status      # Check current config"
        echo "  $0 --restart     # Restart audio services"
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Run '$0 --help' for usage information"
        exit 1
        ;;
esac

