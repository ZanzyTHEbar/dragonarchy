# Hot-Path Tranche 4

## Scope

The fourth hot-path tranche defines the authentication and GPU ownership boundaries.

Included roles:

- `fingerprint`
- `nvidia`
- `amd_gpu`

This tranche intentionally keeps the boundary narrow:

- `fingerprint` owns fprintd and PAM/auth-adjacent system state.
- `nvidia` owns NVIDIA driver and kernel-module behavior.
- `amd_gpu` owns AMD GPU driver and resume behavior.
- SDDM remains the only owner of display-manager state.
- Hyprland remains the owner only of the system session substrate.
- rendered `$HOME` session files remain future chezmoi work.

## Ownership

### `fingerprint`

Owns:

- fprintd package installation
- fingerprint device udev policy
- fingerprint suspend/resume hook installation
- PAM fingerprint policy for managed authentication surfaces
- host-specific `/etc/pam.d/hyprlock` when fingerprint-backed lock auth is required

Does not own:

- SDDM theme assets or `/etc/sddm.conf.d/*`
- Hyprland user configuration
- GPU drivers or resume units
- user-level watchdog timers under `$HOME`

### `nvidia`

Owns:

- NVIDIA driver package installation
- NVIDIA kernel-module configuration under `/etc/modprobe.d`
- `/etc/modules-load.d/nvidia.conf`
- persistent kernel parameter management for NVIDIA DRM modesetting

Does not own:

- SDDM config
- Hyprland user-session environment files
- PAM or fingerprint policy
- TLP, VPN, or generic laptop power policy

### `amd_gpu`

Owns:

- AMD GPU package installation
- AMD GPU kernel-module configuration under `/etc/modprobe.d`
- `/etc/modules-load.d/amd.conf`
- AMD GPU resume services and related bootloader/kernel parameter state
- GPU-adjacent polkit rules that belong to GPU tooling such as CoreCtrl

Does not own:

- SDDM config
- Hyprland user-session environment files
- PAM or fingerprint policy
- AIO cooler ownership
- TLP, VPN, or generic laptop power policy

## Explicitly deferred

Deferred to later hot-path or edge-case batches:

- `tlp`
- `resolved`
- `openfortivpn`
- user-level fingerprint watchdog units
- chezmoi-driven session rendering for Hyprland, Waybar, launchers, and host-specific user files

## Current implementation rule

The tranche-4 implementation is intentionally limited to the current real Arch-family hardware fleet:

- `fingerprint` currently targets `goldendragon`
- `nvidia` currently targets `goldendragon`
- `amd_gpu` currently targets `dragon` and `firedragon`
- no Debian-family GPU or fingerprint path is inferred or auto-created

## No-overlap rule

If a change primarily concerns login-manager theming, compositor package substrate, or rendered user-session config, it belongs to another owner.

If a change primarily concerns host power policy outside GPU driver recovery, it belongs to a later owner.
