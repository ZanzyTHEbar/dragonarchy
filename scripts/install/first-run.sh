#!/usr/bin/env bash
#
# first-run.sh - First-run setup tasks for a fresh dotfiles installation
#
# Runs one-time provisioning tasks that only make sense on a fresh machine:
#   - Basic firewall setup (ufw)
#   - Timezone auto-detection
#   - Theme verification (plymouth, SDDM)
#   - Welcome message with next-steps guidance
#
# Each task is gated by install-state markers so re-running is idempotent.
#
# Usage:
#   bash scripts/install/first-run.sh           # run all first-run tasks
#   bash scripts/install/first-run.sh --dry-run  # preview without changes
#
# Environment:
#   SYSMOD_DRY_RUN=1   - passed through to system-mods helpers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"

# Source libraries
# shellcheck disable=SC1091
source "${SCRIPTS_DIR}/lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPTS_DIR}/lib/install-state.sh"
# shellcheck disable=SC1091
source "${SCRIPTS_DIR}/lib/system-mods.sh"

DRY_RUN=false

# ────────────────────────────────────────────────────────────────
# Task 1: Firewall Setup
# ────────────────────────────────────────────────────────────────
setup_firewall() {
    local step_id="first-run:firewall"

    if is_step_completed "$step_id"; then
        log_info "Firewall already configured (skipped)"
        return 0
    fi

    log_step "Configuring firewall..."

    if ! command -v ufw >/dev/null 2>&1; then
        log_warning "ufw not found; skipping firewall setup"
        log_info "Install ufw and re-run, or configure your firewall manually"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would configure ufw: default deny incoming, allow outgoing, allow SSH"
        return 0
    fi

    # Set sane defaults: deny incoming, allow outgoing, allow SSH
    _sysmod_sudo ufw default deny incoming 2>/dev/null || true
    _sysmod_sudo ufw default allow outgoing 2>/dev/null || true
    _sysmod_sudo ufw allow ssh 2>/dev/null || true

    # Enable ufw if not already active
    local ufw_status
    ufw_status=$(_sysmod_sudo ufw status 2>/dev/null || true)
    if [[ "$ufw_status" != *"Status: active"* ]]; then
        _sysmod_sudo ufw --force enable 2>/dev/null || true
    fi

    mark_step_completed "$step_id"
    log_success "Firewall configured (deny incoming, allow outgoing, allow SSH)"
}

# ────────────────────────────────────────────────────────────────
# Task 2: Timezone Auto-Detection
# ────────────────────────────────────────────────────────────────
setup_timezone() {
    local step_id="first-run:timezone"

    if is_step_completed "$step_id"; then
        log_info "Timezone already configured (skipped)"
        return 0
    fi

    log_step "Detecting and setting timezone..."

    local current_tz
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || true)

    if [[ -n "$current_tz" && "$current_tz" != "UTC" && "$current_tz" != "Etc/UTC" ]]; then
        log_info "Timezone already set to ${current_tz} (not UTC); keeping it"
        mark_step_completed "$step_id"
        return 0
    fi

    # Attempt geo-IP based timezone detection
    local detected_tz=""
    if command -v curl >/dev/null 2>&1; then
        detected_tz=$(curl -sf --max-time 5 "http://ip-api.com/line/?fields=timezone" 2>/dev/null || true)
    fi

    if [[ -z "$detected_tz" ]]; then
        log_warning "Could not auto-detect timezone; keeping current setting (${current_tz:-unknown})"
        log_info "Set manually: sudo timedatectl set-timezone <Zone/City>"
        mark_step_completed "$step_id"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would set timezone to: $detected_tz"
        return 0
    fi

    _sysmod_sudo timedatectl set-timezone "$detected_tz" 2>/dev/null || {
        log_warning "Failed to set timezone to '$detected_tz'; set manually"
        mark_step_completed "$step_id"
        return 0
    }

    # Enable NTP synchronization
    _sysmod_sudo timedatectl set-ntp true 2>/dev/null || true

    mark_step_completed "$step_id"
    log_success "Timezone set to ${detected_tz} with NTP enabled"
}

