#!/usr/bin/env bash
#
# manage-hibernation.sh - role-owned hibernation and resume plumbing
#
# This script is the canonical implementation for swap, resume, and bootloader
# state under the Ansible hibernation role. It intentionally does not manage
# systemd sleep/logind policy because that is already owned by the ASUS laptop role.

set -euo pipefail

BOOT_LIB="${BOOT_LIB:-/usr/local/libexec/dotfiles/bootloader.sh}"
HIBERNATION_STATE_FILE="${HIBERNATION_STATE_FILE:-/etc/dotfiles/hibernation.env}"
SWAPFILE_PATH="${SWAPFILE_PATH:-/swapfile}"
SWAPFILE_PRIORITY="${SWAPFILE_PRIORITY:-1000}"
SWAP_SIZE_GIB="${SWAP_SIZE_GIB:-}"
FORCE_RECREATE="${FORCE_RECREATE:-0}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[ERROR] manage-hibernation.sh must run as root" >&2
  exit 1
fi

log_info()    { echo "[INFO] $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_warning() { echo "[WARNING] $*"; }
log_error()   { echo "[ERROR] $*"; }
log_step()    { echo "[STEP] $*"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

if [[ ! -f "$BOOT_LIB" ]]; then
  log_error "Shared bootloader helper not found at $BOOT_LIB"
  exit 1
fi

# shellcheck disable=SC1090
source "$BOOT_LIB"

ROLE_CHANGED=0

mark_changed() {
  ROLE_CHANGED=1
}

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
    if ! grep -Fxq "$line" "$fstab"; then
      sed -i "s|^[[:space:]]*${swapfile}[[:space:]]\\+none[[:space:]]\\+swap.*|${line}|" "$fstab"
      mark_changed
    fi
    return 0
  fi

  {
    echo
    echo "# firedragon: hibernate swapfile (managed by Ansible)"
    echo "$line"
  } >>"$fstab"
  mark_changed
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
      mark_changed
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
      mark_changed
    else
      fallocate -l "${size_gib}G" "$swapfile"
      chmod 600 "$swapfile"
      mkswap "$swapfile" >/dev/null
      mark_changed
      log_success "Created swapfile"
    fi
  fi

  ensure_swapfile_fstab "$swapfile" "$SWAPFILE_PRIORITY"

  if ! swap_is_active "$swapfile"; then
    swapon "$swapfile"
    mark_changed
    log_success "Enabled swapfile"
  else
    log_info "Swapfile already active"
  fi
}

compute_resume_offset_pages() {
  local swapfile="$1"
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
  if [[ "$hooks_line" =~ (^|[[:space:]])systemd($|[[:space:]]) ]] && [[ -f /usr/lib/initcpio/hooks/sd-resume ]]; then
    want="sd-resume"
  fi

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

  mark_changed
  log_success "mkinitcpio: added ${want} hook"
  log_info "Rebuilding initramfs (mkinitcpio -P)..."
  mkinitcpio -P || log_warning "mkinitcpio returned non-zero; please review output"
}

install_limine_dropin() {
  local resume_params="$1"
  local dest="/etc/limine-entry-tool.d/20-hibernate.conf"
  local desired

  install -d -m 755 /etc/limine-entry-tool.d
  desired="$(cat <<EOF
# FireDragon hibernate/resume kernel parameters (generated)
# Managed by: ansible role hibernation
KERNEL_CMDLINE[default]+=" ${resume_params}"
EOF
)"

  if [[ -f "$dest" ]] && [[ "$(cat "$dest")" == "$desired" ]]; then
    log_info "Limine hibernation drop-in already current"
  else
    printf '%s\n' "$desired" > "$dest"
    mark_changed
    log_success "Installed Limine drop-in: ${dest}"
  fi

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
}

write_state_file() {
  local chosen_name="$1"
  local chosen_type="$2"
  local resume_uuid="$3"
  local resume_offset="$4"
  local resume_params="$5"
  local bootloader="$6"
  local tmp

  install -d -m 755 "$(dirname "$HIBERNATION_STATE_FILE")"
  tmp="$(mktemp)"
  cat >"$tmp" <<EOF
CHOSEN_NAME=${chosen_name}
CHOSEN_TYPE=${chosen_type}
RESUME_UUID=${resume_uuid}
RESUME_OFFSET=${resume_offset}
RESUME_PARAMS=${resume_params}
BOOTLOADER=${bootloader}
EOF

  if [[ -f "$HIBERNATION_STATE_FILE" ]] && cmp -s "$tmp" "$HIBERNATION_STATE_FILE"; then
    rm -f "$tmp"
    return 0
  fi

  mv "$tmp" "$HIBERNATION_STATE_FILE"
  chmod 0644 "$HIBERNATION_STATE_FILE"
  mark_changed
}

main() {
  log_info "Configuring hibernation and resume plumbing..."

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

  local chosen_name="" chosen_type="" chosen_size=0
  if command_exists swapon; then
    while IFS=' ' read -r name type size _prio; do
      [[ -n "${name:-}" ]] || continue
      [[ "$name" == /dev/zram* ]] && continue
      [[ -n "${size:-}" ]] || continue
      if [[ "$size" -ge "$ram_bytes" ]]; then
        if [[ -z "$chosen_name" ]]; then
          chosen_name="$name"; chosen_type="$type"; chosen_size="$size"
          continue
        fi
        if [[ "$chosen_type" != "partition" && "$type" == "partition" ]]; then
          chosen_name="$name"; chosen_type="$type"; chosen_size="$size"
          continue
        fi
        if [[ "$size" -gt "$chosen_size" ]]; then
          chosen_name="$name"; chosen_type="$type"; chosen_size="$size"
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

  local resume_uuid="" resume_offset="" resume_params=""
  if [[ "$chosen_type" == "file" || "$chosen_name" != /dev/* ]]; then
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
    resume_uuid="$(blkid -s UUID -o value "$chosen_name" 2>/dev/null || true)"
    if [[ -z "$resume_uuid" ]]; then
      log_error "Could not determine UUID for swap device: $chosen_name"
      exit 1
    fi
    resume_params="resume=UUID=${resume_uuid}"
  fi

  log_success "Resume parameters: ${resume_params}"

  ensure_mkinitcpio_resume_hook

  boot_append_kernel_params "$resume_params"
  boot_rebuild_if_changed
  if [[ "${BOOT_PARAMS_CHANGED:-false}" == "true" ]]; then
    mark_changed
  fi

  local bootloader="unknown"
  bootloader="$(detect_bootloader)"
  if [[ "$bootloader" == "limine" ]]; then
    install_limine_dropin "$resume_params"
  fi

  write_state_file "$chosen_name" "$chosen_type" "$resume_uuid" "$resume_offset" "$resume_params" "$bootloader"

  echo
  log_warning "REBOOT REQUIRED for hibernate/resume to work."
  log_info "After reboot, verify:"
  echo "  grep -E 'resume=|resume_offset=' /proc/cmdline"
  echo "  swapon --show"
  echo "  systemctl hibernate"

  if [[ "$ROLE_CHANGED" -eq 1 ]]; then
    echo "RESULT=changed"
  else
    echo "RESULT=unchanged"
  fi
}

main "$@"
