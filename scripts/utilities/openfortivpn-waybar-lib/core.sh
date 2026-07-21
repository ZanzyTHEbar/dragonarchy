#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

have_cmd() { command -v "$1" >/dev/null 2>&1; }

config_value() {
  local key="$1"
  [[ -f "$VPN_CONFIG" && -r "$VPN_CONFIG" ]] || return 0
  awk -F= -v key="$key" '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    $1 ~ "^[[:space:]]*"key"[[:space:]]*$" {
      val=$2
      sub(/^[[:space:]]+/, "", val)
      sub(/[[:space:]]+$/, "", val)
      print val
      exit
    }
  ' "$VPN_CONFIG"
}

config_or_default() {
  local key="$1"
  local default="$2"
  local value=""
  value="$(config_value "$key")"
  if [[ -n "$value" ]]; then
    echo "$value"
  else
    echo "$default"
  fi
}

vpn_login_url() {
  local host port
  host="$(config_value host)"
  port="$(config_or_default port 443)"
  if [[ -z "$host" ]]; then
    host="${OPENFORTIVPN_HOST:-}"
  fi
  [[ -z "$host" ]] && return 1
  echo "https://${host}:${port}/remote/saml/start?redirect=1"
}

build_cmd_string() {
  local out="" part
  for part in "$@"; do
    out+="$(printf '%q' "$part") "
  done
  printf "%s" "${out% }"
}

port_in_use() {
  local port="$1"
  if have_cmd ss; then
    ss -ltn "sport = :$port" 2>/dev/null | awk 'NR>1 {print $1; exit}' | grep -q LISTEN
    return $?
  fi
  if have_cmd netstat; then
    netstat -ltn 2>/dev/null | awk -v p=":$port" '$4 ~ p {print $6; exit}' | grep -q LISTEN
    return $?
  fi
  return 1
}

wait_for_port() {
  local port="$1"
  local max_wait_ms="${2:-5000}"
  local slept=0
  local step=200
  while (( slept < max_wait_ms )); do
    if port_in_use "$port"; then
      return 0
    fi
    sleep 0.2
    slept=$((slept + step))
  done
  return 1
}

wait_for_disconnect() {
  local max_wait_ms="${1:-6000}"
  local slept=0
  local step=300
  while (( slept < max_wait_ms )); do
    if ! vpn_iface_up && ! vpn_proc_running && !(systemd_service_exists && systemd_is_active); then
      return 0
    fi
    sleep 0.3
    slept=$((slept + step))
  done
  return 1
}

run_background() {
  local log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/openfortivpn"
  mkdir -p "$log_dir"
  chmod 0700 "$log_dir"
  local log_file="${log_dir}/waybar.log"
  if have_cmd setsid; then
    setsid "$@" </dev/null >"$log_file" 2>&1 &
  else
    "$@" </dev/null >"$log_file" 2>&1 &
  fi
  disown || true
}

launch_terminal() {
  local cmd_string="$1"
  local -a term=()

  if have_cmd kitty; then
    term=(kitty --class=OpenFortiVPN --title=OpenFortiVPN)
  elif have_cmd foot; then
    term=(foot -a OpenFortiVPN)
  elif have_cmd alacritty; then
    term=(alacritty --class OpenFortiVPN,OpenFortiVPN)
  elif have_cmd wezterm; then
    term=(wezterm start --class OpenFortiVPN)
  elif have_cmd gnome-terminal; then
    term=(gnome-terminal --)
  elif have_cmd xterm; then
    term=(xterm -T OpenFortiVPN)
  fi

  if [[ ${#term[@]} -eq 0 ]]; then
    notify "VPN" "No terminal found to launch OpenFortiVPN."
    return 1
  fi

  if have_cmd uwsm && uwsm check is-active >/dev/null 2>&1; then
    uwsm app -- "${term[@]}" bash -lc "$cmd_string" &
  else
    "${term[@]}" bash -lc "$cmd_string" &
  fi
  disown || true
}
