# Host Model

## Source of truth

The new architecture uses Ansible inventory plus host variables as the only runtime source of truth.

## Inventory groups

Foundation currently models the following group axes:

- distro family: `arch`, `debian`
- form factor / role: `desktop`, `laptop`, `server`
- capability groups: `hyprland`, `fingerprint`, `amd_gpu`, `nvidia`, `netbird`, `fortinet_vpn`

These groups are explicit declarations, not inferred tags.

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

### `firedragon`

- role: `laptop`
- platform family: `arch`
- desktop stack: `hyprland`
- gpu stack: `amd-gpu`

### `goldendragon`

- role: `laptop`
- platform family: `arch`
- desktop stack: `hyprland`
- gpu stack: `intel`, `nvidia`

### `microdragon`

- role: `server`
- platform family: `debian`
- desktop stack: `none`
- gpu stack: none

## Legacy data sources

These remain reference material only:

- `hosts/<host>/.traits`
- `hosts/<host>/setup.sh`
- `hosts/<host>/etc/`
- `hosts/<host>/dotfiles/`

They must not become the runtime source of truth in the new architecture.
