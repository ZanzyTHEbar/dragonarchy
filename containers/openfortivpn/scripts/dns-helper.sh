#!/usr/bin/env bash
set -euo pipefail

# Portable DNS helper for openfortivpn-container
# Usage:
#   dns-helper.sh --apply          # Apply split DNS
#   dns-helper.sh --reset          # Remove split DNS and restore original
#
# Environment:
#   VPN_DOMAIN          Domain for split DNS (default: avular.dev)
#   VPN_DNS_SERVERS     Comma-separated DNS servers (default: 10.10.100.50,10.10.100.11)
#   DNS_METHOD          auto | resolved | dnsmasq | none (default: auto)
#   HOST_RESOLV         Path to host resolv.conf (default: /host/etc/resolv.conf)
#   BACKUP_RESOLV       Path to backup file (default: /var/lib/openfortivpn/resolv.conf.backup)

VPN_DOMAIN="${VPN_DOMAIN:-avular.dev}"
VPN_DNS_SERVERS="${VPN_DNS_SERVERS:-10.10.100.50,10.10.100.11}"
DNS_METHOD="${DNS_METHOD:-auto}"
HOST_RESOLV="${HOST_RESOLV:-/host/etc/resolv.conf}"
BACKUP_RESOLV="${BACKUP_RESOLV:-/var/lib/openfortivpn/resolv.conf.backup}"
DNSMASQ_CONF="${DNSMASQ_CONF:-/run/openfortivpn/dnsmasq.conf}"
DNSMASQ_PIDFILE="${DNSMASQ_PIDFILE:-/run/openfortivpn/dnsmasq.pid}"

log() {
  echo "[dns-helper] $*" >&2
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Detect best DNS method
detect_method() {
  if [[ "$DNS_METHOD" != "auto" ]]; then
    echo "$DNS_METHOD"
    return 0
  fi

  if have_cmd resolvectl && resolvectl status >/dev/null 2>&1; then
    echo "resolved"
    return 0
  fi

  if [[ -f "$HOST_RESOLV" && -w "$HOST_RESOLV" ]]; then
    echo "dnsmasq"
    return 0
  fi

  echo "none"
}

# Backup current resolv.conf
backup_resolv() {
  if [[ -f "$HOST_RESOLV" ]]; then
    mkdir -p "$(dirname "$BACKUP_RESOLV")"
    cp -L "$HOST_RESOLV" "$BACKUP_RESOLV"
    log "Backed up resolv.conf to $BACKUP_RESOLV"
  fi
}

# Restore original resolv.conf
restore_resolv() {
  if [[ -f "$BACKUP_RESOLV" ]]; then
    cp "$BACKUP_RESOLV" "$HOST_RESOLV"
    log "Restored resolv.conf from backup"
    rm -f "$BACKUP_RESOLV"
  fi
}

# Detect VPN interface
detect_iface() {
  local iface=""
  if have_cmd resolvectl; then
    iface="$(resolvectl status 2>/dev/null | awk '/^Link [0-9]+ \(/ {name=$3; gsub(/[()]/,"",name); if (name ~ /^fctvpn/) {print name; exit}}')"
    if [[ -z "$iface" ]] && resolvectl status 2>/dev/null | grep -q 'Link .* (ppp0)'; then
      iface="ppp0"
    fi
    if [[ -z "$iface" ]]; then
      iface="$(resolvectl status 2>/dev/null | awk '/^Link [0-9]+ \(/ {name=$3; gsub(/[()]/,"",name); if (name ~ /^(ppp|tun|tap)/) {print name; exit}}')"
    fi
  fi
  if [[ -z "$iface" ]] && have_cmd ip; then
    iface="$(ip -brief link show 2>/dev/null | awk '/^ppp/ {print $1; exit}')"
  fi
  echo "$iface"
}

# Apply DNS via systemd-resolved
apply_resolved() {
  local iface
  iface="$(detect_iface)"
  if [[ -z "$iface" ]]; then
    log "ERROR: Could not detect VPN interface for resolved"
    return 1
  fi

  local IFS=','
  local servers=""
  local s
  for s in $VPN_DNS_SERVERS; do
    servers="$servers $s"
  done

  resolvectl dns "$iface" $servers
  resolvectl domain "$iface" "~${VPN_DOMAIN}"
  resolvectl flush-caches >/dev/null 2>&1 || true
  log "Applied split DNS via resolved on $iface"
}

# Reset DNS via systemd-resolved
reset_resolved() {
  local iface
  iface="$(detect_iface)"
  if [[ -n "$iface" ]]; then
    resolvectl revert "$iface" >/dev/null 2>&1 || true
    resolvectl flush-caches >/dev/null 2>&1 || true
    log "Reset DNS via resolved on $iface"
  else
    log "No VPN interface found for resolved reset"
  fi
}

# Apply DNS via dnsmasq + resolv.conf manipulation
apply_dnsmasq() {
  backup_resolv

  # Update dnsmasq config with VPN DNS
  local IFS=','
  local server
  for server in $VPN_DNS_SERVERS; do
    echo "server=/${VPN_DOMAIN}/${server}" >> "$DNSMASQ_CONF"
  done

  # Reload dnsmasq
  if [[ -f "$DNSMASQ_PIDFILE" ]]; then
    local pid
    pid="$(cat "$DNSMASQ_PIDFILE")"
    if kill -0 "$pid" 2>/dev/null; then
      kill -HUP "$pid" || true
    fi
  fi

  # Point host resolv.conf to local dnsmasq
  echo "nameserver 127.0.0.1" > "$HOST_RESOLV"
  log "Applied split DNS via dnsmasq (resolv.conf -> 127.0.0.1)"
}

# Reset DNS via dnsmasq
reset_dnsmasq() {
  restore_resolv

  # Remove VPN-specific lines from dnsmasq config
  if [[ -f "$DNSMASQ_CONF" ]]; then
    grep -v "server=/${VPN_DOMAIN}/" "$DNSMASQ_CONF" > "${DNSMASQ_CONF}.tmp" || true
    mv "${DNSMASQ_CONF}.tmp" "$DNSMASQ_CONF"
  fi

  # Reload dnsmasq
  if [[ -f "$DNSMASQ_PIDFILE" ]]; then
    local pid
    pid="$(cat "$DNSMASQ_PIDFILE")"
    if kill -0 "$pid" 2>/dev/null; then
      kill -HUP "$pid" || true
    fi
  fi

  log "Reset DNS via dnsmasq"
}

# Main
ACTION="${1:-}"
case "$ACTION" in
  --apply)
    METHOD="$(detect_method)"
    log "Applying DNS (method: $METHOD)..."
    case "$METHOD" in
      resolved) apply_resolved ;;
      dnsmasq) apply_dnsmasq ;;
      none) log "DNS method is 'none'; skipping" ;;
    esac
    ;;
  --reset)
    METHOD="$(detect_method)"
    log "Resetting DNS (method: $METHOD)..."
    case "$METHOD" in
      resolved) reset_resolved ;;
      dnsmasq) reset_dnsmasq ;;
      none) log "DNS method is 'none'; skipping" ;;
    esac
    ;;
  *)
    echo "Usage: $0 {--apply|--reset}" >&2
    exit 2
    ;;
esac
