#!/usr/bin/env bash
#
# enable-sleep-hibernate.sh - FireDragon hibernation + sleep plumbing
#
# What this does:
# - Ensures a disk-backed swap area sized to RAM (swapfile by default)
# - Persists it via /etc/fstab and enables it
# - Computes resume UUID (+ resume_offset for swapfiles)
# - Ensures mkinitcpio has the correct resume hook (resume or sd-resume)
# - Adds kernel cmdline resume parameters (Limine via limine-entry-tool drop-in when available)
# - Installs systemd sleep/logind configs to expose hibernate in login1/SDDM
#
# Usage:
#   ./enable-sleep-hibernate.sh
#
# Optional environment overrides:
#   SWAPFILE_PATH=/swapfile
#   SWAPFILE_PRIORITY=1000
#   SWAP_SIZE_GIB=16          # defaults to ceil(RAM GiB)
#   FORCE_RECREATE=0|1        # recreate swapfile if it exists but is the wrong size
#

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOG_LIB="${PROJECT_ROOT}/scripts/lib/logging.sh"
BOOT_LIB="${PROJECT_ROOT}/scripts/lib/bootloader.sh"

if [[ -f "$LOG_LIB" ]]; then
  # shellcheck disable=SC1091
  source "$LOG_LIB"
else
  log_info()    { echo "[INFO] $*"; }
  log_success() { echo "[SUCCESS] $*"; }
  log_warning() { echo "[WARNING] $*"; }
  log_error()   { echo "[ERROR] $*"; }
  log_step()    { echo "[STEP] $*"; }
  command_exists() { command -v "$1" >/dev/null 2>&1; }
fi

if [[ -f "$BOOT_LIB" ]]; then
  # shellcheck disable=SC1091
  source "$BOOT_LIB"
fi

SWAPFILE_PATH="${SWAPFILE_PATH:-/swapfile}"
SWAPFILE_PRIORITY="${SWAPFILE_PRIORITY:-1000}"
SWAP_SIZE_GIB="${SWAP_SIZE_GIB:-}"
FORCE_RECREATE="${FORCE_RECREATE:-0}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

bytes_to_gib_ceil() {
  local bytes="$1"
  local gib=$((1024 * 1024 * 1024))
  echo $(((bytes + gib - 1) / gib))
}

get_ram_bytes() {
  local kb
  kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  echo $((kb * 1024))
}

swap_is_active() {
  local needle="$1"
  swapon --show --noheadings --output=NAME 2>/dev/null | awk '{print $1}' | grep -Fxq "$needle"
}

ensure_swapfile_fstab() {
  local swapfile="$1"
  local pri="$2"
  local fstab="/etc/fstab"
  local line="${swapfile} none swap defaults,pri=${pri} 0 0"

  if grep -Eq "^[[:space:]]*${swapfile}[[:space:]]+none[[:space:]]+swap[[:space:]]" "$fstab"; then
    # Replace existing line for this swapfile (keep idempotent)
    sed -i "s|^[[:space:]]*${swapfile}[[:space:]]\\+none[[:space:]]\\+swap.*|${line}|" "$fstab"
    return 0
  fi

  {
    echo
    echo "# firedragon: hibernate swapfile (managed by dotfiles)"
    echo "$line"
  } >>"$fstab"
}

