# Hot-Path Tranche 1

## Scope

The first hot-path tranche includes only:

- `base`
- `packages`
- `users`

This is intentionally narrow.

It creates a real migration slice without dragging in display stack, GPU, authentication, VPN, or user-state rendering too early.

## Ownership

### `base`

Owns:

- minimal host-wide baseline state
- explicit baseline validation

Current tranche-1 implementation:

- timezone management

### `packages`

Owns:

- cross-distro package installation
- explicit package profile resolution
- distro-specific package naming

Current tranche-1 package profiles:

- `core_cli`
- `dev`

Current tranche-1 package policy:

- keep the profiles minimal and portable
- avoid GUI-terminal assumptions in `core_cli`
- avoid high-drift packages like `terraform` in tranche 1
- prefer release-safer Debian mappings such as `fd-find` and `lsd`

### `users`

Owns:

- local users
- local supplementary groups required by those users

It does not own user dotfiles or rendered `$HOME` content.

Current tranche-1 user policy:

- manage only the primary operator account per host
- use the platform-default admin group only
- defer display- and container-adjacent groups until the owning roles exist

## Explicitly deferred

Deferred to later hot-path or edge-case batches:

- `sddm`
- `hyprland`
- `tlp`
- `fingerprint`
- `nvidia`
- `amd_gpu`
- `resolved`
- `openfortivpn`
- chezmoi-driven user-state migration

## Implementation order

1. foundation contract
2. `base`
3. `packages`
4. `users`

## No-fallback rule

This tranche follows the same architecture rule as foundation:

- no alternate execution paths
- no best-effort continuation for role contracts
- no hidden ownership overlap
