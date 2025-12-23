#!/usr/bin/env bash
#
# bootloader.sh - Detection and safe kernel parameter helpers
#
# Provides:
#   - detect_bootloader
#   - boot_append_kernel_params "token1 token2"
#   - boot_rebuild_if_changed
#
# Bootloaders supported: systemd-boot, limine, grub, uki (fallback)
# All updates are idempotent and create backups before modifying files.

# Fallback minimal logging if not sourced
if ! declare -F log_info >/dev/null 2>&1; then
  log_info()    { echo "[INFO] $*"; }
  log_success() { echo "[SUCCESS] $*"; }
  log_warning() { echo "[WARNING] $*"; }
  log_error()   { echo "[ERROR] $*"; }
  log_step()    { echo "[STEP] $*"; }
fi

# Track whether we changed boot parameters
BOOT_PARAMS_CHANGED=false

# ------------------------ Detection ------------------------

detect_bootloader() {
  local is_uefi=0
  [[ -d /sys/firmware/efi ]] && is_uefi=1

  # systemd-boot
  if command -v bootctl >/dev/null 2>&1 && bootctl is-installed >/dev/null 2>&1; then
    echo systemd-boot; return
  fi
  if [[ -f /boot/loader/loader.conf || -d /boot/loader/entries ]]; then
    echo systemd-boot; return
  fi

  # Limine
  if [[ -f /boot/limine.cfg || -f /boot/limine.conf || -f /boot/limine/limine.cfg || -f /boot/limine/limine.conf ]]; then
    echo limine; return
  fi

  # GRUB
  if [[ -f /etc/default/grub || -f /boot/grub/grub.cfg ]] || command -v grub-install >/dev/null 2>&1; then
    echo grub; return
  fi

  # UKI-only fallback
  if [[ $is_uefi -eq 1 ]]; then
    if compgen -G "/boot/efi/EFI/Linux/*.efi" >/dev/null 2>&1 || compgen -G "/efi/EFI/Linux/*.efi" >/dev/null 2>&1; then
      echo uki; return
    fi
  fi

  echo unknown
}

# ------------------------ Merge & Helpers ------------------------

boot__merge_params() {
  # shellcheck disable=SC2206
  local current_tokens=($1)
  # shellcheck disable=SC2206
  local add_tokens=($2)
  local out=()
  local -A seen=()
  for t in "${current_tokens[@]}"; do
    if [[ -n "$t" && -z "${seen[$t]:-}" ]]; then out+=("$t"); seen["$t"]=1; fi
  done
  for t in "${add_tokens[@]}"; do
    if [[ -n "$t" && -z "${seen[$t]:-}" ]]; then out+=("$t"); seen["$t"]=1; fi
  done
  printf "%s" "${out[*]}"
}

boot__dedupe_params_string() {
  # Remove duplicate tokens from a cmdline-like string while preserving order.
  # shellcheck disable=SC2206
  local tokens=($1)
  local out=()
  local -A seen=()
  for t in "${tokens[@]}"; do
    if [[ -n "$t" && -z "${seen[$t]:-}" ]]; then
      out+=("$t")
      seen["$t"]=1
    fi
  done
  printf "%s" "${out[*]}"
}

boot__append_cmdline() {
  local params="$1"; local target="/etc/kernel/cmdline"
  if [[ ! -f "$target" ]]; then
    log_warning "Kernel cmdline file not found at $target; skipping to avoid breaking boot"
    return 0
  fi
  local existing merged
  existing="$(tr '\n' ' ' < "$target" | xargs || true)"
  merged="$(boot__merge_params "$existing" "$params")"
  if [[ "$merged" == "$existing" ]]; then
    log_info "Kernel cmdline already contains desired parameters"
    return 0
  fi
  cp "$target" "${target}.backup.$(date +%Y%m%d_%H%M%S)"
  printf "%s\n" "$merged" > "${target}.tmp"
  mv "${target}.tmp" "$target"
  sync
  log_success "Updated $target (backup created)"
  BOOT_PARAMS_CHANGED=true
}

