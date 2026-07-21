# Host Model

## Source of truth

The new architecture uses Ansible inventory plus host variables as the only runtime source of truth.

The rule is:

- host variables define host identity and declared capabilities
- inventory groups are the execution selectors
- where a capability has a matching execution group, both must stay aligned

## Inventory groups

The current inventory models these group axes:

- distro family: `arch`, `debian`
- form factor / role: `desktop`, `laptop`, `server`
- desktop stack: `hyprland`
- display manager: `sddm`
- GPU / hardware: `amd_gpu`, `intel_gpu`, `nvidia`, `aio_cooler`, `v4l2loopback`
- capability or rollout groups: `tlp`, `fingerprint`, `netbird`, `fortinet_vpn`, `asus`, `hibernation`, `power_sleep`, `iwd`, `networkmanager`, `acpi_wakeup`, `resolved`

These groups are explicit declarations, not inferred tags.

## Metadata-to-group contract

The inventory is not allowed to drift away from host metadata.

The current contract is:

- `host_role` must match one of `desktop`, `laptop`, or `server`
- `host_platform_family` must match one of `arch` or `debian`
- `host_desktop_stack: hyprland` must match the `hyprland` inventory group
- `host_gpu_stack` entries map to execution groups:
  - `amd-gpu` -> `amd_gpu`
  - `intel` -> `intel_gpu`
  - `nvidia` -> `nvidia`
- `host_capabilities` entries currently map to execution groups when they are role-owned:
  - `tlp` -> `tlp`
  - `fingerprint` -> `fingerprint`
  - `netbird` -> `netbird`
  - `fortinet_vpn` -> `fortinet_vpn`
  - `asus` -> `asus`
  - `hibernation` -> `hibernation`
  - `aio-cooler` -> `aio_cooler`
  - `v4l2loopback` -> `v4l2loopback`
  - `power_sleep` -> `power_sleep`
  - `iwd` -> `iwd`
  - `networkmanager` -> `networkmanager`
  - `acpi_wakeup` -> `acpi_wakeup`

Not every inventory group has to come from `host_capabilities`.

`resolved` and `sddm` are currently inventory-owned rollout selectors rather than host capability tokens, because they represent where a role is active rather than permanent host traits.

## Required host variables

Every managed host must define:

- `host_role`
- `host_platform_family`
- `host_desktop_stack`
- `host_gpu_stack`
- `host_capabilities`
- `legacy_host_directory`

## Current host mapping

### `dragon`

- role: `desktop`
- platform family: `arch`
- desktop stack: `hyprland`
- gpu stack: `amd-gpu`
- capabilities: `aio-cooler`, `netbird`, `v4l2loopback`, `power_sleep`

### `firedragon`

- role: `laptop`
- platform family: `arch`
- desktop stack: `hyprland`
- gpu stack: `amd-gpu`
- capabilities: `tlp`, `asus`, `hibernation`, `netbird`

### `goldendragon`

- role: `laptop`
- platform family: `arch`
- desktop stack: `hyprland`
- gpu stack: `intel`, `nvidia`
- capabilities: `tlp`, `fingerprint`, `fortinet_vpn`, `v4l2loopback`, `power_sleep`, `iwd`, `networkmanager`, `acpi_wakeup`

### `microdragon`

- role: `server`
- platform family: `debian`
- desktop stack: `none`
- gpu stack: none
- capabilities: `netbird`

### `opencode-runtime`

- role: `server`
- platform family: `debian`
- desktop stack: `none`
- gpu stack: none
- capabilities: none
- connection: local container/runtime profile

## Legacy data sources

These remain reference material only:

- `hosts/<host>/.traits`
- `hosts/<host>/setup.sh`
- `hosts/<host>/etc/`
- `hosts/<host>/dotfiles/`

They must not become the runtime source of truth in the new architecture.
