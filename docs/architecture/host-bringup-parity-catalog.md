# Host Bringup Parity Catalog — leaf 1.1.1 baseline

## Purpose

This document catalogs the repository baseline needed to reach full host bringup parity after the managed-host pivot to Ansible + chezmoi.

It is **not** a parity approval. Every relationship in this document is a
proposal with a named producer, writer, verifier, recovery owner and pending
decision owner. The machine-readable enumeration is
`docs/architecture/ansible-chezmoi-retirement/gates/contract/baseline.json`;
this catalog is its human-facing reconciliation.

## Baseline boundary

- The historical catalog modeled four hosts (`dragon`, `firedragon`,
  `goldendragon`, `microdragon`). The current inventory contains six, adding
  `opencode-runtime` and `ubuntu-mobile-dev`; all six are listed below.
- `AUDIT.md` remains immutable. Its recorded SHA-256 is checked by the leaf
  test. Corrections and current observations belong in the contract baseline,
  not in the audit.
- Repository presence, role presence, archived runbooks, historical success,
  cleanup claims and task percentages are not current-SHA or live-host proof.
  Live drift, credentials, hardware state, exact platform facts and current
  host outcomes remain **UNKNOWN**.
- `PENDING` means unresolved. It is not retained, retired, approved,
  parity-complete or permission to execute a live operation.

The goal is not a vague migration summary.

The goal is a host-by-host implementation catalog of:

1. legacy source files and behaviors that still matter
2. current Ansible + chezmoi ownership and coverage
3. exact remaining parity gaps
4. a surgical checklist to reach 1:1 bringup parity

## Comparison basis

The comparison uses these facts:

- the historical `main` comparison had no `infra/` control plane; this
  checkout's current branch does
- `./install` is the canonical managed-host entrypoint
- `./install.sh` is deprecated and guarded for managed hosts
- legacy host trees under `hosts/<host>/etc/` and `hosts/<host>/dotfiles/` are repository payload candidates referenced by Ansible roles and chezmoi manifests until fully absorbed or explicitly retained
- the current branch adds the new architecture primarily under:
  - `infra/ansible/`
  - `infra/chezmoi/`
  - `infra/packer/`

That means most parity analysis is:

- legacy shell behavior that remains as reference or recovery path
- versus inventory, roles, manifests, and validation in the current branch

## In-scope hosts

Current inventory hosts from `infra/ansible/inventory/hosts.yml`:

- `dragon`
- `firedragon`
- `goldendragon`
- `microdragon`
- `opencode-runtime`
- `ubuntu-mobile-dev`

## Current new-architecture host mapping

### `dragon`

- groups: `arch`, `desktop`, `resolved`, `hyprland`, `sddm`, `amd_gpu`, `aio_cooler`, `netbird`, `v4l2loopback`, `power_sleep`
- host vars: `infra/ansible/inventory/host_vars/dragon.yml`
- capabilities: `aio-cooler`, `netbird`, `v4l2loopback`, `power_sleep`

### `firedragon`

- groups: `arch`, `desktop`, `laptop`, `tlp`, `asus`, `hibernation`, `resolved`, `hyprland`, `sddm`, `amd_gpu`, `netbird`
- host vars: `infra/ansible/inventory/host_vars/firedragon.yml`
- capabilities: `tlp`, `asus`, `hibernation`, `netbird`

### `goldendragon`

- groups: `arch`, `desktop`, `laptop`, `tlp`, `resolved`, `hyprland`, `sddm`, `fingerprint`, `nvidia`, `intel_gpu`, `fortinet_vpn`, `v4l2loopback`, `power_sleep`, `iwd`, `networkmanager`, `acpi_wakeup`
- host vars: `infra/ansible/inventory/host_vars/goldendragon.yml`
- capabilities: `tlp`, `fingerprint`, `fortinet_vpn`, `v4l2loopback`, `power_sleep`, `iwd`, `networkmanager`, `acpi_wakeup`

### `microdragon`

- groups: `debian`, `server`, `netbird`
- host vars: `infra/ansible/inventory/host_vars/microdragon.yml`
- capabilities: `netbird`

### `opencode-runtime`

- groups: `debian`, `server`
- host vars: `infra/ansible/inventory/host_vars/opencode-runtime.yml`
- capabilities: explicit local-connection runtime targeting; no host
  capability list is selected in the current inventory

### `ubuntu-mobile-dev`

- groups: `debian`, `desktop`, `hyprland`, `sddm`
- host vars: `infra/ansible/inventory/host_vars/ubuntu-mobile-dev.yml`
- capabilities: desktop/session composition; no host-specific capability list
  is selected in the current inventory

## Shared new-architecture ownership observations

The paths below are observed producers/candidates, not accepted ownership.
Role or manifest presence does not prove complete behavior, current target
state or retirement readiness.

Current role directories:

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

Current chezmoi scope is partial but now covers the first session-oriented slices plus zsh and devtool/SSH declarations:

- `infra/chezmoi/manifests/devtools-core.manifest`
- `infra/chezmoi/manifests/git-ssh.manifest`
- `infra/chezmoi/manifests/session-core.manifest`
- `infra/chezmoi/manifests/session-shell.manifest`
- `infra/chezmoi/manifests/session-zsh.manifest`

Current Packer scope is validation infrastructure, not host bringup ownership:

- `infra/packer/`

## Shared parity gaps

These gaps affect multiple hosts and must be understood before claiming 1:1 parity.

### 1. Top-level bringup path is replaced, legacy path still exists

Managed-host bringup now flows through:

- `./install`
- `infra/ansible/playbooks/site.yml`
- `infra/chezmoi/bin/chezmoi-sync`
- `chezmoi apply`

Legacy recovery/unmanaged bringup still exists under:

- `install.sh`
- `scripts/install/*`
- `hosts/<host>/setup.sh`

`install.sh` is deprecated and should not run for managed hosts without explicit `DOTFILES_LEGACY_INSTALL=1` opt-in.

### 2. Duplicate package truth

**Repository observation, still PENDING:** `scripts/install/deps.manifest.toml` is the proposed package source. The `packages` role resolves plans via `scripts/install/export-package-plan.sh` (see `docs/architecture/package-manifest-contract.md`). Role-local package lists were removed or emptied in some migrated areas (e.g. `amd_gpu`, `nvidia`, `tlp` stacks; `roles/packages/vars/main.yml` retired), but provider acceptance and complete selected plans remain downstream work.

**Remaining seams (incremental):** some roles still carry install lists for session/UI stacks (`hyprland`, `sddm`, `fingerprint`, `openfortivpn`) until those are folded into manifest-backed groups or host profiles in a later batch.

### 3. NetBird has a role candidate, but is not parity-complete

Hosts and capability mapping now have a candidate `roles/netbird`.

That means:

- `dragon`
- `firedragon`
- `microdragon`

all have an observed Ansible candidate for NetBird installation and service
state; this is not live or final ownership proof.

The remaining gap is host-specific parity around surrounding behavior:

- `microdragon` routing-peer behavior must stay verified
- `firedragon` still has additional DNS integration behavior outside the basic NetBird role
- legacy host setup scripts still remain as historical/reference paths until they are retired

