#!/usr/bin/env bash
#
# Installation State Management Utility
#
# View and manage the installation state tracking system

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/install-state.sh"

# Show usage
usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [arguments]

Manage installation state tracking for dotfiles setup

COMMANDS:
    status              Show current installation state
    info                Show detailed state information
    reset [host]        Reset installation state (all or specific host)
    list [host]         List completed steps (all or specific host)
    check <step>        Check if a specific step is completed
    force <step>        Force a step to re-run by resetting its state

EXAMPLES:
    $(basename "$0") status                    # Show summary
    $(basename "$0") list                      # List all completed steps
    $(basename "$0") list dragon               # List dragon-specific steps
    $(basename "$0") reset                     # Reset all state
    $(basename "$0") reset dragon              # Reset dragon steps only
    $(basename "$0") check dragon-install-liquidctl
    $(basename "$0") force dragon-install-liquidctl

EOF
}

# Show current status
show_status() {
    local completed_count
    completed_count=$(find "$STATE_DIR" -type f 2>/dev/null | wc -l)
    
    echo
    log_info "📊 Installation State Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "State directory: $STATE_DIR"
    log_info "Completed steps: $completed_count"
    echo
    
    if [[ $completed_count -eq 0 ]]; then
        log_info "No installation steps have been completed yet."
        log_info "Run ./install.sh to begin setup."
    else
        # Group by host
        log_info "Steps by host:"
        echo
        
        for host in dragon firedragon goldendragon microdragon spacedragon; do
            local host_steps
            host_steps=$(find "$STATE_DIR" -type f -name "${host}-*" 2>/dev/null | wc -l)
            if [[ $host_steps -gt 0 ]]; then
                echo "  $host: $host_steps steps completed"
            fi
        done
        
        # Check for other steps
        local other_steps
        other_steps=$(find "$STATE_DIR" -type f 2>/dev/null | grep -v -E "dragon-|firedragon-|goldendragon-|microdragon-|spacedragon-" | wc -l || echo "0")
        if [[ $other_steps -gt 0 ]]; then
            echo "  other: $other_steps steps completed"
        fi
    fi
    echo
}

# Show detailed information
show_info() {
    show_state_info
}

# List completed steps
list_steps() {
    local filter="${1:-}"
    
    echo
    log_info "📋 Completed Installation Steps"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ -z "$filter" ]]; then
        log_info "All completed steps:"
    else
        log_info "Completed steps for: $filter"
    fi
    echo
    
    local steps
    if [[ -z "$filter" ]]; then
        steps=$(find "$STATE_DIR" -type f -printf "%f\n" 2>/dev/null | sort || true)
    else
        steps=$(find "$STATE_DIR" -type f -name "${filter}-*" -printf "%f\n" 2>/dev/null | sort || true)
    fi
    
    if [[ -z "$steps" ]]; then
        log_warning "No completed steps found"
        if [[ -n "$filter" ]]; then
            log_info "Try: $(basename "$0") list  # to see all steps"
        fi
    else
        echo "$steps" | while IFS= read -r step; do
            local timestamp
            timestamp=$(stat -c %y "$STATE_DIR/$step" 2>/dev/null | cut -d. -f1 || echo "unknown")
            printf "  ✓ %-50s [%s]\n" "$step" "$timestamp"
        done
    fi
    echo
}

# Reset installation state
reset_state() {
    local filter="${1:-}"
    
    echo
    if [[ -z "$filter" ]]; then
        log_warning "⚠️  Reset ALL installation state?"
        echo "This will force all steps to re-run on next installation."
        read -p "Are you sure? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            return 0
        fi
        
        reset_all_steps
    else
        log_warning "⚠️  Reset installation state for: $filter"
        echo "This will force $filter steps to re-run on next installation."
        read -p "Are you sure? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            return 0
        fi
        
        find "$STATE_DIR" -type f -name "${filter}-*" -delete 2>/dev/null || true
        log_success "Reset state for $filter"
    fi
    echo
}

# Check if a specific step is completed
check_step() {
    local step="$1"
    
    echo
    if is_step_completed "$step"; then
        log_success "✓ Step completed: $step"
        local timestamp
        timestamp=$(stat -c %y "$STATE_DIR/$step" 2>/dev/null | cut -d. -f1 || echo "unknown")
        log_info "  Completed at: $timestamp"
    else
        log_info "✗ Step not completed: $step"
        log_info "  This step will run on next installation"
    fi
    echo
}

# Force a step to re-run
force_step() {
    local step="$1"
    
    echo
    if is_step_completed "$step"; then
        reset_step "$step"
        log_success "✓ Reset step: $step"
        log_info "  This step will re-run on next installation"
    else
        log_info "Step was not completed: $step"
        log_info "  Nothing to reset"
    fi
    echo
}

# Main function
main() {
    local command="${1:-status}"
    shift || true
    
    case "$command" in
        status)
            show_status
            ;;
        info)
            show_info
            ;;
        list)
            list_steps "$@"
            ;;
        reset)
            reset_state "$@"
            ;;
        check)
            if [[ $# -eq 0 ]]; then
                log_error "Missing step name"
                echo "Usage: $(basename "$0") check <step-name>"
                exit 1
            fi
            check_step "$1"
            ;;
        force)
            if [[ $# -eq 0 ]]; then
                log_error "Missing step name"
                echo "Usage: $(basename "$0") force <step-name>"
                exit 1
            fi
            force_step "$1"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            usage
            exit 1
            ;;
    esac
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