boot__append_systemd_boot_entry() {
  local entry="$1"; local params="$2"
  [[ -f "$entry" ]] || return 0
  local current merged
  current="$(grep -m1 '^options ' "$entry" | sed 's/^options[[:space:]]\+//')"
  if [[ -z "$current" ]]; then
    log_warning "No 'options' line found in $entry; skipping"
    return 0
  fi
  merged="$(boot__merge_params "$current" "$params")"
  if [[ "$merged" == "$current" ]]; then
    log_info "Boot entry already contains desired parameters: $entry"
    return 0
  fi
  cp "$entry" "${entry}.backup.$(date +%Y%m%d_%H%M%S)"
  awk -v repl="$merged" 'BEGIN{done=0} /^options / && !done {print "options " repl; done=1; next} {print}' "$entry" > "${entry}.tmp"
  mv "${entry}.tmp" "$entry"
  sync
  log_success "Updated boot entry: $entry (backup created)"
  BOOT_PARAMS_CHANGED=true
}

boot__append_systemd_boot() {
  local params="$1"
  local changed=0
  if [[ -d /boot/loader/entries ]]; then
    while IFS= read -r entry; do
      boot__append_systemd_boot_entry "$entry" "$params" && changed=1 || true
    done < <(find /boot/loader/entries -name '*.conf' 2>/dev/null || true)
  fi
  return $changed
}

boot__limine_cfg_path() {
  if [[ -f /boot/limine.conf ]]; then echo /boot/limine.conf; return; fi
  if [[ -f /boot/limine.cfg ]]; then echo /boot/limine.cfg; return; fi
  if [[ -f /boot/limine/limine.cfg ]]; then echo /boot/limine/limine.cfg; return; fi
  if [[ -f /boot/limine/limine.conf ]]; then echo /boot/limine/limine.conf; return; fi
  return 1
}

boot__append_limine() {
  local params="$1"; local cfg
  cfg="$(boot__limine_cfg_path || true)" || { log_warning "Limine config not found"; return 0; }
  local tmp
  tmp="${cfg}.tmp"
  cp "$cfg" "${cfg}.backup.$(date +%Y%m%d_%H%M%S)"
  local changed=0
  local touched=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^CMDLINE ]]; then
      # Extract quoted content
      local val
      val="$(printf '%s' "$line" | sed -n 's/^CMDLINE[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p')"
      local merged
      merged="$(boot__merge_params "$val" "$params")"
      if [[ "$merged" != "$val" ]]; then
        printf 'CMDLINE="%s"\n' "$merged" >> "$tmp"
        changed=1
        continue
      fi
      touched=1
    elif [[ "$line" =~ ^[[:space:]]*kernel_cmdline: ]]; then
      local prefix value merged
      prefix="$(printf '%s' "$line" | sed -E 's/^([[:space:]]*kernel_cmdline:[[:space:]]*).*/\1/')"
      value="${line#"$prefix"}"
      value="$(printf '%s' "$value" | xargs || true)"
      merged="$(boot__merge_params "$value" "$params")"
      if [[ "$merged" != "$value" ]]; then
        printf '%s%s\n' "$prefix" "$merged" >> "$tmp"
        changed=1
        touched=1
        continue
      fi
      touched=1
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$cfg"
  if [[ $changed -eq 1 ]]; then
    mv "$tmp" "$cfg"; sync; log_success "Updated Limine config: $cfg"; BOOT_PARAMS_CHANGED=true
  else
    rm -f "$tmp"
    if [[ $touched -eq 0 ]]; then
      log_warning "No kernel_cmdline entries found in Limine config; please add parameters manually if needed"
    else
      log_info "Limine kernel_cmdline already contains desired parameters"
    fi
  fi
}