### 4. Chezmoi does not yet cover full host user-state

Current manifests cover the first session-oriented slices plus zsh overlays.

Remaining gaps are other non-session host dotfiles and user-state that still sits outside the current manifests.

### 5. Validation is still not a full behavioral proof

The current managed-host parity gate is:

- `infra/validate-parity.sh`

It validates inventory membership, inferred role coverage, manifest source existence, host setup deprecation, and entrypoint presence. It does not yet prove full behavioral parity for running services, pending package tiers, or all runtime-generated user state.

## Shared duplicate ownership seams

These are the repo-wide cases where the new architecture is not yet the only meaningful owner.

They matter because parity is not enough if runtime ownership is still ambiguous.

If legacy shell, Stow, or host trees can still write or source the same concern, then the pivot is incomplete even when a new role exists.

### Duplicate ownership matrix (all rows PENDING)

The `Proposed owner` column records the current candidate only. Each row still
needs its named downstream decision and later behavioral verification.


| Domain                                            | Legacy owner paths                                                                                                                                     | Current new owner paths                                                                                             | Conflict type    | Proposed owner                                                                            | Remaining pivot work                                                                                                                          |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| top-level bringup                                 | `install.sh`, `scripts/install/*`, `hosts/<host>/setup.sh`                                                                                             | `./install`, `infra/ansible/playbooks/*.yml`, `infra/chezmoi/bin/chezmoi-sync`                                      | legacy seam      | Ansible + chezmoi                                                                          | keep legacy installer guarded and finish removing stale operator docs                                                                         |
| validation gate                                   | `scripts/install/validate.sh`                                                                                                                          | `infra/validate-parity.sh`, role `validate.yml` and `verify.yml`, CI syntax checks                                  | partial overlap  | Ansible/chezmoi parity gate                                                                | extend parity validation to strict behavioral checks and pending package tiers                                                                |
| package truth                                     | `scripts/install/deps.manifest.toml`                                                                                                                   | `infra/ansible/roles/packages` (manifest plan consumer) + optional legacy role overrides                                                           | PENDING          | proposed: **`deps.manifest.toml` + `export-package-plan.sh`**                             | leaf-1.1.5 must decide authority and keep thinning role-local lists (`hyprland`, `sddm`, …) into manifest groups                              |
| SDDM theme payload and active theme               | `packages/sddm/**`, `scripts/install/stow-system.sh`, `scripts/theme-manager/refresh-sddm`, `scripts/theme-manager/sddm-set`                           | `infra/ansible/roles/sddm/tasks/configure.yml`                                                                      | partial overlap  | Ansible `sddm` role                                                                        | stop using system Stow and theme-manager as the runtime writer for managed hosts                                                              |
| baseline polkit admin rule                        | `packages/polkit/etc/polkit-1/rules.d/49-wheel-admin.rules`                                                                                            | `infra/ansible/roles/base/tasks/configure.yml`                                                                      | full duplication | Ansible `base` role                                                                        | remove `polkit` from system-Stow bringup for managed hosts                                                                                    |
| fingerprint PAM insertion                         | `hosts/goldendragon/setup.sh`, `hosts/goldendragon/etc/pam.d/*`                                                                                        | `infra/ansible/roles/fingerprint/defaults/main.yml`, `infra/ansible/roles/fingerprint/tasks/configure.yml`          | partial overlap  | Ansible `fingerprint` role                                                                 | stop relying on `setup.sh` edits; own `sudo`, `polkit-1`, `system-local-login`, and `sddm` insertion only through the role                    |
| fingerprint sleep hook and hyprlock PAM           | `hosts/goldendragon/etc/systemd/system-sleep/99-fprintd-reset.sh`, `hosts/goldendragon/etc/pam.d/hyprlock`                                             | `infra/ansible/roles/fingerprint/tasks/configure.yml`                                                               | partial overlap  | Ansible `fingerprint` role                                                                 | keep host tree as payload source, not runtime writer                                                                                          |
| fingerprint watchdog                              | `hosts/goldendragon/scripts/fingerprint/*`                                                                                                             | `hosts/goldendragon/dotfiles/.local/bin/fprintd-watchdog`, `hosts/goldendragon/dotfiles/.config/systemd/user/*`, `session-shell.manifest` | partial overlap | chezmoi                                                                                    | remove obsolete script-oriented install path after real-host verification                                                                     |
| hyprlock PAM base path                            | `packages/hyprland/hyprlock.pam`, `scripts/install/setup/pam-hyprlock.sh`                                                                              | `infra/ansible/roles/fingerprint/tasks/configure.yml` for fingerprint hosts                                         | partial overlap  | Ansible for managed `/etc/pam.d/hyprlock`                                                  | define one policy for non-fingerprint and fingerprint hosts, then retire shell installers                                                     |
| Hyprland session packages                         | `scripts/install/install-deps.sh`, `scripts/install/deps.manifest.toml`                                                                                | `infra/ansible/roles/hyprland/*`, `infra/ansible/roles/packages/*`                                                  | partial overlap  | Ansible `hyprland` + `packages`                                                            | stop using installer package paths for Ansible-managed hosts                                                                                  |
| Hyprland user-state rendering                     | Stow of `packages/hyprland/**`, host dotfiles under `hosts/<host>/dotfiles/**`                                                                         | `infra/chezmoi/manifests/*.manifest`, `infra/chezmoi/bin/chezmoi-sync`                                              | migration seam   | chezmoi                                                                                    | finish manifest expansion and prove current sync/apply convergence                                                                            |
| theme-generated user files                        | `scripts/theme-manager/*` writes runtime state under `$HOME`                                                                                           | chezmoi manifests are beginning to own adjacent trees                                                               | migration seam   | split by concern: chezmoi for static user files, theme-manager for runtime-generated state | document every runtime-generated exception and either keep it runtime-owned or move generation into the new model                             |
| NVIDIA kernel and module state                    | `scripts/install/system-config.sh`, `hosts/goldendragon/etc/modprobe.d/*`                                                                              | `infra/ansible/roles/nvidia/*`                                                                                      | partial overlap  | Ansible `nvidia` role                                                                      | keep host tree as payload source, not runtime writer                                                                                          |
| AMD GPU kernel, module, polkit, and service state | `scripts/install/system-config.sh`, `hosts/dragon/etc/**`, `hosts/firedragon/etc/**`                                                                   | `infra/ansible/roles/amd_gpu/*`                                                                                     | partial overlap  | Ansible `amd_gpu` role                                                                     | keep host tree as payload source, not runtime writer                                                                                          |
| Intel GPU kernel and module state                 | `scripts/install/system-config.sh`                                                                                                                     | `infra/ansible/roles/intel_gpu/*`                                                                                   | PENDING          | proposed: Ansible `intel_gpu` role                                                         | leaf-1.1.2 platform decision and validate on goldendragon hardware                                                                             |
| laptop power policy                               | `scripts/install/setup/power-management.sh`, host TLP config under `hosts/*/etc/tlp.d/*`                                                               | `infra/ansible/roles/tlp/*`, `infra/ansible/roles/tlp/files/hosts/*`                                                | partial overlap  | Ansible `tlp` role                                                                         | retire shell-side service toggles for managed hosts and eventually delete or archive the legacy reference copy                                |
| resolved DNS drop-ins                             | legacy host-tree DNS copies                                                                                                                            | `infra/ansible/roles/resolved/*`, `infra/ansible/roles/resolved/files/hosts/*`                                      | PENDING          | proposed: Ansible `resolved` role                                                         | leaf-1.1.6 source decision; keep DNS payloads role-local unless the decision changes                                                            |
| OpenFortiVPN units and helper                     | `hosts/goldendragon/etc/systemd/system/openfortivpn*.service`, `hosts/goldendragon/dotfiles/.local/bin/avular-vpn-dns`                                 | `infra/ansible/roles/openfortivpn/*`, `infra/ansible/roles/openfortivpn/files/hosts/goldendragon/*`                 | partial overlap  | Ansible `openfortivpn` role                                                                | stop treating host files as a live source and eventually delete or archive the legacy reference copy                                          |
| NetBird capability                                | legacy host setup NetBird paths                                                                                                                        | `infra/ansible/roles/netbird/*`                                                                                     | partial overlap  | Ansible `netbird` role                                                                     | retire host setup logic and finish any host-specific DNS or routing parity that still lives outside the role                                  |
| declared system service enablement                | `scripts/install/setup/system-services.sh`, `hosts/<host>/setup.sh`                                                                                    | owning Ansible roles (`iwd`, `networkmanager`, `acpi_wakeup`, `power_sleep`, `asus_laptop`, `tlp`, `resolved`, …)    | partial overlap  | owning Ansible role                                                                        | do not port legacy opportunistic service detection; add explicit capabilities before owning generic Bluetooth, CUPS, Docker, or power-profile services |
| timezone policy                                   | `scripts/install/first-run.sh`                                                                                                                         | `infra/ansible/roles/base/tasks/configure.yml`                                                                      | partial overlap  | Ansible `base` role                                                                        | set real per-host timezone vars and stop relying on first-run mutation for managed hosts                                                      |
| secrets flow                                      | `scripts/utilities/secrets.sh`, `install.sh` secrets setup                                                                                             | no new-system replacement yet                                                                                       | migration seam   | explicit product decision required                                                         | choose out-of-band secrets, Ansible Vault, or chezmoi-backed secret rendering and document it                                                 |
| host-specific hardware and service extras         | `hosts/dragon/setup.sh`, `hosts/firedragon/setup.sh`, `hosts/goldendragon/setup.sh`, assorted `hosts/*/etc/**`                                         | only partially represented in current roles                                                                         | migration seam   | explicit role ownership, chezmoi for `$HOME` only                                          | port remaining host `/etc`, service, and hardware slices into explicit roles or mark them as intentional exceptions                           |