create_or_fix_swapfile() {
  local swapfile="$1"
  local size_gib="$2"
  local want_bytes=$((size_gib * 1024 * 1024 * 1024))

  log_step "Ensuring swapfile exists at ${swapfile} (${size_gib} GiB)"

  if [[ -e "$swapfile" ]]; then
    local current_bytes=0
    current_bytes="$(stat -c %s "$swapfile" 2>/dev/null || echo 0)"

    if [[ "$current_bytes" -ge "$want_bytes" && "$FORCE_RECREATE" -ne 1 ]]; then
      log_info "Swapfile already exists and is large enough"
    else
      if swap_is_active "$swapfile"; then
        log_info "swapoff ${swapfile} (to recreate)"
        swapoff "$swapfile" 2>/dev/null || true
      fi
      if [[ "$FORCE_RECREATE" -ne 1 ]]; then
        log_error "Existing ${swapfile} is too small (${current_bytes} bytes). Re-run with FORCE_RECREATE=1 to recreate it."
        exit 1
      fi
      rm -f "$swapfile"
    fi
  fi

  if [[ ! -e "$swapfile" ]]; then
    mkdir -p "$(dirname "$swapfile")"

    local fstype=""
    fstype="$(findmnt -no FSTYPE -T "$(dirname "$swapfile")" 2>/dev/null || true)"

    if [[ "$fstype" == "btrfs" ]] && command_exists btrfs; then
      if btrfs filesystem mkswapfile --size "${size_gib}G" --uuid clear "$swapfile" >/dev/null 2>&1; then
        chmod 600 "$swapfile" 2>/dev/null || true
        log_success "Created btrfs swapfile via btrfs-progs"
      else
        log_warning "btrfs mkswapfile failed/unavailable; falling back to manual swapfile creation (may not be hibernate-safe on btrfs)."
        : >"$swapfile"
        if command_exists chattr; then
          chattr +C "$swapfile" 2>/dev/null || true
        fi
        fallocate -l "${size_gib}G" "$swapfile"
        chmod 600 "$swapfile"
        mkswap "$swapfile" >/dev/null
      fi
    else
      fallocate -l "${size_gib}G" "$swapfile"
      chmod 600 "$swapfile"
      mkswap "$swapfile" >/dev/null
      log_success "Created swapfile"
    fi
  fi

  ensure_swapfile_fstab "$swapfile" "$SWAPFILE_PRIORITY"

  if ! swap_is_active "$swapfile"; then
    swapon "$swapfile"
    log_success "Enabled swapfile"
  else
    log_info "Swapfile already active"
  fi
}

compute_resume_offset_pages() {
  local swapfile="$1"

  # Prefer btrfs-progs helper when available (returns pages-ready resume_offset with -r on newer btrfs-progs).
  local fstype=""
  fstype="$(findmnt -no FSTYPE -T "$swapfile" 2>/dev/null || true)"
  if [[ "$fstype" == "btrfs" ]] && command_exists btrfs; then
    local out=""
    out="$(btrfs inspect-internal map-swapfile -r "$swapfile" 2>/dev/null || true)"
    out="$(printf '%s' "$out" | tr -d '\n' | xargs || true)"
    if [[ "$out" =~ ^[0-9]+$ ]]; then
      echo "$out"
      return 0
    fi
  fi

  if ! command_exists filefrag; then
    log_error "filefrag not found (package: e2fsprogs). Cannot compute resume_offset for swapfile hibernation."
    return 1
  fi

  local phys=""
  phys="$(filefrag -v "$swapfile" 2>/dev/null | awk '$1=="0:"{print $4; exit}' | sed 's/:$//' | cut -d.. -f1)"
  if [[ -z "$phys" || ! "$phys" =~ ^[0-9]+$ ]]; then
    log_error "Failed to parse physical offset from filefrag output"
    return 1
  fi

  local fs_block_size page_size
  fs_block_size="$(stat -f -c %S "$swapfile" 2>/dev/null || echo 4096)"
  page_size="$(getconf PAGE_SIZE 2>/dev/null || echo 4096)"

  echo $((phys * fs_block_size / page_size))
}

