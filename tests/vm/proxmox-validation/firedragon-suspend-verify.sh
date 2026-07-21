#!/usr/bin/env bash
# Read-only verification for the firedragon suspend/hibernate stack.

set -euo pipefail

GIB=$((1024 * 1024 * 1024))
FAILURES=0
HYPRIDLE_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
HIBERNATION_STATE_FILE="/etc/dotfiles/hibernation.env"

section() {
  printf '\n%s\n' "$1"
}

pass() {
  printf '   PASS: %s\n' "$1"
}

warn() {
  printf '   WARN: %s\n' "$1"
}

fail() {
  printf '   FAIL: %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}

section "1) Kernel cmdline"
if grep -qw 'amdgpu.modeset=1' /proc/cmdline; then
  pass "amdgpu.modeset=1 present"
else
  fail "amdgpu.modeset=1 missing"
fi

if grep -qw 'resume=' /proc/cmdline; then
  pass "resume= present"
else
  fail "resume= missing"
fi

if grep -qw 'resume_offset=' /proc/cmdline; then
  pass "resume_offset= present"
else
  warn "resume_offset= absent (acceptable when resuming from a swap partition)"
fi

section "2) AMD GPU and suspend services"
for unit in amdgpu-suspend.service amdgpu-resume.service amdgpu-console-restore.service; do
  if systemctl is-enabled "$unit" >/dev/null 2>&1; then
    pass "$unit enabled"
  else
    fail "$unit not enabled"
  fi
done

if [[ -f /etc/modprobe.d/amdgpu.conf ]] && grep -q 'gpu_reset=0' /etc/modprobe.d/amdgpu.conf; then
  pass "/etc/modprobe.d/amdgpu.conf has expected reset tuning"
else
  fail "/etc/modprobe.d/amdgpu.conf missing expected reset tuning"
fi

section "3) ASUS laptop sleep policy"
if [[ -f /etc/systemd/logind.conf.d/10-firedragon-lid.conf ]]; then
  pass "logind lid policy present"
else
  fail "logind lid policy missing"
fi

if [[ -f /etc/systemd/sleep.conf.d/10-firedragon-sleep.conf ]]; then
  pass "sleep policy present"
else
  fail "sleep policy missing"
fi

section "4) Hibernation state"
MEM_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
MEM_BYTES=$((MEM_KB * 1024))
MEM_GIB=$(((MEM_BYTES + GIB - 1) / GIB))
printf '   RAM: ~%s GiB\n' "$MEM_GIB"

DISK_SWAP_BYTES="$(swapon --show --noheadings --bytes --output=NAME,SIZE 2>/dev/null | awk '$1 !~ /^\/dev\/zram/ {sum+=$2} END{print sum+0}')"
DISK_SWAP_GIB=$(((DISK_SWAP_BYTES + GIB - 1) / GIB))
printf '   Disk swap (excluding zram): ~%s GiB\n' "$DISK_SWAP_GIB"
if [[ "$DISK_SWAP_BYTES" -ge "$MEM_BYTES" ]]; then
  pass "disk-backed swap is large enough for hibernate"
else
  fail "disk-backed swap is too small for hibernate"
fi

if [[ -f "$HIBERNATION_STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$HIBERNATION_STATE_FILE"
  pass "hibernation state file present (${HIBERNATION_STATE_FILE})"
  printf '   Chosen swap: %s\n' "${CHOSEN_NAME:-unknown}"
  printf '   Resume params: %s\n' "${RESUME_PARAMS:-unknown}"
else
  fail "hibernation state file missing (${HIBERNATION_STATE_FILE})"
fi

if [[ -f /etc/mkinitcpio.conf ]] && grep -Eq '^HOOKS=.*(sd-resume|resume)' /etc/mkinitcpio.conf; then
  pass "mkinitcpio hooks include resume support"
else
  fail "mkinitcpio hooks missing resume support"
fi

section "5) Hypridle session policy"
if [[ -f "$HYPRIDLE_CONF" ]]; then
  pass "hypridle config present (${HYPRIDLE_CONF})"
else
  fail "hypridle config missing (${HYPRIDLE_CONF})"
fi

if [[ -f "$HYPRIDLE_CONF" ]] && grep -Eq 'before_sleep_cmd[[:space:]]*=[[:space:]]*loginctl lock-session' "$HYPRIDLE_CONF"; then
  pass "hypridle locks session before sleep"
else
  fail "hypridle missing before_sleep_cmd = loginctl lock-session"
fi

if [[ -f "$HYPRIDLE_CONF" ]] && grep -Eq 'after_sleep_cmd[[:space:]]*=[[:space:]]*hyprctl dispatch dpms on' "$HYPRIDLE_CONF"; then
  pass "hypridle restores DPMS after sleep"
else
  fail "hypridle missing after_sleep_cmd = hyprctl dispatch dpms on"
fi

section "6) ASUS platform profile"
if command -v asusctl >/dev/null 2>&1; then
  CURRENT_PROFILE="$(asusctl profile -p 2>/dev/null || true)"
  printf '   Current ASUS profile: %s\n' "${CURRENT_PROFILE:-unknown}"
  if [[ "$CURRENT_PROFILE" == *Balanced* ]]; then
    pass "ASUS profile is Balanced"
  else
    fail "ASUS profile is not Balanced"
  fi
else
  warn "asusctl unavailable; skipping ASUS profile check"
fi

section "7) Manual smoke sequence"
printf '   1. loginctl lock-session\n'
printf '   2. systemctl suspend\n'
printf '   3. Close lid for 5+ seconds, then open\n'
printf '   4. systemctl hibernate\n'
printf '   5. Ctrl+Alt+F2, then return to the active VT\n'

if [[ "$FAILURES" -gt 0 ]]; then
  printf '\nVerification failed with %s failing check(s).\n' "$FAILURES"
  exit 1
fi

printf '\nVerification passed.\n'