### Proposed ownership hypotheses (PENDING, not approval)

These are candidate boundaries to reconcile; they must not be treated as
approved policy until the named decision and later proof gates pass:

- proposed: Ansible owns system packages.
- proposed: Ansible owns `/etc`.
- proposed: Ansible owns system services and service enablement.
- proposed: chezmoi owns static user-state under `$HOME`.
- proposed: host trees under `hosts/<host>/etc/` and `hosts/<host>/dotfiles/` are payload sources when referenced by Ansible roles or chezmoi manifests; they are not runtime writers.
- proposed: host setup scripts are not the long-term runtime owner of a feature that already has an Ansible role or chezmoi manifest.

### Canonical-owner decisions that still need explicit resolution

These still need a hard decision before the repo can claim a full pivot:

- whether fingerprint watchdog is system-owned by Ansible or user-owned by chezmoi
- whether PipeWire host audio drop-ins are system-owned by Ansible or intentionally left outside the parity target
- whether `battery-status` and similar host helper binaries are chezmoi-owned user state or intentionally retired
- whether generic desktop service enablement for Bluetooth, CUPS, Docker, and non-TLP `power-profiles-daemon` should become explicit inventory capabilities
- whether user systemd enablement from `scripts/install/setup/user-services.sh` becomes chezmoi-owned user state or remains runtime/user-session setup outside Ansible
- whether secure boot, NetBird, AIO cooler, ASUS laptop behavior, and other host-specific capabilities become first-class roles or remain documented exceptions
- whether secrets stay outside the new control plane or become a first-class part of it

## Pivot plan to reach 100% ownership clarity

The repo is not fully pivoted while unreferenced legacy host-tree payloads or shell writers remain ambiguous.

The repo is fully pivoted only when:

1. a concern has one canonical runtime owner
2. the implementation source lives under that owner's declared payload model (`infra/ansible`, `infra/chezmoi`, or an explicitly referenced `hosts/<host>` payload)
3. unreferenced legacy host paths are demoted to reference-only or deleted
4. parity validation proves the new owner without calling the legacy path

No real-host validation or bringup is allowed before that standard is met for the relevant host and its required capabilities.

### Required pivot stages

#### Stage 1. Stop dual writers

- stop `install.sh`, `scripts/install/*`, and `hosts/<host>/setup.sh` from mutating any path already claimed by an Ansible role
- stop system Stow from owning `sddm`, `polkit`, or any other `/etc` concern that now belongs to Ansible
- stop Stow from owning any `$HOME` subtree once it has been cut over to chezmoi on a managed host

Current progress:

- `install.sh` now supports explicit control-plane gating through `DOTFILES_SYSTEM_OWNER=ansible` and `DOTFILES_USER_OWNER=chezmoi`
- the legacy system writers now skip when `DOTFILES_SYSTEM_OWNER=ansible`: system Stow, host `setup.sh`, legacy SDDM theme writes, `scripts/install/system-config.sh`, and setup-orchestration power/service scripts
- the legacy user writers now skip when `DOTFILES_USER_OWNER=chezmoi`: package Stow, host-dotfile Stow, and the Hyprland restow path inside `scripts/install/setup/user-services.sh`
- this is an execution gate, not full retirement yet: the legacy sources still exist and broader parity validation still needs to prove the managed path without fallback

#### Stage 2. Stop sourcing runtime files from legacy host trees

- move role-managed file payloads out of `hosts/<host>/etc/**` and into role `files/` or `templates/`
- move role-managed helper binaries out of `hosts/<host>/dotfiles/**` when they are actually system-owned artifacts
- keep legacy files only as migration references until the role-local source exists

Current progress:

- `resolved`, `v4l2loopback`, `iwd`, and `networkmanager` now source their Batch-2/3 managed payloads from role-local `files/` paths
- `fingerprint`, `tlp`, `openfortivpn`, `nvidia`, `amd_gpu`, `power_sleep`, and `acpi_wakeup` have explicit Ansible runtime owners, but still source some managed payloads from legacy host trees
- moving the remaining role-owned payloads into role-local `files/` or `templates/` remains required before calling those concerns fully pivoted under the definition below

Batch-9 progress:

