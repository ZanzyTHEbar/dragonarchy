#!/usr/bin/env bash
#
# GoldenDragon Secure Boot Setup (Limine + sbctl)
# Lenovo ThinkPad P16s Gen 4 (Intel) - Type 21QV/21QW
#
# IMPORTANT:
# - This script modifies UEFI Secure Boot keys and signs EFI binaries.
# - You MUST set Secure Boot to "Setup Mode" (or clear existing keys) in firmware BEFORE enrolling keys.
# - For Limine, we only sign Limine's EFI binary (do NOT sbctl-batch-sign kernels, it can break Limine checksum verification).
#
# References:
# - CachyOS Secure Boot + sbctl guidance (Limine section)
#

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"
BOOT_LIB="${PROJECT_ROOT}/scripts/lib/bootloader.sh"

# shellcheck disable=SC1091
source "$LOG_LIB"
# shellcheck disable=SC1091
source "$BOOT_LIB"

ASSUME_YES=false
ENROLL_MICROSOFT=true
ENROLL_FIRMWARE_BUILTIN=false
REBOOT_FIRMWARE=false

usage() {
  cat <<'EOF'
Usage: setup-secure-boot.sh [options]

Options:
  --yes                 Proceed without interactive confirmation
  --no-microsoft        Do not enroll Microsoft's keys (default enrolls them)
  --firmware-builtin    Also enroll firmware built-in keys (if supported by sbctl)
  --reboot-firmware     Reboot into firmware setup at the end (systemctl reboot --firmware-setup)
  -h, --help            Show help

Typical flow:
  1) Reboot to firmware and set Secure Boot to "Setup Mode" / clear keys
  2) Run: sudo bash ./setup-secure-boot.sh --yes
  3) Reboot to firmware and enable Secure Boot
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES=true; shift ;;
    --no-microsoft) ENROLL_MICROSOFT=false; shift ;;
    --firmware-builtin) ENROLL_FIRMWARE_BUILTIN=true; shift ;;
    --reboot-firmware) REBOOT_FIRMWARE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

require_uefi() {
  if [[ ! -d /sys/firmware/efi/efivars ]]; then
    log_fatal "This system is not booted in UEFI mode (/sys/firmware/efi/efivars missing)."
  fi
}

require_limine() {
  local bl
  bl="$(detect_bootloader)"
  if [[ "$bl" != "limine" ]]; then
    log_fatal "Detected bootloader '$bl' (expected limine). Refusing to proceed."
  fi
}

install_arch_pkg() {
  local pkg="$1"
  pacman -Qi "$pkg" &>/dev/null || pacman -S --noconfirm --needed "$pkg"
}

install_dependencies() {
  if ! command -v pacman >/dev/null 2>&1; then
    log_fatal "pacman not found (expected CachyOS/Arch). Install sbctl manually for your distro."
  fi
  log_step "Installing dependencies..."
  install_arch_pkg sbctl
  # Helpful tooling (best-effort)
  install_arch_pkg efibootmgr || true
  install_arch_pkg binutils || true
  log_success "Dependencies installed"
}

sbctl_field() {
  # Args: field label regex, e.g. "Setup Mode" or "Owner GUID"
  local field="$1"
  sbctl status 2>/dev/null | awk -F: -v f="$field" 'BEGIN{IGNORECASE=1} $1 ~ f {print $2; exit}' | xargs || true
}

sbctl_setup_mode_enabled() {
  local v
  v="$(sbctl_field '^Setup Mode')"
  echo "$v" | grep -qi 'enabled'
}

sbctl_owner_guid_present() {
  local v
  v="$(sbctl_field '^Owner (GUID|UUID)')"
  [[ -n "$v" ]]
}

