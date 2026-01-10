#!/usr/bin/env bash
#
# GoldenDragon Host-Specific Setup
# Lenovo ThinkPad P16s Gen 4 (Intel) - Type 21QV/21QW
#
# Goals:
# - Idempotent (safe to re-run)
# - Laptop-grade power management + sleep/lid behavior
# - GPU-aware setup (Intel-only or Intel+NVIDIA, auto-detected)
# - Host-scoped /etc drop-ins live under: hosts/goldendragon/etc/

set -euo pipefail
IFS=$'\n\t'

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"
STATE_LIB="${PROJECT_ROOT}/scripts/lib/install-state.sh"
BOOT_LIB="${PROJECT_ROOT}/scripts/lib/bootloader.sh"

# Source utilities
# shellcheck disable=SC1091
source "$LOG_LIB"
# shellcheck disable=SC1091
source "$STATE_LIB"
if [[ -f "$BOOT_LIB" ]]; then
  # shellcheck disable=SC1091
  source "$BOOT_LIB"
fi

is_arch_based() {
  command -v pacman >/dev/null 2>&1
}

install_pacman_packages() {
  local pkgs=("$@")
  local to_install=()
  local p

  for p in "${pkgs[@]}"; do
    pacman -Qi "$p" &>/dev/null || to_install+=("$p")
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    log_info "All required packages already installed."
    return 0
  fi

  log_info "Installing packages: ${to_install[*]}"
  sudo pacman -S --noconfirm --needed "${to_install[@]}" || log_warning "Some packages failed to install (continuing)"
}

has_nvidia_gpu() {
  command -v lspci >/dev/null 2>&1 || return 1
  lspci -nn 2>/dev/null \
    | grep -Ei 'VGA compatible controller|3D controller|Display controller' \
    | grep -qi 'nvidia'
}

setup_goldendragon_packages() {
  log_step "Installing laptop packages (ThinkPad baseline)..."

  if ! is_arch_based; then
    log_warning "Non-Arch platform detected; skipping package installs (expected CachyOS/Arch)."
    return 0
  fi

  # TLP conflicts with power-profiles-daemon on many systems.
  if pacman -Qi power-profiles-daemon &>/dev/null; then
    log_info "Removing conflicting power-profiles-daemon (TLP conflict)..."
    sudo systemctl stop power-profiles-daemon.service 2>/dev/null || true
    sudo systemctl disable power-profiles-daemon.service 2>/dev/null || true
    sudo pacman -Rdd --noconfirm power-profiles-daemon || log_warning "Failed to remove power-profiles-daemon"
  fi

  local base_pkgs=(
    # Power + thermals
    tlp tlp-rdw powertop thermald lm_sensors acpid
    # Firmware updates
    fwupd
    # Intel GPU / media acceleration tooling
    intel-media-driver libva-utils vulkan-intel
    # Optional diagnostics
    intel-gpu-tools
  )

  install_pacman_packages "${base_pkgs[@]}"

  if has_nvidia_gpu; then
    log_info "Detected NVIDIA dGPU (hybrid graphics). Installing NVIDIA packages..."
    install_pacman_packages nvidia-dkms nvidia-utils
  else
    log_info "No NVIDIA dGPU detected (Intel iGPU-only). Skipping NVIDIA packages."
  fi

  log_success "Laptop packages installed"
}

apply_host_system_configs() {
  log_step "Applying host /etc drop-ins..."

  local src="${SCRIPT_DIR}/etc/"
  if [[ ! -d "$src" ]]; then
    log_warning "Host etc directory missing: $src (skipping)"
    return 0
  fi

  if copy_dir_if_changed "$src" /etc/; then
    log_success "System configs updated from $src"
    reset_step "goldendragon-restart-resolved"
  else
    log_info "System configs unchanged"
  fi

  # Important: do NOT restart systemd-logind during an active session.
  log_warning "systemd-logind changes require REBOOT (do not restart logind manually)."
}

restart_resolved_if_needed() {
  # Apply DNS changes (only if configs changed or first time)
  if ! is_step_completed "goldendragon-restart-resolved"; then
    log_step "Restarting systemd-resolved to apply DNS changes (if running)..."
    if restart_if_running systemd-resolved; then
      log_success "systemd-resolved restarted"
    else
      log_info "systemd-resolved not running (skipped)"
    fi
    mark_step_completed "goldendragon-restart-resolved"
  else
    log_info "✓ DNS configuration already applied (skipped)"
  fi
}

setup_power_management_services() {
  log_step "Enabling power management services..."

  if command_exists tlp; then
    # Avoid rfkill save/restore races with TLP
    sudo systemctl mask systemd-rfkill.service 2>/dev/null || true
    sudo systemctl mask systemd-rfkill.socket 2>/dev/null || true

    sudo systemctl enable tlp.service 2>/dev/null || true
    sudo systemctl enable tlp-sleep.service 2>/dev/null || true
  fi

  if systemctl list-unit-files 2>/dev/null | grep -q '^thermald\.service'; then
    sudo systemctl enable thermald.service 2>/dev/null || true
  fi

  if systemctl list-unit-files 2>/dev/null | grep -q '^acpid\.service'; then
    sudo systemctl enable acpid.service 2>/dev/null || true
  fi

  log_success "Power management services configured"
}

