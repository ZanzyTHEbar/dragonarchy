# DragonServer Access Map

## Host Map

| Alias | FQDN / IP | Role | Notes |
|---|---|---|---|
| `lan-proxmox` | `dragonserver.local` / `192.168.0.215` | Proxmox host and Coolify control plane location | Use for host-level audit and Proxmox operations |
| `cool-res` | `coolifyresources.local` / `192.168.0.157` | LXC resource host running Docker workloads | Use for container-level operations |

## Channel Responsibilities

| Channel | Typical Use |
|---|---|
| SSH `lan-proxmox` | Hardware checks, ZFS status, LXC/VM config, systemd services |
| SSH `cool-res` | Docker container inspection, logs, exec commands |
| Coolify CLI | Service discovery, deployments, env variable lifecycle |
| Coolify REST API | Full service metadata and compose-level patch operations |
| Browser | Admin UI flows where CLI/API is insufficient |

## Known Service UUIDs (Verify Before Use)

| Service | UUID |
|---|---|
| Joplin Sync | `koog44w0gksogwwksc00k0k8` |
| Authentik | `i4oogsg08sgok8scc440ogog` |
| Pangolin Newt | `lgsss04wg8g8g4c44wkg4o8w` |
| OpenCloud | `c80sswg4cscgs0googscc8kw` |

These identifiers were observed in prior sessions and should be revalidated before mutating operations.

## Common Runtime Targets

| Target | Typical Pattern |
|---|---|
| Authentik server container | `authentik-server-<service-uuid>` |
| Authentik worker container | `authentik-worker-<service-uuid>` |
| Service directory on resource host | `/data/coolify/services/<service-uuid>/` |
| Coolify local config | `~/.config/coolify/config.json` |

## Practical Routing Rules

1. If the task is about host resources, storage, kernel, or Proxmox internals, start on `lan-proxmox`.
2. If the task is about a running app container or Docker runtime, start on `cool-res`.
3. If the task is about service metadata or compose definitions, use Coolify CLI/API.
4. If API behavior is unclear, retrieve service state first and avoid speculative writes.
