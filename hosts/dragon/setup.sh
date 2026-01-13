#!/usr/bin/env bash
#
# Dragon Host-Specific Setup
#
# Dragon is an all-AMD desktop (CPU + workstation GPU).
#
# This script:
# - Applies host system config under hosts/dragon/etc -> /etc
# - Ensures AIO cooler services (liquidctl + dynamic_led)
# - Applies host audio config (hosts/dragon/pipewire -> ~/.config/pipewire/pipewire.conf.d)
# - Installs a small workstation toolset when possible (best-effort)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib/logging.sh"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/scripts/lib/install-state.sh"

install_dragon_packages() {
    # Keep host setup runnable standalone even if install-deps wasn’t invoked.
    # (install-deps also installs host_dragon_workstation via deps.manifest.toml on Arch-family)
    local pkgs=(
        "liquidctl"
        "lm_sensors"
        "corectrl"
        "radeontop"
        "vulkan-tools"
        "mesa-utils"
    )

    log_step "Installing Dragon workstation packages (best-effort)..."
    local pkg
    for pkg in "${pkgs[@]}"; do
        if install_package_if_needed "$pkg"; then
            log_success "Installed: $pkg"
        else
            if [[ $? -eq 1 ]]; then
                log_info "✓ $pkg already installed"
            else
                log_warning "Could not install $pkg automatically (no supported package manager)"
            fi
        fi
    done
}

setup_netbird() {
    log_step "Installing NetBird..."
    bash "${PROJECT_ROOT}/scripts/utilities/netbird-install.sh"
}

apply_host_system_configs() {
    log_step "Copying host-specific system configs..."
    if copy_dir_if_changed "${PROJECT_ROOT}/hosts/dragon/etc/" /etc/; then
        log_success "System configs updated"
        reset_step "dragon-restart-resolved"
    else
        log_info "System configs unchanged"
    fi
}

restart_resolved_if_needed() {
    log_step "Applying DNS changes (systemd-resolved)..."
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-unit-files 2>/dev/null | grep -q '^systemd-resolved\.service'; then
            sudo systemctl enable --now systemd-resolved.service >/dev/null 2>&1 || true
        fi
    fi
    restart_if_running systemd-resolved || true
    log_success "DNS configuration applied"
}

setup_dynamic_led_service() {
    log_step "Installing dynamic_led service..."

    if copy_if_changed "${PROJECT_ROOT}/hosts/dragon/dynamic_led.py" /usr/local/bin/dynamic_led.py; then
        sudo chmod +x /usr/local/bin/dynamic_led.py
    fi

    install_service "${PROJECT_ROOT}/hosts/dragon/dynamic_led.service" "dynamic_led.service"
    log_success "dynamic_led service installed and started"
}

setup_liquidctl_suspend_hook() {
    log_step "Configuring suspend hooks..."
    sudo chmod +x /etc/systemd/system-sleep/liquidctl-suspend.sh 2>/dev/null || true
    log_success "Suspend hooks configured"
}

setup_liquidctl_service() {
    log_step "Installing liquidctl AIO cooler service..."
    install_service "${PROJECT_ROOT}/hosts/dragon/liquidctl-dragon.service" "liquidctl-dragon.service"
    log_success "liquidctl service installed and started"
}

setup_audio() {
    log_step "Setting up audio configuration (host pipewire/)..."
    bash "${PROJECT_ROOT}/scripts/utilities/audio-setup.sh"
    log_success "Audio configuration applied"
}

main() {
    log_info "🐉 Running setup for Dragon workstation..."
    echo

    if [[ "${1:-}" == "--reset" ]]; then
        reset_all_steps
        log_info "Installation state reset. All steps will be re-run."
        echo
    fi

    if ! is_step_completed "dragon-packages"; then
        install_dragon_packages && mark_step_completed "dragon-packages"
    else
        log_info "✓ Packages already installed (skipped)"
    fi
    echo

    if ! is_step_completed "dragon-install-netbird"; then
        setup_netbird && mark_step_completed "dragon-install-netbird"
    else
        log_info "✓ NetBird already installed (skipped)"
    fi
    echo

    # Always re-check configs (idempotent + picks up repo updates).
    apply_host_system_configs
    mark_step_completed "dragon-copy-system-configs"
    echo

    if ! is_step_completed "dragon-restart-resolved"; then
        restart_resolved_if_needed && mark_step_completed "dragon-restart-resolved"
    else
        log_info "✓ DNS configuration already applied (skipped)"
    fi
    echo

    if ! is_step_completed "dragon-install-dynamic-led"; then
        setup_dynamic_led_service && mark_step_completed "dragon-install-dynamic-led"
    else
        log_info "✓ dynamic_led already installed (skipped)"
        if copy_if_changed "${PROJECT_ROOT}/hosts/dragon/dynamic_led.py" /usr/local/bin/dynamic_led.py; then
            sudo chmod +x /usr/local/bin/dynamic_led.py
            sudo systemctl restart dynamic_led.service || true
        fi
        if copy_if_changed "${PROJECT_ROOT}/hosts/dragon/dynamic_led.service" /etc/systemd/system/dynamic_led.service; then
            sudo systemctl daemon-reload
            sudo systemctl restart dynamic_led.service || true
        fi
    fi
    echo

    if ! is_step_completed "dragon-configure-suspend-hooks"; then
        setup_liquidctl_suspend_hook && mark_step_completed "dragon-configure-suspend-hooks"
    else
        log_info "✓ Suspend hooks already configured (skipped)"
    fi
    echo

    if ! is_step_completed "dragon-install-liquidctl-service"; then
        setup_liquidctl_service && mark_step_completed "dragon-install-liquidctl-service"
    else
        log_info "✓ liquidctl service already installed (skipped)"
        if copy_if_changed "${PROJECT_ROOT}/hosts/dragon/liquidctl-dragon.service" /etc/systemd/system/liquidctl-dragon.service; then
            sudo systemctl daemon-reload
            sudo systemctl restart liquidctl-dragon.service || true
        fi
    fi
    echo

    if ! is_step_completed "dragon-setup-audio"; then
        setup_audio && mark_step_completed "dragon-setup-audio"
    else
        log_info "✓ Audio configuration already applied (skipped)"
    fi
    echo

    log_success "🐉 Dragon setup complete!"
    echo
    log_info "Quick checks:"
    echo "  • DNS:    resolvectl status"
    echo "  • AIO:    systemctl status liquidctl-dragon.service"
    echo "  • LEDs:   systemctl status dynamic_led.service"
    echo "  • Vulkan: vulkaninfo --summary"
    echo
    log_warning "Reboot recommended if you changed kernel parameters or updated microcode"
    echo
}

main "$@"
