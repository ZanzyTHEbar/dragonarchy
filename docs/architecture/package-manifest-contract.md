# Package manifest contract (Ansible ↔ `deps.manifest.toml`)

## Goal

`scripts/install/deps.manifest.toml` is the **only** canonical definition of package groups, manager channels, and host/feature gates.

Ansible inventory describes **host identity and capabilities**; the **packages** role resolves **which manifest groups apply** and installs **repo-native** packages (`pacman` / `apt`) from a **resolved plan** produced by `scripts/install/export-package-plan.sh`.

AUR (`paru`), vendor tarballs, and `script`-channel installs remain **explicit tiers**: they appear in the exported plan for inspection and optional follow-up—they are not silently folded into `ansible.builtin.package` with a pacman backend.

## Resolution inputs

| Input | Source | Notes |
|-------|--------|--------|
| **platform** | `host_platform_family` | `arch` → manifest `arch`; `debian` → manifest `debian`. |
| **host** | `inventory_hostname` | Matches `requires_hosts` / `exclude_hosts` and `host_*` groups. |
| **features** | Derived in Ansible | e.g. `hyprland` when `host_desktop_stack == 'hyprland'`. Maps to `requires_features` in manifest groups. |
| **groups** | `host_profile_packages` + aliases | Logical “profiles” (e.g. `core_cli`, `host_dragon_workstation`) must name manifest **group keys** under some `platforms.<platform>.<manager>.<group>`. Aliases translate short names (e.g. `firedragon_laptop` → `host_firedragon_laptop`). |

Bundles (`[bundles.*]` in the manifest) are used by `install-deps.sh --bundle`; Ansible convergence uses **explicit group lists** per host so inventory stays explicit. You can still align a host’s list with a bundle’s group set when desired.

## Package tiers

| Tier | Manifest managers | Disposable / minimal validation | Ansible `packages` role (default) |
|------|--------------------|----------------------------------|-------------------------------------|
| **repo-native** | `pacman`, `apt` | Safe to assert on clean Arch/Debian images with default repos enabled | Installs these packages |
| **AUR** | `paru` | Requires AUR helper / build tooling; separate gate | Exposed in plan as `pending.paru`; not installed by default |
| **vendor / script** | `script` | May download binaries or run installers; separate gate | Exposed as `pending.script` |

## Capability-backed groups

Hardware or policy stacks that used to duplicate package lists in roles (AMD GPU, NVIDIA, TLP) are represented as **manifest groups** gated by `requires_hosts` (and optional features). Roles keep **configuration, kernel params, and verification**; they do not re-define package names.

## Provenance

Every export includes `manifest` path, `platform`, `host`, `feature_csv`, `groups`, and per-entry `manager`, `group`, `tier`, and `packages`. Operators and CI can diff plans without re-running Ansible.

## Related files

- Canonical manifest: `scripts/install/deps.manifest.toml`
- Resolution helpers: `scripts/lib/manifest-toml.sh`
- Plan export: `scripts/install/export-package-plan.sh`
- Legacy installer (still uses same manifest): `scripts/install/install-deps.sh`
- Ansible: `infra/ansible/roles/packages/`
