# Hot-Path Batch 2

## Scope

The second hot-path batch centers on the display-manager boundary.

Included role:

- `sddm`

This batch intentionally avoids broader display-stack ownership so it can establish one clean owner for login-manager state before Hyprland, GPU, fingerprint, or VPN work begins.

## Ownership

### `sddm`

Owns:

- SDDM package installation
- managed SDDM theme assets under `/usr/share/sddm/themes`
- `/etc/sddm.conf.d/10-theme.conf`
- SDDM service enablement
- validation of the configured theme path and theme config

Does not own:

- Hyprland configuration
- PAM fingerprint policy
- GPU driver or kernel configuration
- user-session rendering

## Explicitly deferred

Deferred to later hot-path or edge-case batches:

- `hyprland`
- `fingerprint`
- `nvidia`
- `amd_gpu`
- `tlp`
- `resolved`
- `openfortivpn`
- chezmoi-driven user-state migration

## Implementation rule

The `sddm` role is the only owner of display-manager theme configuration in the new control plane.

Legacy shell helpers remain reference material during migration, but they are not the target runtime ownership model.