- explicit Ansible runtime owner exists for the firedragon ASUS laptop edge stack via `roles/asus_laptop`
- some ASUS laptop payloads are role-local; the NetworkManager dispatcher, lid/sleep drop-ins, system-sleep hooks, and AX210 udev rule still need a later payload-source pivot

Batch-11 progress:

- completed for firedragon hibernation and resume plumbing via `roles/hibernation`
- retired the direct dependency on `hosts/firedragon/enable-sleep-hibernate.sh` by moving swap, resume, mkinitcpio, and Limine state under explicit Ansible ownership

Batch-12 progress:

- retired `hosts/firedragon/fix-acpi-boot.sh` because ASUS ACPI boot parameters are already owned by `roles/asus_laptop`
- retired `hosts/firedragon/fix-lid-close-freeze.sh` because its mutation surface is now split across `roles/amd_gpu`, `roles/asus_laptop`, `roles/tlp`, and `roles/hibernation`
- ported `hosts/firedragon/verify-suspend-fix.sh` into the disposable validation lane as `tests/vm/proxmox-validation/firedragon-suspend-verify.sh`

#### Stage 3. Close capability gaps

- finish real-host parity verification for the `netbird` role
- add explicit owners for secure boot and remaining laptop/runtime PM surfaces if they are part of parity
- decide and implement ownership for fingerprint watchdog and other still-unowned host behavior

Current progress:

- `asus_laptop` is now the explicit Ansible owner of the firedragon NetworkManager dispatcher, lid/sleep policy, system-sleep hooks, and AX210 Bluetooth udev behavior
- `hibernation` is now the explicit Ansible owner of firedragon swap, resume, mkinitcpio, and Limine hibernate plumbing
- the old firedragon ACPI and lid-close repair mutators are now retired in favor of explicit role ownership plus disposable-lane validation
- `iwd`, `networkmanager`, `acpi_wakeup`, and `power_sleep` now own their declared Batch-3 service enablement for goldendragon
- remaining capability gaps still include secure boot, fingerprint watchdog, generic desktop services, and user helper ownership decisions such as `kbd-backlight`

#### Stage 4. Finish chezmoi expansion

- expand manifests beyond the current session slice
- absorb host zsh overlays and other host-specific user-state under chezmoi
- keep runtime-generated files explicitly excluded until their owner changes

Current progress:

- default chezmoi builds now include `session-zsh.manifest` alongside `session-core.manifest` and `session-shell.manifest`
- the default cutover target now covers `.zshrc`, `.zshenv`, `.config/zsh/**`, and host zsh overlays/functions
- runtime-generated theme files remain explicitly excluded; zsh currently has no additional generated-file carve-outs beyond the existing Stow cutover model

#### Stage 5. Replace legacy validation with parity validation

- express host expectations from inventory and capabilities, not from `.traits` or shell heuristics
- add a new-system parity gate that proves host bringup without `hosts/<host>/setup.sh`
- require that any claimed parity-complete host passes only through Ansible + chezmoi paths

Gate policy:

- do not validate against any real host until the host catalog is complete and the relevant host is marked parity-complete
- do not attempt any real-host bringup until the parity-complete state has also been proven on the disposable VM lanes
- disposable Debian, Arch, and graphical validation are prerequisites, not substitutes for parity completion

### Practical definition of a full pivot

Do not call a concern fully pivoted until all of the following are true:

1. the canonical owner is explicitly documented
2. there is no second runtime writer for the same path or behavior
3. the new owner no longer sources its payload from a legacy host tree
4. validation proves the new owner in practice
5. the legacy path is either deleted or explicitly documented as reference-only

Until all five are true for a host, that host remains blocked from real-host validation and bringup.

## Host Catalog

## `dragon`

### Legacy host sources on `main`

Host-specific sources:

- `hosts/dragon/.traits`
- `hosts/dragon/.hyprland`
- `hosts/dragon/README.md`
- `hosts/dragon/docs/AMD_WORKSTATION.md`
- `hosts/dragon/setup.sh`
- `hosts/dragon/verify-workstation.sh`
- `hosts/dragon/dynamic_led.py`
- `hosts/dragon/dynamic_led.service`
- `hosts/dragon/liquidctl-dragon.service`
- `hosts/dragon/etc/systemd/logind.conf.d/dragon-power.conf`
- `hosts/dragon/etc/systemd/sleep.conf.d/dragon-sleep.conf`
- `hosts/dragon/etc/systemd/system-sleep/liquidctl-suspend.sh`
- `hosts/dragon/etc/polkit-1/rules.d/90-corectrl.rules`
- `hosts/dragon/etc/modprobe.d/amdgpu-dragon.conf`
- `hosts/dragon/pipewire/20-stereo-audient.conf`
- `hosts/dragon/pipewire/90-audient-defaults.conf`
- `hosts/dragon/pipewire/README.md`
- `hosts/dragon/dotfiles/.config/zsh/hosts/dragon.zsh`
- `hosts/dragon/dotfiles/.config/zsh/functions/dragon.zsh`

Related legacy shared sources:

- `scripts/install/deps.manifest.toml`
- `scripts/utilities/audio-setup.sh`
- `scripts/install/validate.sh`

### Current new-architecture mapping

Inventory and host vars:

- `infra/ansible/inventory/hosts.yml`
- `infra/ansible/inventory/host_vars/dragon.yml`

Roles currently applied to `dragon`:

- `common`
- `base`
- `packages`
- `users`
- `sddm`
- `hyprland`
- `amd_gpu`
- `aio-cooler`
- `resolved`
- `netbird`
- `v4l2loopback`
- `power_sleep`

Chezmoi:

- no committed `dragon`-specific generated tree
- host zsh overlays are now covered by `session-zsh.manifest`

### Repository paths observed (not proof of coverage)

- resolved DNS via `roles/resolved` and role-local `roles/resolved/files/hosts/dragon/`
- AMD GPU core role coverage via `roles/amd_gpu`
- CoreCtrl polkit rule copied from legacy root by `roles/amd_gpu`
- AIO cooler services and resume hook via `roles/aio-cooler`
- v4l2loopback pending AUR package plus role-local modprobe and modules-load state via `roles/packages` and `roles/v4l2loopback`
- `etc/systemd/logind.conf.d/dragon-power.conf` via `roles/power_sleep`
- `etc/systemd/sleep.conf.d/dragon-sleep.conf` via `roles/power_sleep`
- desktop user account and admin group via `roles/users`
- desktop session substrate via `roles/sddm` and `roles/hyprland`

### Missing or only partially represented

- PipeWire host audio drop-ins under `hosts/dragon/pipewire/`
- live NetBird convergence proof on `dragon`
- generic desktop service enablement from `system-services.sh` still needs explicit capability decisions for Bluetooth, CUPS, Docker, and `power-profiles-daemon`

### `dragon` parity checklist

- decide whether PipeWire host audio stays script-owned or moves to chezmoi
- verify the `netbird` role against real Dragon behavior; legacy setup now skips NetBird
- decide whether generic desktop services become explicit role-owned capabilities for `dragon`

## `firedragon`

### Legacy host sources on `main`

