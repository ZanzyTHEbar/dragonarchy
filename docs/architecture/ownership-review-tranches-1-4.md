# Ownership Review: Tranches 1-4

## Scope

This review checks the first four hot-path tranches for ownership overlap before broader user-state migration expands.

Reviewed tranches:

- tranche 1: `base`, `packages`, `users`
- tranche 2: `sddm`
- tranche 3: `hyprland`
- tranche 4: `fingerprint`, `nvidia`, `amd_gpu`

## Findings

No direct ownership violations were found in the implemented tranche contracts.

The current split is consistent:

- `base` remains limited to minimal host baseline state.
- `packages` remains limited to portable package-profile ownership.
- `users` remains limited to local account and default group ownership.
- `sddm` owns display-manager theme and service state only.
- `hyprland` owns only system session-substrate packages and validation.
- `fingerprint` owns auth-adjacent system state and host-specific fingerprint PAM state.
- `nvidia` and `amd_gpu` own driver, module, and GPU resume behavior only.

## Residual risks

The current architecture is clean, but these seams still need attention:

- `fingerprint` intentionally manages PAM entries in `/etc/pam.d/sddm` while `sddm` owns the display manager. This is acceptable only because the ownership split is by concern: auth policy versus greeter/theme state.
- `amd_gpu` owns GPU-tool polkit rules when present. Future non-GPU polkit policy must not drift into the GPU roles.
- `hyprland` still references user-session files and scripts that are not yet chezmoi-owned. This is not a role overlap, but it is still a migration gap.

## Review result

The tranche-1 through tranche-4 contracts are acceptable to continue from.

The next architectural risk is no longer role overlap inside Ansible.

The next architectural risk is partial ownership between legacy Stow-managed `$HOME` content and future chezmoi-managed `$HOME` content during cutover.
