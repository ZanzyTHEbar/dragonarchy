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

usage() {
  cat <<'EOF'
Usage: setup.sh [options]

Options:
  --reset         Clear dotfiles install state and re-run all steps
  --secure-boot   Run Limine + sbctl Secure Boot setup (DANGEROUS; requires firmware Setup Mode)
  -h, --help      Show help
EOF
}

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

has_fingerprint_sensor() {
  # ThinkPads typically expose the reader over internal USB.
  command -v lsusb >/dev/null 2>&1 || return 1
  lsusb 2>/dev/null | grep -Eiq 'fingerprint|fprint|synaptics|validity|goodix|elan|egis'
}

fingerprint_sensor_hint() {
  # Best-effort hinting for common unsupported devices.
  # Validity/Synaptics readers often show up as 138a:* and may require python-validity + libfprint TOD.
  command -v lsusb >/dev/null 2>&1 || return 0
  if lsusb 2>/dev/null | grep -Eiq '138a:'; then
    log_warning "Detected a Validity/Synaptics-style fingerprint USB ID (138a:*). Some models require AUR driver stack (python-validity / TOD libfprint)."
  fi
}

backup_root_pam_file() {
  local pam_file="$1"
  [[ -f "$pam_file" ]] || return 0
  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  local backup_dir="/etc/pam.d/.dragonarchy-backups/fingerprint/${ts}"
  sudo mkdir -p "$backup_dir"
  sudo cp -a "$pam_file" "${backup_dir}/$(basename "$pam_file")"
  log_info "Backed up $(basename "$pam_file") -> ${backup_dir}/$(basename "$pam_file")"
}

ensure_pam_fprintd_enabled() {
  # Insert 'auth sufficient pam_fprintd.so timeout=10' before the first auth rule (fallback to password remains).
  # The timeout prevents long delays when the fingerprint reader is unresponsive.
  # This is idempotent and avoids replacing entire PAM files.
  local pam_file="$1"
  local line='auth      sufficient pam_fprintd.so timeout=10'

  if [[ ! -f "$pam_file" ]]; then
    log_warning "PAM file not found (skipping): $pam_file"
    return 0
  fi

  if sudo grep -qE '^\s*auth\s+.*pam_fprintd\.so' "$pam_file"; then
    log_info "PAM already has pam_fprintd enabled: $pam_file"
    return 0
  fi

  backup_root_pam_file "$pam_file"

  # Insert right before the first 'auth' line. If no auth line exists, insert after '#%PAM-1.0' header.
  sudo awk -v ins="$line" '
    BEGIN { done=0 }
    /^[[:space:]]*auth[[:space:]]+/ && done==0 { print ins; done=1 }
    { print }
    END {
      if (done==0) {
        # No auth lines - try to keep semantics by inserting at top (after header if present).
        # (This is rare; we still ensure the rule exists rather than silently doing nothing.)
      }
    }
  ' "$pam_file" | sudo tee "${pam_file}.dragonarchy.tmp" >/dev/null

  if ! sudo grep -qE '^\s*auth\s+.*pam_fprintd\.so' "${pam_file}.dragonarchy.tmp"; then
    # Fallback insertion (header-aware) if awk didn't place it (no auth lines)
    sudo awk -v ins="$line" '
      BEGIN { done=0 }
      /^#%PAM-1\.0/ { print; if(done==0){ print ins; done=1 }; next }
      { print }
      END { if(done==0) print ins }
    ' "$pam_file" | sudo tee "${pam_file}.dragonarchy.tmp" >/dev/null
  fi

  sudo mv "${pam_file}.dragonarchy.tmp" "$pam_file"
  sudo chmod 644 "$pam_file" 2>/dev/null || true

  log_success "Enabled fingerprint auth (with password fallback) in: $pam_file"
}