ensure_nvidia_kernel_params() {
  if ! has_nvidia_gpu; then
    return 0
  fi

  log_step "Ensuring NVIDIA kernel parameters for Wayland..."

  if grep -qw "nvidia-drm.modeset=1" /proc/cmdline 2>/dev/null; then
    log_success "Kernel parameter nvidia-drm.modeset=1 already active in current boot"
    return 0
  fi

  if [[ ! -f "$BOOT_LIB" ]]; then
    log_warning "Bootloader helper not found at $BOOT_LIB; add nvidia-drm.modeset=1 manually"
    return 0
  fi

  log_info "Updating bootloader configuration to include nvidia-drm.modeset=1..."
  if sudo env LOG_LIB="$LOG_LIB" BOOT_LIB="$BOOT_LIB" KERNEL_PARAMS="nvidia-drm.modeset=1" bash -c '
    set -euo pipefail
    # shellcheck disable=SC1091
    source "$LOG_LIB"
    # shellcheck disable=SC1091
    source "$BOOT_LIB"
    boot_append_kernel_params "$KERNEL_PARAMS"
    boot_rebuild_if_changed
  '; then
    log_success "Bootloader updated for NVIDIA (reboot required)"
  else
    log_warning "Failed to update bootloader automatically; add nvidia-drm.modeset=1 manually"
  fi

  log_warning "Reboot required for NVIDIA kernel parameter changes."
}

setup_battery_tooling() {
  log_step "Setting up battery tooling..."

  mkdir -p "$HOME/.local/bin"

  cat >"$HOME/.local/bin/battery-status" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Prefer UPower for portability across laptops
if command -v upower >/dev/null 2>&1; then
  bat="$(upower -e | grep -m1 -E 'battery|BAT' || true)"
  if [[ -n "$bat" ]]; then
    upower -i "$bat" | grep -E 'state|percentage|time to empty|time to full|energy-rate' || true
    exit 0
  fi
fi

# Fallback to sysfs (best-effort)
bat_path="/sys/class/power_supply/BAT0"
if [[ -f "$bat_path/capacity" ]]; then
  cap="$(cat "$bat_path/capacity")"
  st="$(cat "$bat_path/status" 2>/dev/null || echo unknown)"
  echo "Battery: ${cap}% (${st})"
else
  echo "No battery found"
fi
EOF

  chmod +x "$HOME/.local/bin/battery-status"

  # Enable battery-monitor timer if present (installed via packages/hardware)
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user list-unit-files 2>/dev/null | grep -q '^battery-monitor\.timer'; then
      systemctl --user enable battery-monitor.timer 2>/dev/null || true
      log_info "battery-monitor.timer enabled (user)"
    else
      log_info "battery-monitor.timer not found; battery-status installed only"
    fi
  fi

  log_success "Battery tooling configured"
}

post_setup_instructions() {
  echo
  log_success "🎉 GoldenDragon setup completed!"
  echo
  log_info "Post-setup checklist:"
  echo "  1. Reboot (required for logind + any kernel parameter changes)"
  echo "  2. sensors: sudo sensors-detect && sensors"
  echo "  3. tlp: tlp-stat -s -p -b"
  echo "  4. sleep: cat /sys/power/mem_sleep && systemctl suspend"
  echo "  5. gpu: lspci -k | grep -A3 -i 'vga\\|3d\\|display\\|nvidia'"
  echo "  6. fwupd: fwupdmgr get-devices && fwupdmgr get-updates"
  echo
}

main() {
  log_info "🚀 Setting up GoldenDragon (ThinkPad P16s Gen 4 Intel)..."
  echo

  # Handle --reset flag to force re-run all steps
  if [[ "${1:-}" == "--reset" ]]; then
    reset_all_steps
    log_warning "Installation state reset. All steps will be re-run."
    echo
  fi

  if ! is_step_completed "goldendragon-packages"; then
    setup_goldendragon_packages && mark_step_completed "goldendragon-packages"
  else
    log_info "✓ Packages already installed (skipped)"
  fi
  echo

  if ! is_step_completed "goldendragon-system-configs"; then
    apply_host_system_configs && mark_step_completed "goldendragon-system-configs"
  else
    # Still check for drift
    apply_host_system_configs || true
    log_info "✓ Host system configs already applied (checked)"
  fi
  echo

  restart_resolved_if_needed
  echo

  if ! is_step_completed "goldendragon-power-services"; then
    setup_power_management_services && mark_step_completed "goldendragon-power-services"
  else
    log_info "✓ Power management services already configured (skipped)"
  fi
  echo

  if ! is_step_completed "goldendragon-nvidia-kparams"; then
    ensure_nvidia_kernel_params && mark_step_completed "goldendragon-nvidia-kparams"
  else
    log_info "✓ NVIDIA kernel parameter step already handled (skipped)"
  fi
  echo

  if ! is_step_completed "goldendragon-battery"; then
    setup_battery_tooling && mark_step_completed "goldendragon-battery"
  else
    log_info "✓ Battery tooling already configured (skipped)"
  fi

  post_setup_instructions
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
