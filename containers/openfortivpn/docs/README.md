# OpenFortiVPN Container

A generic, containerized OpenFortiVPN setup that works on any Linux machine (with or without systemd) via Docker or Podman.

## Features

- **Full-network VPN**: Creates a real `ppp0` interface on the host (Linux only)
- **SAML authentication**: Interactive browser-based login flow
- **Portable split DNS**: Works with or without `systemd-resolved`
- **HTTP API + CLI + Web UI**: Control the VPN from your terminal or browser
- **Graceful shutdown**: Proper signal handling with automatic DNS cleanup
- **Health checks**: Container-native health monitoring
- **Modern Go stack**: Go 1.26, hexagonal architecture, command pattern, faults-go error handling
- **Modern web stack**: SolidJS + TailwindCSS, built with Bun

## Quick Start

### 1. Configure

```bash
cp config/openfortivpn.conf.example config/openfortivpn.conf
$EDITOR config/openfortivpn.conf
```

Set your FortiGate host, port, and optional trusted certificate hash.

### 2. Start (Docker)

```bash
docker compose up -d
```

### 3. Connect

```bash
vpnctl connect
# Browser opens for SAML login
```

### 4. Check status

```bash
vpnctl status
```

### 5. Disconnect

```bash
vpnctl disconnect
```

## Web UI

Open [http://127.0.0.1:8080/ui/](http://127.0.0.1:8080/ui/) in your browser for a clickable interface.

## Podman / Quadlet

Copy the Quadlet files to your user's systemd directory:

```bash
mkdir -p ~/.config/containers/systemd
cp podman/openfortivpn.container podman/openfortivpn.volume ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start openfortivpn.service
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `VPN_HOST` | (from config) | FortiGate hostname |
| `VPN_PORT` | `443` | FortiGate port |
| `VPN_DOMAIN` | `avular.dev` | Domain for split DNS |
| `VPN_DNS_SERVERS` | `10.10.100.50,10.10.100.11` | Comma-separated DNS servers |
| `SAML_PORT` | `8020` | Local port for SAML listener |
| `DNS_METHOD` | `auto` | `auto`, `resolved`, `dnsmasq`, `none` |
| `AUTO_CONNECT` | `false` | Start VPN immediately on boot |
| `API_TCP_PORT` | `8080` | TCP port for API/Web UI |
| `API_UNIX_SOCKET` | `/run/openfortivpn/api.sock` | Unix socket for local CLI |

## Building from Source

```bash
just build
```

## Installing the CLI

```bash
just install-cli
# Adds vpnctl to ~/.local/bin
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed design documentation.

## License

MIT