Host-specific sources:

- `hosts/firedragon/.traits`
- `hosts/firedragon/.hyprland`
- `hosts/firedragon/README.md`
- `hosts/firedragon/setup.sh`
- `hosts/firedragon/enable-sleep-hibernate.sh` (retired by `roles/hibernation`)
- `hosts/firedragon/fix-acpi-boot.sh` (retired stub; boot parameters owned by `roles/asus_laptop`)
- `hosts/firedragon/fix-lid-close-freeze.sh` (retired stub; behavior split across Ansible roles)
- `hosts/firedragon/verify-suspend-fix.sh` (compatibility shim to disposable validation probe)
- `hosts/firedragon/dotfiles/.config/zsh/hosts/firedragon.zsh`
- `hosts/firedragon/dotfiles/.config/zsh/functions/firedragon.zsh`
- `hosts/firedragon/etc/limine-entry-tool.d/10-amdgpu.conf`
- `hosts/firedragon/etc/modprobe.d/amdgpu.conf`
- `hosts/firedragon/etc/NetworkManager/dispatcher.d/50-home-dns`
- `hosts/firedragon/etc/systemd/logind.conf.d/10-firedragon-lid.conf`
- `hosts/firedragon/etc/systemd/sleep.conf.d/10-firedragon-sleep.conf`
- `hosts/firedragon/etc/systemd/system/amdgpu-console-restore.service`
- `hosts/firedragon/etc/systemd/system/amdgpu-resume.service`
- `hosts/firedragon/etc/systemd/system/amdgpu-suspend.service`
- `hosts/firedragon/etc/systemd/system-sleep/98-ax210-bt-recover.sh`
- `hosts/firedragon/etc/systemd/system-sleep/99-runtime-pm.sh`
- `hosts/firedragon/etc/tlp.d/01-firedragon.conf`
- `hosts/firedragon/etc/udev/rules.d/99-intel-ax210-btusb-power.rules`
- `hosts/firedragon/docs/ADVANCED_GESTURES.md`
- `hosts/firedragon/docs/ASUS_VIVOBOOK_FEATURES.md`
- `hosts/firedragon/docs/GESTURES_QUICKSTART.md`
- `hosts/firedragon/docs/LID_CLOSE_FREEZE_FIX.md`
- `hosts/firedragon/docs/LIMINE_SETUP.md`
- `hosts/firedragon/docs/SUSPEND_RESUME_COMPLETE_FIX.md`

Related legacy shared sources:

- `scripts/install/deps.manifest.toml`
- `scripts/install/validate.sh`
- `packages/hyprland/.config/hypr/config/gestures.conf`

### Current new-architecture mapping

Inventory and host vars:

- `infra/ansible/inventory/hosts.yml`
- `infra/ansible/inventory/host_vars/firedragon.yml`

Roles currently applied to `firedragon`:

- `common`
- `base`
- `packages`
- `users`
- `sddm`
- `hyprland`
- `amd_gpu`
- `tlp`
- `asus_laptop`
- `hibernation`
- `resolved`
- `netbird`

Chezmoi:

- no committed `firedragon`-specific generated tree
- host zsh overlays are now covered by `session-zsh.manifest`

### Repository paths observed (not proof of coverage)

- `etc/tlp.d/01-firedragon.conf` via `roles/tlp`
- `etc/modprobe.d/amdgpu.conf` via `roles/amd_gpu`
- `etc/systemd/system/amdgpu-*.service` via `roles/amd_gpu`
- `etc/limine-entry-tool.d/10-amdgpu.conf` via `roles/amd_gpu`
- `etc/NetworkManager/dispatcher.d/50-home-dns` via `roles/asus_laptop`
- `etc/systemd/logind.conf.d/10-firedragon-lid.conf` via `roles/asus_laptop`
- `etc/systemd/sleep.conf.d/10-firedragon-sleep.conf` via `roles/asus_laptop`
- `etc/systemd/system-sleep/98-ax210-bt-recover.sh` via `roles/asus_laptop`
- `etc/systemd/system-sleep/99-runtime-pm.sh` via `roles/asus_laptop`
- `etc/udev/rules.d/99-intel-ax210-btusb-power.rules` via `roles/asus_laptop`
- `etc/modprobe.d/asus-vivobook.conf` via `roles/asus_laptop`
- `etc/modules-load.d/asus.conf` via `roles/asus_laptop`
- `etc/udev/rules.d/90-asus-kbd-backlight.rules` via `roles/asus_laptop`
- ASUS ACPI kernel parameters via `roles/asus_laptop`
- firedragon laptop package parity from `setup_firedragon_packages()` via manifest-backed `roles/packages`
- ASUS platform services via `roles/asus_laptop`
- hibernation and swap/resume plumbing from `enable-sleep-hibernate.sh` via `roles/hibernation`
- `etc/systemd/resolved.conf.d/dns.conf` via `roles/resolved` and role-local `roles/resolved/files/hosts/firedragon/`
- NetBird installation and service ownership via `roles/netbird`
- Hyprland and SDDM session substrate via `roles/hyprland` and `roles/sddm`

### Missing or only partially represented

- NetBird DNS integration behavior beyond the dispatcher/resolved edge stack
- generic CUPS and Docker service enablement from `system-services.sh` still needs explicit capability decisions
- user `kbd-backlight` helper still lives outside chezmoi and explicit user-state ownership

### `firedragon` parity checklist

- keep `roles/packages`, `roles/amd_gpu`, and `roles/asus_laptop` aligned with the firedragon package contract
- preserve firedragon DNS integration behavior around NetBird while retiring the legacy installer path
- keep the retired ACPI repair stubs reference-only while validating the Ansible-owned behavior through the disposable firedragon probe
- decide whether generic desktop services become explicit role-owned capabilities for `firedragon`
- decide whether `kbd-backlight` becomes chezmoi-owned user state or is intentionally retired

## `goldendragon`

### Legacy host sources on `main`

Host-specific sources:

