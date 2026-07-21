# Hot-Path Batch 3

## Scope

The third hot-path batch defines the display-session boundary.

Included role:

- `hyprland`

This batch intentionally keeps the boundary narrow:

- SDDM remains the only owner of display-manager state.
- PAM and fingerprint policy remain separate from Hyprland.
- GPU drivers and vendor-specific graphics behavior remain separate from Hyprland.
- user-session rendering remains future chezmoi work.

## Ownership

### `hyprland`

Owns:

- Hyprland session-substrate packages
- UWSM package presence for session launch
- XDG desktop portal package presence for Wayland integration
- a desktop authentication-agent package for GUI polkit prompts
- validation of the system-level Hyprland session substrate

Does not own:

- SDDM theme or `/etc/sddm.conf.d/*`
- PAM files such as `/etc/pam.d/hyprlock`
- fingerprint services, udev rules, or watchdog units
- GPU drivers, kernel modules, modprobe files, or resume workarounds
- files rendered into `$HOME`
- Waybar, launcher, notification, wallpaper, or Hyprland user config rendering

## System session vs user rendering

### Ansible system-session ownership

Ansible owns only the system state required for a Hyprland-capable login session to exist:

- compositor and lock/idle packages
- UWSM package presence
- desktop portal packages
- a polkit authentication agent package
- system-level validation that the session substrate exists

### Future chezmoi user rendering

chezmoi will own the rendered user session:

- `~/.config/hypr/**`
- `~/.config/waybar/**`
- `~/.config/walker/**`
- `~/.config/mako/**` or equivalent notification config
- `~/.config/current/theme/**`
- user autostart and user systemd units under `$HOME`
- host-specific monitor and input rendering

## Explicitly deferred

Deferred to later hot-path or edge-case batches:

- `fingerprint`
- `nvidia`
- `amd_gpu`
- `tlp`
- `resolved`
- `openfortivpn`
- chezmoi-driven user-session migration

## Current implementation rule

The batch-3 implementation is intentionally limited to the current real Hyprland fleet.

- current managed Hyprland hosts are Arch-family
- Debian-family Hyprland activation is deferred until package-track metadata is explicit in inventory
- no package-track inference is allowed inside the role

## No-overlap rule

The `hyprland` role must never become a catch-all for display-stack leftovers.

If a change primarily concerns authentication, fingerprint behavior, GPU behavior, or user-rendered session config, it belongs to another owner.
