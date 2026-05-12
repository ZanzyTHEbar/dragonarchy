# Architecture

## Overview

The containerized OpenFortiVPN is a single privileged container that runs the VPN data plane (openfortivpn + pppd), a portable DNS forwarder (dnsmasq), and a lightweight control plane (Go HTTP API).

## Why a Single Container?

PPP interfaces are kernel-level resources created by `pppd` in the network namespace where it runs. For the host to see and route traffic through the VPN interface, the container **must** use `--network host`. This makes a multi-container split (sidecar pattern) impractical for the data plane, so we colocate all components in one image.

## Components

### 1. VPN Data Plane

- `openfortivpn`: Establishes the TLS tunnel to the FortiGate
- `pppd`: Creates the kernel `ppp0` interface and negotiates PPP over TLS

Runs as root inside the container. The interface is visible on the host because of `--network host`.

### 2. DNS Plane

- `dnsmasq`: Lightweight DNS forwarder bound to `127.0.0.1:53`
- `dns-helper.sh`: Portable script that applies/resets split DNS

On connect:
1. Backs up host `/etc/resolv.conf`
2. Points host resolv.conf to `127.0.0.1` (dnsmasq)
3. Configures dnsmasq to route `*.vpn-domain` to VPN DNS servers
4. Falls back to `systemd-resolved`/`resolvectl` if available and `DNS_METHOD=auto`

On disconnect:
1. Restores original `/etc/resolv.conf`
2. Clears dnsmasq VPN config
3. Falls back to `resolvectl revert` if available

### 3. Control Plane (Go 1.26)

A statically-linked Go binary using **hexagonal architecture**:

```
cmd/
  server/          # HTTP API server entry point
  cli/             # CLI client entry point (vpnctl)
internal/
  core/
    domain/        # Config, State, Status models
    ports/         # Interfaces (VPNManager, DNSResolver, ConfigStore)
    services/      # Application services + Command pattern
  adapters/
    primary/
      http/        # HTTP handlers (std net/http mux)
      cli/         # Cobra commands with Palette pattern
    secondary/
      process/     # openfortivpn process manager
      dns/         # DNS helper adapter
      config/      # File config store
```

Key design patterns:
- **Hexagonal architecture**: Domain logic is isolated from adapters
- **Command pattern**: `ConnectCommand`, `DisconnectCommand`, `StatusCommand` encapsulate operations
- **Palette pattern**: CLI commands are registered in a `CommandPalette` registry
- **Tiger-style errors**: Using `github.com/ZanzyTHEbar/faults-go` for structured, transport-aware errors

The control plane provides:
- HTTP API (Unix socket + TCP)
- Process supervision for openfortivpn
- State machine (disconnected → connecting → connected → disconnected)
- Graceful shutdown handling
- Web UI (SolidJS + TailwindCSS, embedded via `//go:embed`)

### 4. Web UI

Built with **SolidJS + TailwindCSS**, bundled with **Bun + Vite**:

```
webui/
  src/
    App.tsx      # Main UI with reactive state
    index.tsx    # Entry point
    index.css    # Tailwind directives
  index.html
  package.json
  vite.config.ts
  tailwind.config.js
```

Built via `go:generate` before the Go binary is compiled:

```go
//go:generate bash ../../scripts/build-webui.sh
//go:embed webui/dist
var webUI embed.FS
```

### 5. Entrypoint

`tini` runs `entrypoint.sh` as PID 1:
1. Validates environment and config
2. Starts dnsmasq
3. Starts control plane
4. Waits for signals (SIGINT/SIGTERM)
5. On shutdown: stops control plane, stops dnsmasq, exits

## Signal Flow

```
User: docker stop / SIGTERM
  -> tini forwards SIGTERM to entrypoint.sh
  -> entrypoint.sh calls cleanup()
  -> cleanup() stops control plane
  -> control plane calls VPNManager.Disconnect()
  -> Disconnect():
       1. Resets DNS
       2. Sends SIGINT to openfortivpn
       3. Waits up to 10s for graceful exit
       4. Kills pppd
       5. Brings interface down
  -> entrypoint.sh stops dnsmasq
  -> exit 0
```

## API Design

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Container health (200 or 503) |
| GET | `/status` | VPN state, interface, IP, uptime |
| POST | `/connect` | Start VPN; returns SAML URL |
| POST | `/disconnect` | Stop VPN |
| GET | `/config` | Raw openfortivpn config |
| POST | `/config` | Update config (JSON `{config: "..."}`) |
| GET | `/logs` | Log info (streaming not yet implemented) |
| GET | `/saml/status` | Is SAML listener ready? |
| GET | `/ui/` | Web UI |

## State Machine

```
+-------------+     connect()      +------------+
| disconnected| -----------------> | connecting |
+-------------+                    +------------+
      ^                                  |
      |                                  | interface detected
      |                                  v
      |                            +------------+
      |                            | connected  |
      |                            +------------+
      |                                  |
      |                                  | disconnect()
      |                                  v
      |                            +------------+
      +----------------------------| disconnect |
                                   +------------+
```

## Host Requirements

- Linux kernel with PPP support (`/dev/ppp`)
- Docker or Podman
- `CAP_NET_ADMIN` (granted via `--privileged`)

## Security Notes

- The container runs `--privileged` because `pppd` requires `CAP_NET_ADMIN` and `/dev/ppp` access. This is inherent to PPP VPNs.
- The Unix API socket is created with mode `0666` so the CLI client can access it without root.
- The TCP API binds only to `127.0.0.1`.
- Host `/etc/resolv.conf` is bind-mounted into the container for DNS manipulation. Ensure the container image is trusted.