confirm_danger() {
  log_warning "This will enroll custom Secure Boot keys into UEFI variables."
  log_warning "If done incorrectly, your system may not boot until keys are fixed in firmware."
  if [[ "$ASSUME_YES" == "true" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    log_fatal "No TTY available for confirmation. Re-run with --yes if you understand the risk."
  fi
  local ans=""
  read -r -p "Proceed with sbctl key enrollment? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

ensure_keys_and_enrollment() {
  log_step "Checking Secure Boot state..."

  local setup_mode
  setup_mode="$(sbctl_field '^Setup Mode')"
  log_info "UEFI Setup Mode: ${setup_mode:-unknown}"

  # If we don't have an owner GUID and Setup Mode isn't enabled, we can't enroll.
  if ! sbctl_owner_guid_present && ! sbctl_setup_mode_enabled; then
    log_error "sbctl owner keys not present and UEFI is NOT in Setup Mode."
    log_error "Reboot to firmware, clear Secure Boot keys / set Setup Mode, then re-run this script."
    log_info "Tip: systemctl reboot --firmware-setup"
    exit 1
  fi

  if sbctl_setup_mode_enabled; then
    confirm_danger || { log_info "Cancelled."; exit 0; }

    if ! sbctl_owner_guid_present; then
      log_step "Creating Secure Boot keys (sbctl create-keys)..."
      sbctl create-keys
      log_success "Secure Boot keys created"
    else
      log_info "Owner GUID already present; skipping create-keys"
    fi

    log_step "Enrolling keys into firmware variables (sbctl enroll-keys)..."
    local args=()
    if [[ "$ENROLL_MICROSOFT" == "true" ]]; then
      args+=(--microsoft)
    fi
    if [[ "$ENROLL_FIRMWARE_BUILTIN" == "true" ]]; then
      args+=(--firmware-builtin)
    fi
    sbctl enroll-keys "${args[@]}"
    log_success "Keys enrolled"
  else
    log_info "UEFI is not in Setup Mode; skipping enroll-keys (assumes keys already enrolled)."
  fi
}

find_esp_dir() {
  local d
  for d in /boot /boot/efi /efi; do
    if [[ -d "$d/EFI" ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

file_contains_limine() {
  local f="$1"
  if command -v strings >/dev/null 2>&1; then
    strings -n 6 "$f" 2>/dev/null | grep -qi 'limine' && return 0
  fi
  return 1
}

collect_limine_efi_candidates() {
  local esp="$1"
  local -a out=()

  # Prefer explicit limine-named binaries
  while IFS= read -r -d '' f; do
    out+=("$f")
  done < <(find "$esp/EFI" -type f \( -iname '*limine*.efi' -o -iname '*liminex64*.efi' \) -print0 2>/dev/null || true)

  # Consider the default fallback loader if it looks like Limine
  local fallback="$esp/EFI/BOOT/BOOTX64.EFI"
  if [[ -f "$fallback" ]] && file_contains_limine "$fallback"; then
    out+=("$fallback")
  fi

  # De-duplicate
  if [[ ${#out[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${out[@]}" | awk '!seen[$0]++'
}

sign_limine() {
  log_step "Signing Limine EFI binary (Secure Boot)..."

  if command -v limine-enroll-config >/dev/null 2>&1; then
    log_info "Using limine-enroll-config (CachyOS helper)..."
    limine-enroll-config
  else
    local esp
    esp="$(find_esp_dir || true)"
    if [[ -z "$esp" ]]; then
      log_fatal "Could not locate EFI System Partition mount (looked for /boot/EFI, /boot/efi/EFI, /efi/EFI)."
    fi

    local candidates
    candidates="$(collect_limine_efi_candidates "$esp" || true)"
    if [[ -z "$candidates" ]]; then
      log_fatal "Could not find a Limine EFI binary under $esp/EFI. If you know the path, sign it manually: sbctl sign -s <path>"
    fi

    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      log_info "Signing: $f"
      sbctl sign -s "$f"
    done <<<"$candidates"
  fi

  if command -v limine-update >/dev/null 2>&1; then
    log_info "Running limine-update..."
    limine-update
  elif command -v limine-mkinitcpio >/dev/null 2>&1; then
    log_info "Running limine-mkinitcpio..."
    limine-mkinitcpio
  else
    log_warning "limine-update/limine-mkinitcpio not found; ensure Limine entries are updated as needed."
  fi

  log_success "Limine signing step complete"
}

final_status() {
  echo
  log_info "Secure Boot status (sbctl):"
  sbctl status || true
  echo
  log_info "Next steps:"
  echo "  1) Reboot to firmware and ENABLE Secure Boot"
  echo "     - Tip: systemctl reboot --firmware-setup"
  echo "  2) After boot, verify:"
  echo "     - sbctl status"
  echo "     - bootctl status  (should show: Secure Boot: enabled)"
  echo
  log_warning "Limine note: do NOT sbctl-batch-sign kernels on Limine; only sign Limine's EFI binary."
  echo
}

main() {
  require_uefi
  require_limine
  install_dependencies
  ensure_keys_and_enrollment
  sign_limine
  final_status

  if [[ "$REBOOT_FIRMWARE" == "true" ]]; then
    log_warning "Rebooting to firmware setup..."
    systemctl reboot --firmware-setup
  fi
}

main