ensure_mkinitcpio_resume_hook() {
  local cfg="/etc/mkinitcpio.conf"
  [[ -f "$cfg" ]] || { log_warning "mkinitcpio config not found at ${cfg}; skipping hook update"; return 0; }
  command_exists mkinitcpio || { log_warning "mkinitcpio not installed; skipping hook update"; return 0; }

  local hooks_line=""
  hooks_line="$(grep -E '^HOOKS=' "$cfg" | head -n1 || true)"
  [[ -n "$hooks_line" ]] || { log_warning "No HOOKS= line found in ${cfg}; skipping hook update"; return 0; }

  local want="resume"
  if [[ "$hooks_line" =~ (^|[[:space:]])systemd($|[[:space:]]) ]]; then
    if [[ -f /usr/lib/initcpio/hooks/sd-resume ]]; then
      want="sd-resume"
    fi
  fi

  # Extract hook tokens inside HOOKS=(...)
  local inner=""
  inner="$(printf '%s' "$hooks_line" | sed -E 's/^HOOKS=\((.*)\)$/\1/' | xargs || true)"

  # shellcheck disable=SC2206
  local hooks=($inner)
  local h
  for h in "${hooks[@]}"; do
    if [[ "$h" == "$want" ]]; then
      log_info "mkinitcpio: ${want} hook already present"
      return 0
    fi
  done

  local after="" before=""
  if [[ "$want" == "sd-resume" ]]; then
    after="sd-encrypt"
    before="filesystems"
  else
    after="encrypt"
    before="filesystems"
  fi

  local new_hooks=()
  local inserted=0
  for h in "${hooks[@]}"; do
    if [[ "$inserted" -eq 0 && "$h" == "$before" ]]; then
      new_hooks+=("$want")
      inserted=1
    fi
    new_hooks+=("$h")
    if [[ "$inserted" -eq 0 && "$h" == "$after" ]]; then
      new_hooks+=("$want")
      inserted=1
    fi
  done
  if [[ "$inserted" -eq 0 ]]; then
    new_hooks+=("$want")
  fi

  local new_line="HOOKS=(${new_hooks[*]})"
  cp "$cfg" "${cfg}.bak.$(date +%Y%m%d_%H%M%S)"
  awk -v repl="$new_line" 'BEGIN{done=0} /^HOOKS=/ && !done {print repl; done=1; next} {print}' "$cfg" >"${cfg}.tmp"
  mv "${cfg}.tmp" "$cfg"
  sync

  log_success "mkinitcpio: added ${want} hook"
  log_info "Rebuilding initramfs (mkinitcpio -P)..."
  mkinitcpio -P || log_warning "mkinitcpio returned non-zero; please review output"
}

install_systemd_confs() {
  local sleep_src="${PROJECT_ROOT}/hosts/firedragon/etc/systemd/sleep.conf.d/10-firedragon-sleep.conf"
  local logind_src="${PROJECT_ROOT}/hosts/firedragon/etc/systemd/logind.conf.d/10-firedragon-lid.conf"

  if [[ -f "$sleep_src" ]]; then
    install -d -m 755 /etc/systemd/sleep.conf.d
    install -m 644 "$sleep_src" /etc/systemd/sleep.conf.d/10-firedragon-sleep.conf
  fi

  if [[ -f "$logind_src" ]]; then
    install -d -m 755 /etc/systemd/logind.conf.d
    install -m 644 "$logind_src" /etc/systemd/logind.conf.d/10-firedragon-lid.conf
  fi
}