- `hosts/goldendragon/.hyprland`
- `hosts/goldendragon/.traits`
- `hosts/goldendragon/.local/bin/fprintd-watchdog`
- `hosts/goldendragon/setup.sh`
- `hosts/goldendragon/docs/FINGERPRINT.md`
- `hosts/goldendragon/docs/SECURE_BOOT.md`
- `hosts/goldendragon/docs/SHUTDOWN_REBOOT_ISSUE.md`
- `hosts/goldendragon/dotfiles/.config/waybar-hosts/goldendragon/vpn-enabled`
- `hosts/goldendragon/dotfiles/.config/zsh/functions/goldendragon.zsh`
- `hosts/goldendragon/dotfiles/.config/zsh/hosts/goldendragon.zsh`
- `hosts/goldendragon/dotfiles/.local/bin/avular-vpn-dns`
- `hosts/goldendragon/etc/acpi/disable-wakeup.sh`
- `hosts/goldendragon/etc/modprobe.d/nvidia.conf`
- `hosts/goldendragon/etc/modprobe.d/nvidia-drm.conf`
- `hosts/goldendragon/etc/pam.d/hyprlock`
- `hosts/goldendragon/etc/pam.d/polkit-1`
- `hosts/goldendragon/etc/systemd/logind.conf.d/10-goldendragon-lid.conf`
- `hosts/goldendragon/etc/systemd/sleep.conf.d/10-goldendragon-sleep.conf`
- `hosts/goldendragon/etc/systemd/system/disable-acpi-wakeup.service`
- `hosts/goldendragon/etc/systemd/system/openfortivpn-cleanup.service`
- `hosts/goldendragon/etc/systemd/system/openfortivpn.service`
- `hosts/goldendragon/etc/systemd/system-sleep/99-fprintd-reset.sh`
- `hosts/goldendragon/etc/systemd/user/fprintd-watchdog.service`
- `hosts/goldendragon/etc/systemd/user/fprintd-watchdog.timer`
- `hosts/goldendragon/etc/tlp.d/01-goldendragon.conf`
- `hosts/goldendragon/etc/udev/rules.d/99-fingerprint-no-autosuspend.rules`
- `hosts/goldendragon/scripts/diagnostics/diagnose-both-issues.sh`
- `hosts/goldendragon/scripts/diagnostics/verify-nvidia.sh`
- `hosts/goldendragon/scripts/fingerprint/install-fprintd-watchdog.sh`
- `hosts/goldendragon/scripts/fingerprint/restart-fprintd.sh`
- `hosts/goldendragon/scripts/secure-boot/setup-secure-boot.sh`

### Current new-architecture mapping

Inventory and host vars:

- `infra/ansible/inventory/hosts.yml`
- `infra/ansible/inventory/host_vars/goldendragon.yml`

Roles currently applied to `goldendragon`:

- `common`
- `base`
- `packages`
- `users`
- `sddm`
- `hyprland`
- `fingerprint`
- `nvidia`
- `tlp`
- `resolved`
- `intel_gpu`
- `openfortivpn`
- `v4l2loopback`
- `power_sleep`
- `iwd`
- `networkmanager`
- `acpi_wakeup`

Chezmoi:

- current manifests can include `hosts/goldendragon/dotfiles/.config/waybar-hosts/goldendragon/`
- host zsh overlays are now covered by `session-zsh.manifest`

### Repository paths observed (not proof of coverage)

- `etc/tlp.d/01-goldendragon.conf` via `roles/tlp`
- `etc/systemd/resolved.conf.d/dns.conf` via `roles/resolved` and role-local `roles/resolved/files/hosts/goldendragon/`
- `etc/modprobe.d/nvidia.conf` and `nvidia-drm.conf` via `roles/nvidia`
- `nvidia-drm.modeset=1` kernel parameter via `roles/nvidia`
- fingerprint udev and PAM behavior via `roles/fingerprint`
- `etc/pam.d/hyprlock` via `roles/fingerprint`
- OpenFortiVPN service units and `/usr/local/bin/avular-vpn-dns` via `roles/openfortivpn`
- `etc/modprobe.d/v4l2loopback.conf` via role-local `roles/v4l2loopback/files/`
- `etc/modules-load.d/v4l2loopback.conf` via role-local `roles/v4l2loopback/files/`
- `v4l2loopback-dkms` pending AUR package via manifest-backed `roles/packages`
- `etc/systemd/logind.conf.d/10-goldendragon-lid.conf` via `roles/power_sleep`
- `etc/systemd/sleep.conf.d/10-goldendragon-sleep.conf` via `roles/power_sleep`
- `acpid.service` and `thermald.service` via `roles/power_sleep`
- `etc/iwd/main.conf` via role-local `roles/iwd/files/hosts/goldendragon/`
- `iwd.service` via `roles/iwd`
- `etc/NetworkManager/conf.d/10-unmanage-wlan0.conf` via role-local `roles/networkmanager/files/hosts/goldendragon/`
- `NetworkManager.service` via `roles/networkmanager`
- `etc/acpi/disable-wakeup.sh` via `roles/acpi_wakeup`
- `etc/systemd/system/disable-acpi-wakeup.service` via `roles/acpi_wakeup`
- `disable-acpi-wakeup.service` enablement via `roles/acpi_wakeup`
- ACPI wakeup resume reapply via `roles/acpi_wakeup`
- goldendragon laptop package parity from `setup_goldendragon_packages()` via manifest-backed `roles/packages`
- desktop session substrate via `roles/sddm` and `roles/hyprland`

### Missing or only partially represented

- user `fprintd-watchdog` timer/service/binary
- `~/.local/bin/battery-status` behavior created by legacy `setup.sh`
- exact Waybar VPN marker lifecycle for `vpn-enabled`
- secure-boot bringup path is still script-oriented and currently path-fragile
- generic Bluetooth, CUPS, Docker, and non-TLP `power-profiles-daemon` service enablement from `system-services.sh` still needs explicit capability decisions

### `goldendragon` parity checklist

- add fingerprint watchdog ownership to the new architecture
- decide where `battery-status` lives in the new model
- add explicit management or validation for the Waybar VPN marker
- fix the secure-boot script entrypoint so it matches the actual repo path
- decide whether generic desktop services become explicit role-owned capabilities for `goldendragon`

## `microdragon`

### Legacy host sources on `main`

Host-specific sources:

- `hosts/microdragon/setup.sh`

Related legacy shared sources:

- `scripts/lib/install-state.sh`
- `install.sh`

There are no tracked legacy host files for:

- `hosts/microdragon/.traits`
- `hosts/microdragon/etc/`
- `hosts/microdragon/dotfiles/`

### Current new-architecture mapping

Inventory and host vars:

- `infra/ansible/inventory/hosts.yml`
- `infra/ansible/inventory/host_vars/microdragon.yml`

Roles currently applied to `microdragon`:

- `common`
- `base`
- `packages`
- `users`
- `netbird`

Chezmoi:

- no host dotfiles source exists
- no current chezmoi slice targets `microdragon`

### Repository paths observed (not proof of coverage)

- Debian server identity via inventory and host vars
- base user management via `roles/users`
- baseline package/profile bringup via `roles/packages`
- non-Hyprland server posture via inventory grouping

### Missing or only partially represented

- NetBird parity verification on Debian beyond the new role contract
- any host-specific user-state
- legacy Debian setup mismatch has been superseded by the Ansible `netbird` role, but still needs real-host proof

### `microdragon` parity checklist

- verify the new `netbird` role against real Debian behavior on `microdragon`
- keep legacy setup's NetBird skip until the setup script is fully retired
- decide whether `microdragon` should gain a `.traits` file and/or host dotfiles source

## Inventory extensions

The two inventory hosts that were absent from the historical four-host
catalog are baseline rows, not silent approvals:

### `opencode-runtime`

- source: `hosts/opencode-runtime/setup.sh`, `hosts/opencode-runtime/.traits`
- current selectors: `debian`, `server`, `ansible_connection: local`,
  `managed_users: coder`
- proposed producer: `infra/ansible/playbooks/site.yml` with an explicit
  local-runtime target contract