setup_fingerprint_auth() {
  log_step "Setting up fingerprint authentication (goldendragon)..."

  if ! is_arch_based; then
    log_warning "Non-Arch platform detected; skipping fingerprint setup."
    return 0
  fi

  # Detection is best-effort; allow forcing for development/debug.
  if [[ "${FORCE_FINGERPRINT:-0}" != "1" ]] && ! has_fingerprint_sensor; then
    log_info "No fingerprint sensor detected via lsusb (skipping). Set FORCE_FINGERPRINT=1 to force."
    return 0
  fi

  fingerprint_sensor_hint

  # Packages (official repos).
  install_pacman_packages fprintd libfprint usbutils

  # Service
  # fprintd is typically DBus-activated (UnitFileState=static), so it may show as "inactive" until used.
  # We'll start it once (best-effort) but we do NOT try to enable it.
  if systemctl list-unit-files 2>/dev/null | grep -q '^fprintd\.service'; then
    sudo systemctl start fprintd.service >/dev/null 2>&1 || true
  else
    log_warning "fprintd.service not found (package install may have failed)"
  fi

  # PAM enablement: sudo + polkit + sddm + local login
  ensure_pam_fprintd_enabled /etc/pam.d/sudo
  ensure_pam_fprintd_enabled /etc/pam.d/polkit-1
  ensure_pam_fprintd_enabled /etc/pam.d/system-local-login
  ensure_pam_fprintd_enabled /etc/pam.d/sddm

  # USB autosuspend fix: prevent fingerprint reader from being suspended
  # This is critical to avoid 30-40 second wake-up delays at login/lock screens
  log_info "Installing USB autosuspend fix for fingerprint reader..."
  
  local fingerprint_usb_id
  fingerprint_usb_id=$(lsusb 2>/dev/null | grep -Ei 'fingerprint|fprint|synaptics|validity|goodix|elan|egis' | awk '{print $6}' | head -1)
  
  if [[ -n "$fingerprint_usb_id" ]]; then
    local vendor_id="${fingerprint_usb_id%:*}"
    local product_id="${fingerprint_usb_id#*:}"
    
    log_info "Detected fingerprint reader: ${fingerprint_usb_id}"
    
    # Create udev rule to disable autosuspend
    sudo tee /etc/udev/rules.d/99-fingerprint-no-autosuspend.rules >/dev/null <<EOF
# Disable USB autosuspend for fingerprint reader (${fingerprint_usb_id})
# This prevents the 30-40 second wakeup delay at login/lock screens.

ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${vendor_id}", ATTR{idProduct}=="${product_id}", TEST=="power/control", ATTR{power/control}="on"
EOF
    
    log_success "Created udev rule: /etc/udev/rules.d/99-fingerprint-no-autosuspend.rules"
    
    # Reload udev rules
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger --subsystem-match=usb 2>/dev/null || true
  else
    log_warning "Could not detect fingerprint USB ID for autosuspend exclusion"
  fi

  log_info "Next: enroll a finger (interactive): fprintd-enroll"
  log_info "Then test: fprintd-verify, and try sudo / polkit prompts"
  
  # Install watchdog system to prevent recurring device claim issues
  log_info ""
  log_info "Installing fprintd watchdog system (prevents device claim issues)..."
  if bash "${SCRIPT_DIR}/install-fprintd-watchdog.sh" >/dev/null 2>&1; then
    log_success "Fprintd watchdog installed"
  else
    log_warning "Could not install fprintd watchdog (run manually if needed)"
    log_info "Manual install: bash ${SCRIPT_DIR}/install-fprintd-watchdog.sh"
  fi
  
  log_success "Fingerprint setup step completed (goldendragon)"
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
    
    # Check if nvidia-open-dkms kernel is already installed (conflicts with nvidia-dkms)
    if pacman -Qi linux-cachyos-lts-nvidia-open &>/dev/null || pacman -Qi linux-cachyos-nvidia-open &>/dev/null; then
      log_warning "NVIDIA open kernel detected. Skipping nvidia-dkms installation (conflicts with nvidia-open)."
      log_info "If you need proprietary NVIDIA drivers, remove the nvidia-open kernel first:"
      log_info "  sudo pacman -R linux-cachyos-lts-nvidia-open"
      log_info "Then re-run this setup script."
    else
      install_pacman_packages nvidia-dkms nvidia-utils || log_warning "NVIDIA packages installation failed (continuing)"
    fi
  else
    log_info "No NVIDIA dGPU detected (Intel iGPU-only). Skipping NVIDIA packages."
  fi

  log_success "Laptop packages installed"
}