main() {
  log_info "Configuring sleep + hibernate prerequisites for firedragon..."

  local ram_bytes ram_gib
  ram_bytes="$(get_ram_bytes)"
  ram_gib="$(bytes_to_gib_ceil "$ram_bytes")"

  local swap_gib
  if [[ -n "$SWAP_SIZE_GIB" ]]; then
    swap_gib="$SWAP_SIZE_GIB"
  else
    swap_gib="$ram_gib"
  fi

  log_info "RAM detected: ~${ram_gib} GiB"

  # Prefer an existing disk-backed swap device if it is already large enough.
  local chosen_name="" chosen_type="" chosen_size=0
  if command_exists swapon; then
    while read -r name type size prio; do
      [[ -n "${name:-}" ]] || continue
      [[ "$name" == /dev/zram* ]] && continue
      [[ -n "${size:-}" ]] || continue
      if [[ "$size" -ge "$ram_bytes" ]]; then
        if [[ -z "$chosen_name" ]]; then
          chosen_name="$name"; chosen_type="$type"; chosen_size="$size"
          continue
        fi
        # Prefer partition over file; otherwise prefer larger.
        if [[ "$chosen_type" != "partition" && "$type" == "partition" ]]; then
          chosen_name="$name"; chosen_type="$type"; chosen_size="$size"
          continue
        fi
        if [[ "$size" -gt "$chosen_size" ]]; then
          chosen_name="$name"; chosen_type="$type"; chosen_size="$size"
          continue
        fi
      fi
    done < <(swapon --show --noheadings --bytes --output=NAME,TYPE,SIZE,PRIO 2>/dev/null || true)
  fi

  if [[ -z "$chosen_name" ]]; then
    log_info "No existing disk-backed swap large enough for hibernate; creating swapfile..."
    create_or_fix_swapfile "$SWAPFILE_PATH" "$swap_gib"
    chosen_name="$SWAPFILE_PATH"
    chosen_type="file"
  else
    log_success "Using existing swap (${chosen_type}): ${chosen_name}"
  fi

  # Determine resume UUID + optional resume_offset
  local resume_uuid="" resume_offset="" resume_params=""

  if [[ "$chosen_type" == "file" || "$chosen_name" != /dev/* ]]; then
    # Swapfile resume points at the *filesystem block device* holding the file.
    local src=""
    src="$(findmnt -no SOURCE -T "$chosen_name" 2>/dev/null | head -n1 || true)"
    if [[ -z "$src" ]]; then
      src="$(df --output=source "$chosen_name" 2>/dev/null | tail -n1 | xargs || true)"
    fi
    src="${src%%[*}"
    if [[ "$src" == UUID=* ]]; then
      resume_uuid="${src#UUID=}"
    elif [[ -n "$src" ]]; then
      resume_uuid="$(blkid -s UUID -o value "$src" 2>/dev/null || true)"
    fi

    if [[ -z "$resume_uuid" ]]; then
      log_error "Could not determine filesystem UUID for swapfile resume device (source=${src:-<empty>})"
      exit 1
    fi

    resume_offset="$(compute_resume_offset_pages "$chosen_name")"
    resume_params="resume=UUID=${resume_uuid} resume_offset=${resume_offset}"
  else
    # Swap partition/device
    resume_uuid="$(blkid -s UUID -o value "$chosen_name" 2>/dev/null || true)"
    if [[ -z "$resume_uuid" ]]; then
      log_error "Could not determine UUID for swap device: $chosen_name"
      exit 1
    fi
    resume_params="resume=UUID=${resume_uuid}"
  fi

  log_success "Resume parameters: ${resume_params}"

  # Install sleep/logind confs (do not restart logind during an active session)
  install_systemd_confs

  # Ensure initramfs has resume support (mkinitcpio)
  ensure_mkinitcpio_resume_hook

  # Bootloader kernel cmdline: use helper when available
  if declare -F boot_append_kernel_params >/dev/null 2>&1; then
    boot_append_kernel_params "$resume_params"
    boot_rebuild_if_changed
  fi

  # Limine persistence: install a limine-entry-tool drop-in when possible
  local bl="unknown"
  if declare -F detect_bootloader >/dev/null 2>&1; then
    bl="$(detect_bootloader)"
  fi
  if [[ "$bl" == "limine" ]]; then
    install -d -m 755 /etc/limine-entry-tool.d
    cat >/etc/limine-entry-tool.d/20-hibernate.conf <<EOF
# FireDragon hibernate/resume kernel parameters (generated)
# Managed by: ${PROJECT_ROOT}/hosts/firedragon/enable-sleep-hibernate.sh
KERNEL_CMDLINE[default]+=" ${resume_params}"
EOF
    log_success "Installed Limine drop-in: /etc/limine-entry-tool.d/20-hibernate.conf"

    if command_exists limine-update; then
      if limine-update; then
        log_success "limine-update: configuration regenerated"
      else
        log_warning "limine-update failed; rerun it manually after fixing any issues"
      fi
    elif command_exists limine-mkinitcpio; then
      if limine-mkinitcpio; then
        log_success "limine-mkinitcpio: entries refreshed"
      else
        log_warning "limine-mkinitcpio failed; rerun it manually after fixing any issues"
      fi
    else
      log_warning "Limine regeneration tool not found; ensure your Limine entries include: ${resume_params}"
    fi
  fi

  echo
  log_warning "REBOOT REQUIRED for hibernate/resume to work."
  log_info "After reboot, verify:"
  echo "  grep -E 'resume=|resume_offset=' /proc/cmdline"
  echo "  swapon --show"
  echo "  systemctl hibernate"
}

main "$@"