- proposed writer: Ansible system state; chezmoi only after target binding
- proposed verifier: `leaf-1.6.7`, then `leaf-1.7.5`
- recovery owner: opencode-runtime operator with local container/host recovery
- pending decision: **PENDING — leaf-1.1.2** must confirm release,
  architecture, target, user and home binding

### `ubuntu-mobile-dev`

- source: `hosts/ubuntu-mobile-dev/**` is referenced by inventory but absent
  from this repository snapshot; live absence is unknown
- current selectors: `debian`, `desktop`, `hyprland`, `sddm`, managed user
  `ubuntu`
- proposed producer: `infra/ansible/playbooks/site.yml` with Ubuntu-specific
  providers
- proposed writer: Ansible system state and selected chezmoi user state
- proposed verifier: `leaf-1.6.8`, then `leaf-1.7.6`
- recovery owner: ubuntu-mobile-dev operator with physical/console recovery
- pending decision: **PENDING — leaf-1.1.2** must confirm exact Ubuntu release,
  architecture and package/session boundary

## Host/profile capability ownership matrix

Each comma-separated capability ID below is a separate host/profile
relationship. The ownership tuple on that row applies to every listed ID;
the capability-specific proposed tuple and source list are in
`gates/contract/baseline.json`. No row is approved.

| Host/profile | Capability IDs | Proposed producer | Proposed writer | Proposed verifier | Recovery owner | Pending decision |
|---|---|---|---|---|---|---|
| `dragon` | `baseline-system`, `platform-arch`, `profile-desktop`, `desktop-hyprland`, `desktop-sddm`, `desktop-session-stack`, `desktop-audio-services`, `desktop-visual-integration`, `package-core-cli`, `package-development`, `package-host`, `package-fonts`, `package-aur`, `package-vendor`, `package-runtimes`, `optional-gui`, `optional-sharing`, `optional-creative`, `optional-gaming`, `optional-input`, `user-static`, `user-devtools`, `user-git-ssh`, `user-zsh`, `gpu-amd`, `hardware-aio`, `hardware-v4l2loopback`, `power-sleep`, `network-netbird`, `network-resolved`, `boot-plymouth`, `boot-parameters`, `firewall-polkit`, `sddm-ownership`, `source-encoding`, `source-sync`, `source-target`, `source-migration`, `source-cutover`, `generated-state`, `theme-runtime`, `secrets`, `pkgsolve`, `validation-ci`, `validation-idempotency` | `infra/ansible/playbooks/site.yml plus the capability-specific producer in capabilities` | `Ansible system writer plus selected chezmoi/runtime writers after decisions` | `leaf-1.6.3 qualification and leaf-1.7.1 cutover evidence` | `dragon cutover operator with physical/console recovery` | `leaf-1.1.2` |
| `firedragon` | `baseline-system`, `platform-arch`, `profile-desktop`, `profile-laptop`, `desktop-hyprland`, `desktop-sddm`, `desktop-session-stack`, `desktop-audio-services`, `desktop-visual-integration`, `package-core-cli`, `package-development`, `package-host`, `package-fonts`, `package-aur`, `package-vendor`, `package-runtimes`, `optional-gui`, `optional-sharing`, `optional-creative`, `optional-gaming`, `optional-input`, `user-static`, `user-devtools`, `user-git-ssh`, `user-zsh`, `gpu-amd`, `hardware-asus`, `power-tlp`, `power-hibernation`, `network-netbird`, `network-resolved`, `boot-plymouth`, `boot-parameters`, `firewall-polkit`, `sddm-ownership`, `source-encoding`, `source-sync`, `source-target`, `source-migration`, `source-cutover`, `generated-state`, `theme-runtime`, `secrets`, `pkgsolve`, `validation-ci`, `validation-idempotency` | `infra/ansible/playbooks/site.yml plus the capability-specific producer in capabilities` | `Ansible system writer plus selected chezmoi/runtime writers after decisions` | `leaf-1.6.4 qualification and leaf-1.7.2 cutover evidence` | `firedragon cutover operator with physical/console recovery` | `leaf-1.1.2` |
| `goldendragon` | `baseline-system`, `platform-arch`, `profile-desktop`, `profile-laptop`, `desktop-hyprland`, `desktop-sddm`, `desktop-session-stack`, `desktop-audio-services`, `desktop-visual-integration`, `package-core-cli`, `package-development`, `package-host`, `package-fonts`, `package-aur`, `package-vendor`, `package-runtimes`, `optional-gui`, `optional-sharing`, `optional-creative`, `optional-gaming`, `optional-input`, `user-static`, `user-devtools`, `user-git-ssh`, `user-zsh`, `user-host-watchdog`, `gpu-intel`, `gpu-nvidia`, `hardware-v4l2loopback`, `power-tlp`, `power-sleep`, `power-acpi`, `auth-fingerprint`, `network-resolved`, `network-iwd`, `network-networkmanager`, `network-fortinet`, `boot-plymouth`, `boot-parameters`, `firewall-polkit`, `sddm-ownership`, `source-encoding`, `source-sync`, `source-target`, `source-migration`, `source-cutover`, `generated-state`, `theme-runtime`, `secrets`, `pkgsolve`, `validation-ci`, `validation-idempotency` | `infra/ansible/playbooks/site.yml plus the capability-specific producer in capabilities` | `Ansible system writer plus selected chezmoi/runtime writers after decisions` | `leaf-1.6.5 qualification and leaf-1.7.3 cutover evidence` | `goldendragon cutover operator with physical/console recovery` | `leaf-1.1.2` |
| `microdragon` | `baseline-system`, `platform-debian`, `profile-server`, `package-core-cli`, `package-runtimes`, `user-static`, `user-devtools`, `user-git-ssh`, `user-zsh`, `network-netbird`, `boot-plymouth`, `boot-parameters`, `firewall-polkit`, `source-encoding`, `source-sync`, `source-target`, `source-migration`, `source-cutover`, `secrets`, `pkgsolve`, `validation-ci`, `validation-idempotency` | `infra/ansible/playbooks/site.yml plus the capability-specific producer in capabilities` | `Ansible server writer plus selected chezmoi/runtime writers after decisions` | `leaf-1.6.6 qualification and leaf-1.7.4 cutover evidence` | `microdragon cutover operator with console recovery` | `leaf-1.1.2` |
| `opencode-runtime` | `baseline-system`, `platform-debian`, `profile-server`, `package-core-cli`, `package-runtimes`, `user-static`, `user-devtools`, `user-git-ssh`, `user-zsh`, `boot-plymouth`, `boot-parameters`, `firewall-polkit`, `source-encoding`, `source-sync`, `source-target`, `source-migration`, `source-cutover`, `secrets`, `pkgsolve`, `validation-ci`, `validation-idempotency` | `infra/ansible/playbooks/site.yml with explicit local-runtime target binding` | `Ansible local-runtime writer plus chezmoi only after target resolution` | `leaf-1.6.7 qualification and leaf-1.7.5 cutover evidence` | `opencode-runtime operator with local container/host recovery` | `leaf-1.1.2` |
| `ubuntu-mobile-dev` | `baseline-system`, `platform-debian`, `profile-desktop`, `desktop-hyprland`, `desktop-sddm`, `desktop-session-stack`, `desktop-audio-services`, `desktop-visual-integration`, `package-core-cli`, `package-development`, `package-fonts`, `package-runtimes`, `optional-gui`, `optional-sharing`, `optional-creative`, `optional-gaming`, `optional-input`, `user-static`, `user-devtools`, `user-git-ssh`, `user-zsh`, `boot-plymouth`, `boot-parameters`, `firewall-polkit`, `sddm-ownership`, `source-encoding`, `source-sync`, `source-target`, `source-migration`, `source-cutover`, `generated-state`, `theme-runtime`, `secrets`, `pkgsolve`, `validation-ci`, `validation-idempotency` | `infra/ansible/playbooks/site.yml plus Ubuntu-specific package/session providers` | `Ansible system writer plus selected chezmoi/runtime writers after decisions` | `leaf-1.6.8 qualification and leaf-1.7.6 cutover evidence` | `ubuntu-mobile-dev operator with physical/console recovery` | `leaf-1.1.2` |
| `generic-desktop` | `generic-desktop`, `profile-desktop`, `desktop-hyprland`, `desktop-sddm`, `desktop-session-stack`, `desktop-audio-services`, `desktop-visual-integration`, `package-core-cli`, `package-fonts`, `package-aur`, `package-vendor`, `optional-gui`, `optional-sharing`, `optional-creative`, `optional-gaming`, `optional-input`, `user-static`, `user-devtools`, `user-git-ssh`, `user-zsh`, `boot-plymouth`, `boot-parameters`, `firewall-polkit`, `sddm-ownership`, `source-encoding`, `source-sync`, `source-target`, `source-migration`, `source-cutover`, `generated-state`, `theme-runtime`, `secrets`, `pkgsolve`, `validation-ci`, `validation-idempotency` | `leaf-1.1.4-selected generic desktop composition` | `install-selected Ansible/chezmoi composition` | `leaf-1.7.14 generic desktop final acceptance` | `generic desktop maintainer with disposable recovery procedure` | `leaf-1.1.4` |
| `generic-headless` | `generic-headless`, `profile-server`, `package-core-cli`, `package-runtimes`, `user-static`, `user-devtools`, `user-git-ssh`, `user-zsh`, `boot-plymouth`, `boot-parameters`, `firewall-polkit`, `source-encoding`, `source-sync`, `source-target`, `source-migration`, `source-cutover`, `secrets`, `pkgsolve`, `validation-ci`, `validation-idempotency` | `leaf-1.1.4-selected generic headless composition` | `install-selected Ansible composition` | `leaf-1.7.15 generic headless final acceptance` | `generic headless maintainer with disposable recovery procedure` | `leaf-1.1.4` |

