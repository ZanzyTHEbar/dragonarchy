#!/bin/bash
# Configure per-user services and user-session app daemons (Walker/Elephant)

set -euo pipefail

# Get script directory and source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Runtime-resolved path to logging library
source "${SCRIPT_DIR}/../../lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/control-plane-mode.sh"

mkdir -p "$HOME/.config/systemd/user"

# Shared paths for the remaining legacy non-launcher setup below.
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PACKAGES_ROOT="$DOTFILES_ROOT/packages"

ensure_user_package_stowed() {
    local package="$1"

    if dotfiles_user_owner_is_chezmoi; then
        log_info "Skipping user package restow for '$package' because DOTFILES_USER_OWNER=chezmoi"
        return 0
    fi

    if ! command -v stow >/dev/null 2>&1; then
        log_warning "GNU Stow is unavailable; cannot restow '$package'"
        return 1
    fi

    if [[ ! -d "$PACKAGES_ROOT/$package" ]]; then
        log_warning "Package directory not found for stow restow: $PACKAGES_ROOT/$package"
        return 1
    fi

    # Run from the packages root so GNU Stow applies packages/.stowrc ignores.
    if (cd "$PACKAGES_ROOT" && stow --restow -t "$HOME" "$package"); then
        log_success "Restowed user package: $package"
        return 0
    fi

    log_warning "Failed to restow user package: $package"
    return 1
}

POLKIT_AGENT_UNIT_PATH="$HOME/.config/systemd/user/polkit-agent.service"
POLKIT_AGENT_HELPER_PATH="$HOME/.local/bin/start-polkit-agent"
if [[ ! -e "$POLKIT_AGENT_UNIT_PATH" || ! -x "$POLKIT_AGENT_HELPER_PATH" ]]; then
    ensure_user_package_stowed "hyprland" || true
fi

# Launcher units/config are curated static inputs, not generated here. In a real
# graphical session dragon-launcher-session imports its environment and starts
# the single Walker/Elephant owners. Do not load plugins/Lua as an installer probe.
log_info "Launcher ownership: managed elephant.service/walker.service; start via dragon-launcher-session"

# --- Workspace indicator (optional standalone pre-built release) ---
# Direct release assets avoid API rate limits.
WS_INDICATOR_URL="${WORKSPACE_INDICATOR_URL:-https://github.com/ZanzyTHEbar/workspace-indicator/releases/latest/download/workspace-indicator-linux-x86_64.tar.gz}"
if [[ "${WORKSPACE_INDICATOR_SKIP:-0}" != "1" ]]; then
    ws_tmp="$(mktemp -d)"
    if curl -fsSL "$WS_INDICATOR_URL" | tar -xz -C "$ws_tmp" 2>/dev/null && "$ws_tmp/install.sh"; then
        log_success "workspace-indicator pre-built bundle installed"
    else
        log_warning "workspace-indicator release unavailable or failed to install; skipping optional integration"
    fi
    rm -rf "$ws_tmp"
fi

WORKSPACE_INDICATOR_UNIT="workspace-indicator.service"
if systemctl --user list-unit-files --no-legend 2>/dev/null | grep -q "^${WORKSPACE_INDICATOR_UNIT}"; then
    systemctl --user daemon-reload
    if systemctl --user enable --now "${WORKSPACE_INDICATOR_UNIT}" >/dev/null 2>&1; then
        log_success "Workspace indicator service enabled"
    else
        log_warning "Failed to enable workspace-indicator.service"
    fi
else
    log_info "workspace-indicator.service not present; skipping enablement"
fi

# --- Thermal profile initialization service ---
THERMAL_PROFILE_UNIT="thermal-profile-init.service"
if systemctl --user list-unit-files --no-legend 2>/dev/null | grep -q "^${THERMAL_PROFILE_UNIT}"; then
    if systemctl --user enable --now "${THERMAL_PROFILE_UNIT}" >/dev/null 2>&1; then
        log_success "Thermal profile init service enabled"
    else
        log_warning "Failed to enable thermal-profile-init.service; ensure ~/.local/bin/thermal-profile-init exists"
    fi
else
    log_info "thermal-profile-init.service not present; skipping enablement"
fi

# --- Dynamic monitor layout service ---
DYNAMIC_MONITORS_UNIT="dynamic-monitors.service"
if systemctl --user list-unit-files --no-legend 2>/dev/null | grep -q "^${DYNAMIC_MONITORS_UNIT}"; then
    if systemctl --user enable --now "${DYNAMIC_MONITORS_UNIT}" >/dev/null 2>&1; then
        log_success "Dynamic monitors service enabled"
    else
        log_warning "Failed to enable dynamic-monitors.service"
    fi
else
    log_info "dynamic-monitors.service not present; skipping enablement"
fi

# --- Polkit authentication agent ---
POLKIT_AGENT_UNIT="polkit-agent.service"
if systemctl --user list-unit-files --no-legend 2>/dev/null | grep -q "^${POLKIT_AGENT_UNIT}"; then
    systemctl --user daemon-reload
    if systemctl --user enable --now "${POLKIT_AGENT_UNIT}" >/dev/null 2>&1; then
        log_success "Polkit agent service enabled"
    else
        log_warning "Failed to enable polkit-agent.service; falling back to Hyprland autostart"
    fi
else
    log_info "polkit-agent.service not present; skipping enablement"
fi

# --- Quick hints ---
log_info "Verify: systemctl --user status elephant"
log_info "An existing Elephant socket requires owner inspection; no automatic unlink/fallback start"
