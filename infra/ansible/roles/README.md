# Ansible Role Contract

Every role in `infra/ansible/roles` must follow the same contract.

## Required properties

- explicit ownership
- explicit distro support
- explicit variables
- explicit validation
- no fallback logic
- no hidden side effects

## Required layout

```text
roles/<role>/
  defaults/main.yml
  tasks/main.yml
  handlers/main.yml
  meta/main.yml
```

Additional files like `templates/`, `files/`, `vars/`, and split task files are added only when the role actually needs them.

## Role rules

1. A role must own a clear concern.
2. A role must fail if required inputs are missing.
3. A role must not silently continue on unsupported platforms.
4. A role must not edit files or manage services that belong to another role.
5. A role must validate the state it is responsible for.

## Current role set

The current control plane contains:

- `common`
- `base`
- `packages`
- `users`
- `sddm`
- `hyprland`
- `fingerprint`
- `nvidia`
- `intel_gpu`
- `amd_gpu`
- `tlp`
- `asus_laptop`
- `hibernation`
- `resolved`
- `netbird`
- `openfortivpn`
- `aio-cooler`
- `v4l2loopback`
- `power_sleep`
- `iwd`
- `networkmanager`
- `acpi_wakeup`

## Package ownership

The `packages` role does not author package lists. It runs `scripts/install/export-package-plan.sh` against `scripts/install/deps.manifest.toml` using inventory (`host_profile_packages`, host name, features). Repo-native installs use `pacman`/`apt`; `paru` and `script` tiers are reported as pending. See `docs/architecture/package-manifest-contract.md`.

## Service ownership

Service enablement belongs to the role that owns the service contract. Roles must not recreate legacy `system-services.sh` behavior by enabling units opportunistically just because they are installed.

Examples:

- `iwd` owns `iwd.service` for hosts in the `iwd` group.
- `networkmanager` owns `NetworkManager.service` for hosts in the `networkmanager` group.
- `acpi_wakeup` owns `disable-acpi-wakeup.service` for hosts in the `acpi_wakeup` group.
- `power_sleep` owns declared power-adjacent platform services such as `acpid.service` and `thermald.service` only when listed for a host.

Roles that manage network service configuration must document whether config changes are applied immediately. `iwd` deliberately avoids automatic restarts because restarting Wi-Fi can drop remote convergence; apply its config changes with a controlled restart or reboot.

## Foundation role

`common` remains the foundation role.

Its purpose is to:

- validate the shared architecture contract
- validate core host metadata
- expose a deterministic host summary

It still does not install packages or manage services directly.

The hot-path roles build on top of that contract rather than replacing it.