setup_openfortivpn_access() {
  log_step "Provisioning OpenFortiVPN access..."

  local config="/etc/openfortivpn/config"
  local service_config="/etc/openfortivpn/waybar.conf"
  local group="openfortivpn"
  local target_user="${OPENFORTIVPN_USER:-${SUDO_USER:-$USER}}"
  local host_short
  host_short="$(hostname | cut -d. -f1)"
  local target_home=""
  target_home="$(getent passwd "$target_user" 2>/dev/null | awk -F: '{print $6}')"
  [[ -z "$target_home" ]] && target_home="$HOME"
  local marker_path="${target_home}/.config/waybar-hosts/${host_short}/vpn-enabled"
  local marker_src="${SCRIPT_DIR}/dotfiles/.config/waybar-hosts/${host_short}/vpn-enabled"

  if ! command -v sudo >/dev/null 2>&1; then
    log_warning "sudo not available; skipping OpenFortiVPN provisioning"
    return 0
  fi

  if is_arch_based; then
    install_pacman_packages openfortivpn
  else
    log_warning "Non-Arch platform detected; install openfortivpn manually."
  fi

  if ! getent group "$group" >/dev/null 2>&1; then
    if sudo groupadd -r "$group"; then
      log_success "Created group: $group"
    else
      log_warning "Failed to create group: $group"
    fi
  else
    log_info "Group already exists: $group"
  fi

  if [[ ! -f "$config" ]]; then
    sudo install -d -m 755 /etc/openfortivpn
    sudo tee "$config" >/dev/null <<'EOF'
### configuration file for openfortivpn, see man openfortivpn(1) ###

host = vpn.avular.com
port = 443
# username = you@example.com   # optional, can prompt
# password = yourpassword      # optional, better to prompt
saml-login = 8020              # or any free port; triggers browser SAML flow
#trusted-cert = <sha256_hash>  # get this first
# realm = <if needed; try without>
# set-dns = 1                  # auto-set DNS if possible
# set-routes = 1
# pppd-use-peerdns = 1
EOF
    log_success "Seeded OpenFortiVPN config at $config"
  else
    log_info "OpenFortiVPN config already present: $config"
  fi

  if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    log_warning "Cannot determine non-root user to add to $group (set OPENFORTIVPN_USER to override)"
  else
    if id -nG "$target_user" 2>/dev/null | grep -qw "$group"; then
      log_info "User already in $group: $target_user"
    else
      if sudo usermod -aG "$group" "$target_user"; then
        log_success "Added user to group: $target_user -> $group"
        log_warning "Logout/login required to pick up group membership"
      else
        log_warning "Failed to add user to group: $target_user -> $group"
      fi
    fi
  fi

  if [[ -f "$config" ]]; then
    sudo chgrp "$group" "$config" || log_warning "Failed to chgrp $config"
    sudo chmod 640 "$config" || log_warning "Failed to chmod 640 $config"
    log_success "Adjusted permissions on $config"
  else
    log_warning "OpenFortiVPN config not found: $config"
  fi

  if [[ -f "$config" ]]; then
    sudo python - <<'PY'
from pathlib import Path

src = Path("/etc/openfortivpn/config")
dst = Path("/etc/openfortivpn/waybar.conf")

lines = src.read_text().splitlines()
filtered = []
for line in lines:
    stripped = line.strip()
    if stripped.startswith("#") or not stripped:
        filtered.append(line)
        continue
    if stripped.lower().startswith("saml-login"):
        continue
    filtered.append(line)

dst.write_text("\n".join(filtered) + "\n")
PY
    sudo chgrp "$group" "$service_config" || log_warning "Failed to chgrp $service_config"
    sudo chmod 640 "$service_config" || log_warning "Failed to chmod 640 $service_config"
    log_success "Generated service config: $service_config"
  fi

  if [[ -f /etc/systemd/system/openfortivpn.service || -f /etc/systemd/system/openfortivpn-cleanup.service ]]; then
    sudo systemctl daemon-reload >/dev/null 2>&1 || log_warning "systemctl daemon-reload failed"
  fi

  if [[ -f "$marker_src" ]]; then
    mkdir -p "$(dirname "$marker_path")"
    local marker_link="$marker_src"
    if command -v realpath >/dev/null 2>&1; then
      local marker_dir rel
      marker_dir="$(dirname "$marker_path")"
      rel="$(realpath --relative-to="$marker_dir" "$marker_src" 2>/dev/null || true)"
      if [[ -n "$rel" ]]; then
        marker_link="$rel"
      fi
    fi
    if [[ "$target_user" != "$USER" ]]; then
      sudo -u "$target_user" ln -snf "$marker_link" "$marker_path"
    else
      ln -snf "$marker_link" "$marker_path"
    fi
    log_success "Provisioned Waybar host marker: $marker_path"
  else
    log_warning "Waybar host marker missing in dotfiles: $marker_src"
  fi
}