boot__dedupe_limine() {
  local cfg
  cfg="$(boot__limine_cfg_path || true)" || { log_warning "Limine config not found"; return 0; }
  local tmp changed=0 touched=0
  tmp="${cfg}.tmp"
  cp "$cfg" "${cfg}.backup.$(date +%Y%m%d_%H%M%S)"
  while IFS= read -r line; do
    if [[ "$line" =~ ^CMDLINE ]]; then
      local val dedup
      val="$(printf '%s' "$line" | sed -n 's/^CMDLINE[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p')"
      dedup="$(boot__dedupe_params_string "$val")"
      if [[ "$dedup" != "$val" ]]; then
        printf 'CMDLINE="%s"\n' "$dedup" >> "$tmp"
        changed=1
        continue
      fi
      touched=1
    elif [[ "$line" =~ ^[[:space:]]*kernel_cmdline: ]]; then
      local prefix value dedup
      prefix="$(printf '%s' "$line" | sed -E 's/^([[:space:]]*kernel_cmdline:[[:space:]]*).*/\1/')"
      value="${line#"$prefix"}"
      value="$(printf '%s' "$value" | xargs || true)"
      dedup="$(boot__dedupe_params_string "$value")"
      if [[ "$dedup" != "$value" ]]; then
        printf '%s%s\n' "$prefix" "$dedup" >> "$tmp"
        changed=1
        touched=1
        continue
      fi
      touched=1
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$cfg"
  if [[ $changed -eq 1 ]]; then
    mv "$tmp" "$cfg"; sync; log_success "Deduplicated Limine config: $cfg"; BOOT_PARAMS_CHANGED=true
  else
    rm -f "$tmp"
    if [[ $touched -eq 0 ]]; then
      log_warning "No kernel_cmdline entries found in Limine config while deduplicating"
    else
      log_info "Limine kernel_cmdline already deduplicated"
    fi
  fi
}

boot__append_grub() {
  local params="$1"; local cfg="/etc/default/grub"
  if [[ ! -f "$cfg" ]]; then
    log_warning "GRUB default config not found at $cfg"; return 0
  fi
  local current new merged
  current="$(sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/p' "$cfg")"
  merged="$(boot__merge_params "$current" "$params")"
  if [[ "$merged" == "$current" ]]; then
    log_info "GRUB_CMDLINE_LINUX_DEFAULT already contains desired parameters"
  else
    cp "$cfg" "${cfg}.backup.$(date +%Y%m%d_%H%M%S)"
    sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$merged\"/" "$cfg"
    sync
    log_success "Updated $cfg (backup created)"
    BOOT_PARAMS_CHANGED=true
  fi
  if command -v grub-mkconfig >/dev/null 2>&1; then
    if grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1; then
      log_success "Regenerated /boot/grub/grub.cfg"
    else
      log_warning "grub-mkconfig failed; please regenerate grub.cfg manually"
    fi
  fi
}

# Public API: append params according to detected bootloader
boot_append_kernel_params() {
  local params="$1"; local bl
  bl="$(detect_bootloader)"
  case "$bl" in
    systemd-boot) boot__append_systemd_boot "$params" ;;
    limine)       boot__append_limine "$params" ;;
    grub)         boot__append_grub "$params" ;;
    uki)          boot__append_cmdline "$params" ;;
    *)            log_warning "Unknown bootloader; skipping kernel param changes" ;;
  esac
}

boot_dedupe_kernel_params() {
  local bl
  bl="$(detect_bootloader)"
  case "$bl" in
    limine) boot__dedupe_limine ;;
    systemd-boot|uki|grub)
      log_info "Kernel parameter dedupe not required for $bl (already handled during merge)"
      ;;
    *)
      log_warning "Unknown bootloader; skipping kernel parameter dedupe"
      ;;
  esac
}

# Public API: rebuild initramfs if changed
boot_rebuild_if_changed() {
  if [[ "$BOOT_PARAMS_CHANGED" != "true" ]]; then
    return 0
  fi
  log_step "Rebuilding initramfs due to boot parameter changes..."
  if command -v mkinitcpio >/dev/null 2>&1; then
    if mkinitcpio -P; then
      log_success "mkinitcpio: presets rebuilt"
    else
      log_warning "mkinitcpio failed; please verify configuration"
    fi
  elif command -v dracut >/dev/null 2>&1; then
    if dracut --regenerate-all --force; then
      log_success "dracut: images regenerated"
    else
      log_warning "dracut failed; please verify configuration"
    fi
  else
    log_warning "No initramfs tool found (mkinitcpio/dracut); rebuild manually if needed"
  fi
}