## Source inventory mapping and evidence boundaries

The following IDs and categories are the complete source inventory. Paths and
ownership tuples are authoritative in `gates/contract/baseline.json`; this
table is the catalog cross-check, not a second source list.

| Source ID | Category | Repository paths | Pending owner |
|---|---|---|---|
| `inventory-and-host-vars` | platform | `infra/ansible/inventory/hosts.yml`, `infra/ansible/inventory/group_vars/*`, `infra/ansible/inventory/host_vars/*` | `leaf-1.1.2` |
| `legacy-host-dragon` | source | `hosts/dragon/**` | `leaf-1.1.6` |
| `legacy-host-firedragon` | source | `hosts/firedragon/**` | `leaf-1.1.6` |
| `legacy-host-goldendragon` | source | `hosts/goldendragon/**` | `leaf-1.1.6` |
| `legacy-host-microdragon` | source | `hosts/microdragon/setup.sh` | `leaf-1.1.6` |
| `legacy-host-opencode-runtime` | platform | `hosts/opencode-runtime/setup.sh`, `hosts/opencode-runtime/.traits` | `leaf-1.1.2` |
| `legacy-host-ubuntu-mobile-dev` | platform | `hosts/ubuntu-mobile-dev/**` *(intentionally missing in this checkout)* | `leaf-1.1.2` |
| `generic-profile-sources` | generic | `hosts/desktop/**`, `hosts/headless/**` | `leaf-1.1.4` |
| `package-manifest` | package | `scripts/install/deps.manifest.toml`, `scripts/install/export-package-plan.sh`, `scripts/install/install-deps.sh` | `leaf-1.1.5` |
| `ansible-role-sources` | package | `infra/ansible/roles/common`, `infra/ansible/roles/base`, `infra/ansible/roles/packages`, `infra/ansible/roles/users`, and the listed role paths in the baseline | `leaf-1.1.5` |
| `chezmoi-source-slices` | source | `infra/chezmoi/manifests/*`, `infra/chezmoi/bin/chezmoi-sync`, `infra/chezmoi/.chezmoiignore` | `leaf-1.1.6` |
| `managed-entrypoints` | platform | `install`, `infra/ansible/playbooks/site.yml`, `infra/ansible/run-playbook.sh`, `infra/chezmoi/bin/chezmoi-sync` | `leaf-1.1.2` |
| `legacy-control-plane` | source | `install.sh`, `scripts/install/setup.sh`, `scripts/install/stow-system.sh`, `scripts/install/system-config.sh`, `scripts/install/update.sh`, `scripts/install/setup/*`, `scripts/lib/control-plane-mode.sh` | `leaf-1.1.6` |
| `migration-and-validation-sources` | package | `migrations/**`, `scripts/install/validate.sh`, `infra/validate-parity.sh`, `tests/docker/**`, `scripts/ci/debian-vm-e2e.sh`, `tools/pkgsolve/**` | `leaf-1.1.5` |
| `archived-runbooks` | source | `docs/archive/migration-2026-05/` runbooks listed in the baseline | `leaf-1.1.6` |

The intentional missing path is limited to
`legacy-host-ubuntu-mobile-dev` → `hosts/ubuntu-mobile-dev/**`; the checker
rejects any other missing or unlisted path.

## Cross-host implementation checklist

This is the minimum shared backlog to achieve true 1:1 parity claims.

- reconcile package truth between `scripts/install/deps.manifest.toml` and `infra/ansible/roles/packages/vars/main.yml`
- expand chezmoi manifests beyond the current session slices for remaining host-specific user state outside zsh
- stop legacy shell and Stow paths from writing concerns already claimed by Ansible or chezmoi
- finish moving remaining role-owned file sources out of `hosts/<host>/etc/` and into role-local `files/` or `templates/`
- decide which remaining `hosts/<host>/setup.sh` responsibilities are intentionally staying legacy and which must be ported now
- port unmanaged host `/etc` overlays into explicit role ownership where parity is required
- add parity-oriented validation that proves full host bringup through the new architecture, not only syntax and VM slice tests

## Practical parity rule

Do not call any host 1:1 parity-complete until all three are true:

1. every host-specific file still required for bringup has a declared new owner
2. every host capability in inventory is backed by executable automation or an explicit documented exception
3. the host can be brought up end-to-end without relying on `hosts/<host>/setup.sh` for still-required behavior