openfortivpn_is_provisioned() {
  local config="/etc/openfortivpn/config"
  local service_config="/etc/openfortivpn/waybar.conf"
  local group="openfortivpn"
  local target_user="${OPENFORTIVPN_USER:-${SUDO_USER:-$USER}}"
  local host_short
  host_short="$(hostname | cut -d. -f1)"
  local target_home=""
  target_home="$(getent passwd "$target_user" 2>/dev/null | awk -F: '{print $6}')"
  [[ -z "$target_home" ]] && target_home="$HOME"
  local marker_path="${target_home}/.config/waybar-hosts/${host_short}/vpn-enabled"

  command -v openfortivpn >/dev/null 2>&1 || return 1
  getent group "$group" >/dev/null 2>&1 || return 1
  [[ -f "$config" ]] || return 1
  [[ -f "$service_config" ]] || return 1
  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-unit-files --type=service 2>/dev/null | grep -q '^openfortivpn\.service' || return 1
    systemctl list-unit-files --type=service 2>/dev/null | grep -q '^openfortivpn-cleanup\.service' || return 1
  fi
  [[ "$(stat -c '%G' "$config" 2>/dev/null || true)" == "$group" ]] || return 1
  getent group "$group" | awk -F: -v u="$target_user" '
    {
      n=split($4, users, ",");
      for (i=1; i<=n; i++) {
        if (users[i] == u) { found=1; break }
      }
    }
    END { exit(found ? 0 : 1) }
  ' || return 1
  [[ -f "$marker_path" ]] || return 1
  return 0
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
    if command -v systemctl >/dev/null 2>&1; then
      if systemctl list-unit-files 2>/dev/null | grep -q '^systemd-resolved\.service'; then
        sudo systemctl enable --now systemd-resolved.service >/dev/null 2>&1 || true
      fi
    fi
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
      systemctl --user enable --now battery-monitor.timer 2>/dev/null || true
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

  local do_reset="false"
  local run_secure_boot="false"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reset) do_reset="true"; shift ;;
      --secure-boot) run_secure_boot="true"; shift ;;
      -h|--help) usage; return 0 ;;
      *) log_warning "Ignoring unknown option: $1"; shift ;;
    esac
  done

  if [[ "$do_reset" == "true" ]]; then
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

  if openfortivpn_is_provisioned; then
    log_info "✓ OpenFortiVPN access already provisioned (skipped)"
  else
    log_warning "OpenFortiVPN access incomplete; provisioning now..."
    setup_openfortivpn_access && mark_step_completed "goldendragon-openfortivpn"
  fi
  echo

  if ! is_step_completed "goldendragon-fingerprint"; then
    setup_fingerprint_auth && mark_step_completed "goldendragon-fingerprint"
  else
    log_info "✓ Fingerprint setup already handled (skipped)"
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
  echo

  if [[ "$run_secure_boot" == "true" ]]; then
    log_warning "Secure Boot setup requested (--secure-boot)."
    if [[ -f "${SCRIPT_DIR}/setup-secure-boot.sh" ]]; then
      bash "${SCRIPT_DIR}/setup-secure-boot.sh" --yes
    else
      log_error "Secure Boot helper not found: ${SCRIPT_DIR}/setup-secure-boot.sh"
      log_info "Run manually from: ${SCRIPT_DIR}"
    fi
    echo
  fi

  post_setup_instructions
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
