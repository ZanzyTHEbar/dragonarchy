#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

systemd_service_exists() {
  have_cmd systemctl || return 1
  systemctl cat openfortivpn.service >/dev/null 2>&1
}

systemd_is_active() {
  have_cmd systemctl || return 1
  systemctl is-active --quiet openfortivpn.service
}

systemd_start_vpn() {
  systemctl start openfortivpn.service
}

systemd_stop_vpn() {
  systemctl stop openfortivpn.service
  systemctl reset-failed openfortivpn.service >/dev/null 2>&1 || true
}

systemd_cleanup_exists() {
  have_cmd systemctl || return 1
  systemctl cat openfortivpn-cleanup.service >/dev/null 2>&1
}

systemd_cleanup_vpn() {
  systemctl start openfortivpn-cleanup.service
}

systemd_main_pid() {
  have_cmd systemctl || return 1
  systemctl show -p MainPID --value openfortivpn.service 2>/dev/null || true
}

openfortivpn_pids() {
  pgrep -x "$VPN_PROC_NAME" 2>/dev/null || true
}

stray_openfortivpn_pids() {
  local main_pid=""
  main_pid="$(systemd_main_pid)"
  local pid
  for pid in $(openfortivpn_pids); do
    if [[ -n "$main_pid" && "$main_pid" != "0" && "$pid" == "$main_pid" ]]; then
      continue
    fi
    echo "$pid"
  done
}

stray_openfortivpn_running() {
  [[ -n "$(stray_openfortivpn_pids)" ]]
}

vpn_iface_up() {
  have_cmd ip || return 1
  ip link show dev "$VPN_IFACE" >/dev/null 2>&1
}

vpn_addr() {
  have_cmd ip || return 0
  local output=""
  output="$(ip -brief addr show dev "$VPN_IFACE" 2>/dev/null || true)"
  printf "%s" "$output" | awk 'NR==1 {print $3}' | cut -d/ -f1
}

vpn_proc_running() {
  pgrep -x "$VPN_PROC_NAME" >/dev/null 2>&1
}

vpn_state() {
  if vpn_iface_up; then
    echo "connected"
  elif systemd_service_exists; then
    if systemd_is_active; then
      echo "connecting"
    elif stray_openfortivpn_running; then
      echo "error"
    elif vpn_proc_running; then
      echo "error"
    else
      echo "disconnected"
    fi
  elif vpn_proc_running; then
    echo "connecting"
  else
    echo "disconnected"
  fi
}
