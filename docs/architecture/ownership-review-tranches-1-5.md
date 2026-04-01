# Ownership Review: Tranches 1-5

## Scope

This review extends the ownership-overlap check through the full implemented hot-path set before broader edge-case work and larger chezmoi cutover proceeds.

Reviewed tranches:

- tranche 1: `base`, `packages`, `users`
- tranche 2: `sddm`
- tranche 3: `hyprland`
- tranche 4: `fingerprint`, `nvidia`, `amd_gpu`
- tranche 5: `tlp`, `resolved`, `openfortivpn`

## Findings

No direct ownership violations were found in the implemented tranche contracts.

The tranche-5 split remains consistent with the earlier tranche reviews:

- `tlp` stays limited to laptop power-policy system state.
- `resolved` stays limited to systemd-resolved configuration and service state.
- `openfortivpn` stays limited to Fortinet VPN system state, helper installation, and service ownership.

The current full hot-path split is coherent:

- `base` owns minimal baseline state.
- `packages` owns portable package-profile installation.
- `users` owns local users and required admin-group membership.
- `sddm` owns display-manager theme and service state only.
- `hyprland` owns only the system session substrate.
- `fingerprint` owns auth-adjacent system state.
- `nvidia` and `amd_gpu` own driver and resume behavior.
- `tlp` owns laptop power-policy system state.
- `resolved` owns resolved configuration and service state.
- `openfortivpn` owns Fortinet VPN system state.

## Residual risks

The remaining risks are no longer about obvious Ansible role overlap.

The current seams that still need care are:

- `fingerprint` still intentionally edits PAM for `sddm`, which is acceptable only while the ownership split remains auth policy versus display-manager theming.
- `resolved` is currently an inventory-owned rollout selector rather than a host capability token, so that distinction must stay documented to avoid duplicate truth.
- `openfortivpn` installs user-visible Waybar marker prerequisites under system ownership, while the marker files themselves remain chezmoi-owned user state.
- the largest remaining architecture risk is still partial ownership during Stow-to-chezmoi cutover of `$HOME`.

## Review result

The tranche-1 through tranche-5 contracts are acceptable to continue from.

The current architecture is ready to proceed into:

1. first-host chezmoi cutover execution
2. edge-case cleanup
3. follow-on simplification and iteration
