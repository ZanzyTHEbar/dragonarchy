# Migration Phases

## Approved sequence

1. foundation
2. hot paths
3. edge cases
4. review
5. iterate

## Foundation

Deliverables:

- control-plane skeleton
- host model
- role contract
- ownership boundaries
- initial playbook graph

## Hot paths

First expected roles:

- `base`
- `packages`
- `users`
- `sddm`
- `hyprland`
- `tlp`
- `fingerprint`
- `nvidia`
- `amd_gpu`
- `resolved`
- `netbird`
- `openfortivpn`

## Edge cases

Examples:

- Arch vs Debian package name drift
- desktop vs server divergence
- vendor-specific laptop behavior
- GPU-specific behavior
- secrets-backed user config

Current implemented edge-case role:

- `asus_laptop`
- `hibernation`

## Review

Review must check:

- ownership overlap
- unsupported assumptions
- hidden fallback logic
- duplicated host truth
- role boundary violations

## Iterate

Iteration is for simplification and tightening, not for reintroducing parallel legacy architecture.
