# Known Limitations

## Linux Only

Full-network VPN mode requires `--network host`, which only exposes the container's network namespace to the **Linux host**. 

- **macOS Docker Desktop**: The container runs in a Linux VM. The `ppp0` interface is created inside the VM, not on the macOS host. Full-network VPN is **not supported** on macOS.
- **Windows WSL2**: The container shares the WSL2 VM's network namespace. The `ppp0` interface is visible inside WSL2 but not on the Windows host. Routing Windows traffic through it requires additional WSL2 network configuration.

## Privileged Container Required

`pppd` needs `CAP_NET_ADMIN` and access to `/dev/ppp` to create kernel interfaces. The container must run with `--privileged` (or explicit `--cap-add=NET_ADMIN --device=/dev/ppp`). There is no way around this for PPP-based VPNs.

## `/etc/resolv.conf` Conflicts

On hosts where `/etc/resolv.conf` is managed by `systemd-resolved`, `NetworkManager`, or another service, our direct manipulation may be overwritten. Use `DNS_METHOD=resolved` on systemd hosts to avoid conflicts.

## SAML Port Conflicts

If port `8020` (or your configured `SAML_PORT`) is already in use on the host, the SAML listener will fail. Change `SAML_PORT` to an available port.

## No Route Conflict Resolution

If the VPN subnet overlaps with your local network, routing may need manual intervention. The container does not automatically resolve subnet conflicts.

## macOS / Windows SOCKS5 Proxy Alternative

For macOS and Windows users, a future enhancement could add a SOCKS5 proxy mode where only specific applications route through the VPN, avoiding the network namespace limitation.
