# Hot-Path Tranche 5

## Scope

The fifth hot-path tranche finishes the remaining system-service ownership before user-state migration expands.

Included roles:

- `tlp`
- `resolved`
- `openfortivpn`

This tranche intentionally keeps the boundary narrow:

- `tlp` owns laptop power-policy system state.
- `resolved` owns systemd-resolved configuration and service state.
- `openfortivpn` owns the Fortinet VPN system package, service units, helper installation, and system config path.
- user-facing Waybar host markers remain chezmoi-owned user state.

## Ownership

### `tlp`

Owns:

- TLP package installation
- host-specific `/etc/tlp.d/*.conf`
- `tlp.service` and `tlp-sleep.service`
- masking conflicting `systemd-rfkill` units
- disabling conflicting `power-profiles-daemon`

Does not own:

- GPU driver state
- fingerprint PAM state
- user aliases or user power UX files

### `resolved`

Owns:

- host-specific `/etc/systemd/resolved.conf.d/*.conf`
- `systemd-resolved.service`

Does not own:

- VPN credential files
- NetBird DNS integration logic
- user-facing network menus

### `openfortivpn`

Owns:

- `openfortivpn` package installation
- `/etc/openfortivpn/config`
- `/etc/openfortivpn/waybar.conf`
- `/usr/local/bin/avular-vpn-dns`
- `openfortivpn` system group and host operator group membership
- `openfortivpn.service` and `openfortivpn-cleanup.service`

Does not own:

- user-session Waybar marker files under `$HOME`
- Waybar module configuration
- generic DNS owner state outside the VPN helper flow

## Explicitly deferred

Deferred to the next phase:

- first real chezmoi migration slices
- ownership-overlap review across completed tranches
- edge-case cleanup for distro- and hardware-specific drift

## No-overlap rule

If a change primarily affects `$HOME`, launcher rendering, Waybar host markers, or Hyprland session files, it belongs to chezmoi.

If a change primarily affects PAM, fprintd, or GPU recovery, it belongs to the tranche-4 roles.
