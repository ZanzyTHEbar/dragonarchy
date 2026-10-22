# Package manifest contract (Ansible ↔ `deps.manifest.toml`)

## Goal

`scripts/install/deps.manifest.toml` is the **only** canonical definition of package groups, manager channels, and host/feature gates.

Ansible inventory describes **host identity and capabilities**; the **packages** role resolves **which manifest groups apply** and installs **repo-native** packages (`pacman` / `apt`) from a **resolved plan** produced by `scripts/install/export-package-plan.sh`.

AUR (`paru`), vendor tarballs, and `script`-channel installs remain **explicit required tiers when selected**: they are not silently folded into `ansible.builtin.package` with a pacman backend. Every group selected by inventory is required; there is no per-package optional flag. Host-specific extras are modeled as separate `host_*` groups that the active Ansible inventory does not select. Selecting one makes its provider requirement binding. The legacy `install-deps.sh` still auto-installs host-specific groups on matching hosts.

## Resolution inputs

| Input | Source | Notes |
|-------|--------|--------|
| **platform** | `host_platform_family` | `arch` → manifest `arch`; `debian` → manifest `debian`. |
| **host** | `inventory_hostname` | Matches `requires_hosts` / `exclude_hosts` and `host_*` groups. |
| **features** | Derived in Ansible | e.g. `hyprland` when `host_desktop_stack == 'hyprland'`. Maps to `requires_features` in manifest groups. |
| **groups** | `host_profile_packages` + aliases | Logical “profiles” (e.g. `core_cli`, `host_dragon_workstation`) must name manifest **group keys** under some `platforms.<platform>.<manager>.<group>`. Aliases translate short names (e.g. `firedragon_laptop` → `host_firedragon_laptop`). |

Bundles (`[bundles.*]` in the manifest) are used by `install-deps.sh --bundle`; Ansible convergence uses **explicit group lists** per host so inventory stays explicit. You can still align a host’s list with a bundle’s group set when desired.

## Host-specific opt-in groups

A package that is not part of the required managed baseline belongs in a dedicated `host_*` group with `requires_hosts`, not inside a broadly selected group. The active Ansible inventory does not select these groups:

| Group | Manifest manager | Hosts | Packages |
|-------|------------------|-------|----------|
| `host_firedragon_gestures` | `paru` | `firedragon` | `libinput-gestures` |
| `host_debian_installer_ui` | `script` | `microdragon`, `opencode-runtime`, `ubuntu-mobile-dev` | `gum` |
| `host_ubuntu_mobile_dev_github_cli` | `script` | `ubuntu-mobile-dev` | `gh` |

Adding one of these groups to `host_profile_packages` deliberately makes it required; the unresolved provider gate then blocks full convergence until a provider is implemented and qualified. The legacy `install-deps.sh` auto-installs `host_*` groups on their matching hosts.

## Package tiers

| Tier | Manifest managers | Disposable / minimal validation | Ansible `packages` role (default) |
|------|--------------------|----------------------------------|-------------------------------------|
| **repo-native** | `pacman`, `apt` | Safe to assert on clean Arch/Debian images with default repos enabled | Installs these packages |
| **AUR** | `paru` | Requires AUR helper / build tooling; separate gate | Nonempty `pending.paru` from selected groups blocks before the role installs any package |
| **vendor / script** | `script` | May download binaries or run installers; separate gate | Nonempty `pending.script` from selected groups blocks before the role installs any package |

The packages role retains legacy pending-tier variables only to reject unsupported overrides:

- `packages_pending_paru_policy: fail`
- `packages_pending_script_policy: fail`

Both default to `fail`; `report` is refused before resolution or installation, even with empty pending lists. The exporter does not mutate target hosts and remains the read-only reporting interface, not an authorization for green provisioning. There is no provider URL/version/installer guessed by this role, and preinstalled packages do not bypass pending-tier refusal. Managed providers require separate implementation and qualification.

The Ansible resolver runs the exporter with `--no-bootstrap`, so plan generation never downloads or bootstraps yq on the controller. It requires and executes a preinstalled `mikefarah` yq v4; `install` rejects a missing or incompatible parser before running Ansible. The legacy `install-deps.sh` path retains its own explicit bootstrap behavior.

Before installing any package, the role validates the existing exporter JSON contract: metadata (`manifest`, `platform`, `host`, `feature_csv`), exact `requested_groups`, group entries (`manager`, `group`, `tier`, `packages`), all four `by_manager` arrays, both `ansible_install` arrays and both `pending` arrays. Required fields cannot default to empty lists. Package values must be nonblank strings; every selected group must contribute at least one package across its manager entries, so an individual manager entry may be empty when a sibling entry for the same group contributes packages. A selected group with no packages at all fails closed rather than counting as complete. Group coverage and flattened lists must agree. Arch accepts pacman/paru/script group providers; Debian accepts apt/script. Native installation runs only for the matching target platform. Missing, malformed or inconsistent plans fail with host/group/tier context.

`python3 tests/shell/package-closure-check.py` evaluates the production role's task assertions, conditions and facts with installed Ansible templating libraries and spies on package actions. It neither runs Ansible commands nor executes the exporter or package modules. This isolated proof does not qualify native package availability, privileges, providers or fleet readiness; native VM qualification remains deferred.

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