# ────────────────────────────────────────────────────────────────
# Task 3: Theme Verification
# ────────────────────────────────────────────────────────────────
verify_themes() {
    local step_id="first-run:themes"

    if is_step_completed "$step_id"; then
        log_info "Theme verification already completed (skipped)"
        return 0
    fi

    log_step "Verifying theme configuration..."

    local issues=0

    # Plymouth theme check
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        local plymouth_theme
        plymouth_theme=$(plymouth-set-default-theme 2>/dev/null || true)
        if [[ -n "$plymouth_theme" ]]; then
            log_success "Plymouth theme: ${plymouth_theme}"
        else
            log_warning "Plymouth theme not set"
            issues=$((issues + 1))
        fi
    fi

    # GTK theme check
    local gtk_settings="$HOME/.config/gtk-3.0/settings.ini"
    if [[ -f "$gtk_settings" ]]; then
        local gtk_theme
        gtk_theme=$(grep -i 'gtk-theme-name' "$gtk_settings" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' ' || true)
        if [[ -n "$gtk_theme" ]]; then
            log_success "GTK theme: ${gtk_theme}"
        else
            log_warning "GTK theme not configured in ${gtk_settings}"
            issues=$((issues + 1))
        fi
    fi

    # Icon theme check
    if [[ -f "$gtk_settings" ]]; then
        local icon_theme
        icon_theme=$(grep -i 'gtk-icon-theme-name' "$gtk_settings" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' ' || true)
        if [[ -n "$icon_theme" ]]; then
            log_success "Icon theme: ${icon_theme}"
        else
            log_warning "Icon theme not configured"
            issues=$((issues + 1))
        fi
    fi

    # Cursor theme check
    local cursor_theme_path="$HOME/.icons/default/index.theme"
    if [[ -f "$cursor_theme_path" ]]; then
        log_success "Cursor theme configured"
    else
        log_info "Cursor theme not explicitly set (using default)"
    fi

    # SDDM theme check
    if command -v sddm >/dev/null 2>&1; then
        local sddm_conf="/etc/sddm.conf.d/10-theme.conf"
        if [[ -f "$sddm_conf" ]]; then
            local sddm_theme
            sddm_theme=$(grep -i 'Current' "$sddm_conf" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' ' || true)
            if [[ -n "$sddm_theme" ]]; then
                log_success "SDDM theme: ${sddm_theme}"
            else
                log_warning "SDDM theme not set in ${sddm_conf}"
                issues=$((issues + 1))
            fi
        else
            log_warning "SDDM theme config not found at ${sddm_conf}"
            issues=$((issues + 1))
        fi
    fi

    if [[ "$issues" -gt 0 ]]; then
        log_warning "Theme verification found ${issues} issue(s); review above"
    else
        log_success "All themes verified"
    fi

    mark_step_completed "$step_id"
}

# ────────────────────────────────────────────────────────────────
# Task 4: Welcome Message
# ────────────────────────────────────────────────────────────────
show_welcome() {
    local step_id="first-run:welcome"

    if is_step_completed "$step_id"; then
        return 0
    fi

    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║          🐉  Welcome to DragonArchy Dotfiles  🐉           ║"
    echo "║                                                            ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║                                                            ║"
    echo "║  Your system has been configured. Here's what to do next:  ║"
    echo "║                                                            ║"
    echo "║  1. Log out and back in for shell changes to take effect   ║"
    echo "║  2. Run 'validate.sh' to verify system health              ║"
    echo "║  3. Check host-specific docs in hosts/<hostname>/docs/     ║"
    echo "║  4. Configure secrets: sops/age keys in ~/.config/sops/    ║"
    echo "║                                                            ║"
    echo "║  Useful commands:                                          ║"
    echo "║    validate.sh          - System health check              ║"
    echo "║    install.sh --help    - See all installer options        ║"
    echo "║    install.sh --status  - Show installation state          ║"
    echo "║                                                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo

    mark_step_completed "$step_id"
}

# ────────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────────
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                export SYSMOD_DRY_RUN=1
                shift
                ;;
            -h|--help)
                echo "Usage: first-run.sh [--dry-run] [--help]"
                echo "  --dry-run   Preview changes without executing them"
                echo "  --help      Show this help message"
                return 0
                ;;
            *)
                log_error "Unknown argument: $1"
                return 1
                ;;
        esac
    done

    log_info "Running first-run setup tasks..."
    echo

    setup_firewall
    setup_timezone
    verify_themes
    show_welcome

    log_success "First-run setup complete"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
