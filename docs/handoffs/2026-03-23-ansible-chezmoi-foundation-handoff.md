# Handoff: Ansible + chezmoi Foundation

## Status

This repository is transitioning to a clean-break architecture:

- Ansible owns system state.
- chezmoi owns user state.
- NixOS is out of scope.
- Initial platform scope is Arch-based and Debian-based systems.
- Target host classes are desktop, laptop, and server.
- Fallback logic is explicitly forbidden in the new architecture.

The implementation sequence is:

1. foundation
2. hot paths
3. edge cases
4. review
5. iterate

## Memory Bank

Project name in memory bank: `dotfiles`

Files initialized and populated:

- `projectbrief.md`
- `productContext.md`
- `systemPatterns.md`
- `techContext.md`
- `activeContext.md`
- `progress.md`

These contain the current architectural decisions, active context, and next milestone.

## Current Local Code Changes

Pending commit at handoff time:

- `hosts/goldendragon/setup.sh`
- `hosts/goldendragon/scripts/fingerprint/install-fprintd-watchdog.sh`

### What changed

`hosts/goldendragon/setup.sh`
- fixes the watchdog installer invocation path
- stops suppressing watchdog installer output
- adds host-local SDDM theme provisioning via `refresh-sddm` and `sddm-set`
- adds an explicit `goldendragon-sddm-theme` install-state step

`hosts/goldendragon/scripts/fingerprint/install-fprintd-watchdog.sh`
- fixes broken relative paths for logging, hook, watchdog binary, and user units
- avoids failing when the user service/timer are already present via Stow-backed paths
- corrects the documented restart helper path

## Root Cause Summary For Recent Goldendragon Failure

The `goldendragon` SDDM issue was not just a fingerprint/watchdog issue.

The concrete failure was:

- `/etc/sddm.conf.d/10-theme.conf` pointed at `catppuccin-mocha-sky-sddm`
- `/usr/share/sddm/themes` was empty

That meant SDDM was configured to load a missing theme.

Why `firedragon` differed:

- `firedragon/setup.sh` already had host-local SDDM theme setup
- `goldendragon/setup.sh` did not

The watchdog installer also had independent pathing defects that prevented clean hook/unit installation.

## New Architecture Decisions

### Ownership boundaries

Ansible must own:

- distro-aware package installation
- `/etc` files
- services
- hardware and host behavior
- desktop/laptop/server composition
- validation of system state

chezmoi must own:

- user dotfiles in `$HOME`
- host/user-specific templating
- secrets-backed user files
- rendered per-machine user config

### Runtime model

The new runtime must not depend on:

- host `setup.sh` orchestration as the primary path
- `.traits` as the source of truth
- Stow as the primary user-config engine
- doc/script parsing for capability detection
- fallback logic or best-effort continuation on core paths

### Target control plane

Expected new structure:

- `infra/ansible/` for inventories, playbooks, roles, vars
- `infra/chezmoi/` for user config source state
- clear ownership docs for role boundaries and host model

## Recommended Immediate Next Work

This should start in the `foundation` phase only.

### 1. Formalize the host model

Define:

- inventory structure
- required host variables
- group taxonomy
- desktop/laptop/server classification
- distro classification
- hardware feature classification

### 2. Define the Ansible role contract

Every role should have:

- declared ownership
- distro support mapping
- explicit variables
- handlers
- validation tasks
- no hidden external assumptions

### 3. Define ownership boundaries between Ansible and chezmoi

Produce a matrix for:

- files
- services
- packages
- user config
- secrets

### 4. Define phase execution

The first-pass playbook graph should align with:

1. foundation
2. hot paths
3. edge cases
4. review
5. iterate

## Strong Warnings

Do not reintroduce:

- compatibility fallbacks
- parallel legacy and new primary runtime paths
- implicit host detection from shell content or docs
- best-effort behavior in core configuration roles

If something is required, declare it explicitly and fail if it is absent.

## Suggested Foundation Deliverables

The next agent should aim to produce:

1. a formal inventory schema
2. a formal Ansible role contract
3. a clear ownership matrix for Ansible vs chezmoi
4. a minimal playbook graph for the foundation phase
5. an initial migration plan from current runtime layout into the new control plane

## Practical Starting Point

The first hot-path roles to model after foundation are likely:

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
- `openfortivpn`

These correspond most directly to the current pain and current host divergence.

## Foundation Batch Progress

The first foundation batch has now been started on branch `feat/ansible-chezmoi-foundation`.

### New control-plane skeleton

Created:

- `infra/ansible/ansible.cfg`
- `infra/ansible/requirements.yml`
- `infra/ansible/inventory/hosts.yml`
- `infra/ansible/inventory/group_vars/all.yml`
- `infra/ansible/inventory/host_vars/dragon.yml`
- `infra/ansible/inventory/host_vars/firedragon.yml`
- `infra/ansible/inventory/host_vars/goldendragon.yml`
- `infra/ansible/inventory/host_vars/microdragon.yml`
- `infra/ansible/playbooks/foundation.yml`
- `infra/ansible/playbooks/site.yml`
- `infra/ansible/roles/common/defaults/main.yml`
- `infra/ansible/roles/common/tasks/main.yml`
- `infra/ansible/roles/common/tasks/contract.yml`
- `infra/ansible/roles/common/tasks/summary.yml`
- `infra/ansible/roles/common/handlers/main.yml`
- `infra/ansible/roles/common/meta/main.yml`
- `infra/ansible/roles/README.md`

### New chezmoi skeleton

Created:

- `infra/chezmoi/README.md`
- `infra/chezmoi/.chezmoiignore`
- `infra/chezmoi/.chezmoitemplates/README.md`

### New architecture docs

Created:

- `docs/architecture/ansible-chezmoi-foundation.md`
- `docs/architecture/host-model.md`
- `docs/architecture/role-contract.md`
- `docs/architecture/migration-phases.md`

### What the foundation batch currently does

- makes current real hosts explicit in inventory
- pins the ownership boundary between Ansible and chezmoi
- defines the required host variable contract
- introduces a shared `common` role that enforces the foundation contract
- establishes the first minimal playbook graph

### Validation completed

- `ReadLints` reported no issues in the new foundation files
- `ansible-playbook -i inventory/hosts.yml playbooks/foundation.yml --syntax-check` passed when run from `infra/ansible/`

### Important note

The repository is currently in a mixed state:

- legacy runtime still exists
- new control-plane skeleton now exists

This is acceptable only during phased migration work on the feature branch. The target runtime must still converge toward the no-fallback Ansible + chezmoi architecture.

## Hot-Path Tranche 1 Progress

Tranche 1 has now been defined and started.

### Tranche 1 scope

Included roles:

- `base`
- `packages`
- `users`

Explicitly deferred:

- `sddm`
- `hyprland`
- `tlp`
- `fingerprint`
- `nvidia`
- `amd_gpu`
- `resolved`
- `openfortivpn`
- chezmoi-driven user-state migration

### New tranche 1 artifacts

Created:

- `infra/ansible/inventory/group_vars/desktop.yml`
- `infra/ansible/inventory/group_vars/laptop.yml`
- `infra/ansible/inventory/group_vars/server.yml`
- `infra/ansible/inventory/group_vars/arch.yml`
- `infra/ansible/inventory/group_vars/debian.yml`
- `infra/ansible/playbooks/hot-path-tranche-1.yml`
- `infra/ansible/roles/base/...`
- `infra/ansible/roles/packages/...`
- `infra/ansible/roles/users/...`
- `docs/architecture/hot-path-tranche-1.md`

Updated:

- host vars for all current explicit hosts now include initial `managed_users`
- `infra/ansible/playbooks/site.yml` now routes through `hot-path-tranche-1.yml`

### What tranche 1 currently does

`base`
- validates base role input
- manages timezone as the first explicit baseline setting

`packages`
- resolves package profiles by platform family
- installs explicit `core_cli` and `dev` profile sets for Arch and Debian families

`users`
- validates declared managed users
- ensures required groups exist
- ensures declared local users exist with the required supplementary groups

### Validation completed

- `ReadLints` reported no issues on the new tranche-1 files
- `ansible-playbook -i inventory/hosts.yml playbooks/hot-path-tranche-1.yml --syntax-check` passed
- `ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check` passed

### Recommended next step

Before starting tranche 2:

1. review package profile contents for correctness by distro family
2. confirm the managed-user model is acceptable across target hosts
3. then start the next hot-path tranche with `sddm` and the adjacent display-stack boundary work

## Tranche 1 Review Updates

The tranche-1 review has now been applied.

### Package-profile corrections

Tranche-1 package sets were tightened to reduce cross-distro drift:

- removed GUI-terminal assumptions from `core_cli`
- removed high-drift packages like `terraform` from tranche 1
- removed fragile Debian assumptions like `eza`
- aligned Debian with safer tranche-1 mappings such as `fd-find` and `lsd`
- kept tranche 1 intentionally smaller and more portable

### Managed-user model corrections

Managed-user scope was reduced to the smallest cross-host baseline:

- Arch-family hosts now use only `wheel`
- Debian-family `microdragon` keeps `sudo`
- display- and container-adjacent groups such as `video` and `docker` were removed from tranche 1

This keeps the user role aligned with the no-drift principle: extra groups should be introduced only when the owning roles exist.

## Hot-Path Tranche 2 Progress

Tranche 2 has now been defined and started.

### Tranche 2 scope

Included role:

- `sddm`

Explicitly deferred:

- `hyprland`
- `fingerprint`
- `nvidia`
- `amd_gpu`
- `tlp`
- `resolved`
- `openfortivpn`
- chezmoi-driven user-state migration

### New tranche 2 artifacts

Created:

- `infra/ansible/playbooks/hot-path-tranche-2.yml`
- `infra/ansible/roles/sddm/...`
- `docs/architecture/hot-path-tranche-2.md`

Updated:

- `infra/ansible/playbooks/site.yml`
- tranche-1 package vars
- host managed-user definitions

### What tranche 2 currently does

`sddm`
- installs SDDM packages by platform family
- installs managed SDDM theme assets from the repository package source
- writes `/etc/sddm.conf.d/10-theme.conf`
- enables and starts the SDDM service
- validates both the active theme config and the selected theme path

### Validation completed

- `ReadLints` reported no issues on the tranche-2 additions
- `ansible-playbook -i inventory/hosts.yml playbooks/hot-path-tranche-1.yml --syntax-check` passed
- `ansible-playbook -i inventory/hosts.yml playbooks/hot-path-tranche-2.yml --syntax-check` passed
- `ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check` passed

### Recommended next step

The clean next move is to begin tranche 3 around the display-session boundary:

1. decide how much of Hyprland-adjacent system ownership belongs outside chezmoi
2. keep PAM/fingerprint separate from SDDM theme/display-manager ownership
3. keep GPU ownership separate from display-manager ownership

## Hot-Path Tranche 3 Progress

Tranche 3 has now been defined and started.

### Tranche 3 scope

Included role:

- `hyprland`

Explicitly deferred:

- `fingerprint`
- `nvidia`
- `amd_gpu`
- `tlp`
- `resolved`
- `openfortivpn`
- chezmoi-driven user-session migration

### New tranche 3 artifacts

Created:

- `infra/ansible/playbooks/hot-path-tranche-3.yml`
- `infra/ansible/roles/hyprland/...`
- `docs/architecture/hot-path-tranche-3.md`

Updated:

- `infra/ansible/playbooks/site.yml`

### What tranche 3 currently does

`hyprland`
- installs the system-level Hyprland session substrate for the current Hyprland fleet
- installs UWSM and desktop-portal packages required for a Hyprland-capable session
- validates required commands and session files such as the Hyprland desktop entry and portal unit
- keeps display-manager ownership pinned to `sddm`

### Tranche 3 ownership boundary

`hyprland` now owns only:

- system-session packages
- UWSM package presence
- Wayland desktop-portal package presence
- validation of the system-level session substrate

`hyprland` explicitly does not own:

- `/etc/sddm.conf.d/*`
- `/etc/pam.d/hyprlock`
- fingerprint services, udev rules, or watchdog units
- GPU drivers, kernel modules, or resume workarounds
- rendered `$HOME` session files such as `~/.config/hypr/**` or `~/.config/waybar/**`

### Implementation rule applied

Tranche 3 was intentionally limited to the current real Hyprland fleet:

- current managed Hyprland hosts are Arch-family
- Debian-family Hyprland enablement is deferred until package-track metadata is explicit in inventory
- no package-track inference was introduced into the role

### Validation completed

- `ReadLints` reported no issues on the tranche-3 additions
- `ansible-playbook -i inventory/hosts.yml playbooks/hot-path-tranche-3.yml --syntax-check` passed
- `ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check` passed

### Recommended next step

The clean next move after tranche 3 is to define the first non-overlapping follow-on contract:

1. `fingerprint` as the sole owner of fprintd, PAM policy, and auth-adjacent system state
2. `nvidia` and `amd_gpu` as the sole owners of GPU-driver and resume behavior
3. future chezmoi user-session rendering for `~/.config/hypr/**`, Waybar, launchers, and host-specific monitor/input layouts

## Hot-Path Tranche 4 Progress

Tranche 4 has now been defined and started.

### Tranche 4 scope

Included roles:

- `fingerprint`
- `nvidia`
- `amd_gpu`

Explicitly deferred:

- `tlp`
- `resolved`
- `openfortivpn`
- user-level fingerprint watchdog units
- chezmoi-driven session rendering for Hyprland, Waybar, launchers, and host-specific user files

### New tranche 4 artifacts

Created:

- `infra/ansible/playbooks/hot-path-tranche-4.yml`
- `infra/ansible/roles/fingerprint/...`
- `infra/ansible/roles/nvidia/...`
- `infra/ansible/roles/amd_gpu/...`
- `docs/architecture/hot-path-tranche-4.md`

Updated:

- `infra/ansible/playbooks/site.yml`

### What tranche 4 currently does

`fingerprint`
- installs `fprintd`, `libfprint`, and `usbutils` for managed fingerprint hosts
- writes the fingerprint USB autosuspend rule from explicit inventory metadata
- installs the suspend/resume reset hook
- manages PAM fingerprint policy for `sudo`, `polkit-1`, `system-local-login`, and `sddm`
- installs host-specific `/etc/pam.d/hyprlock` when fingerprint-backed Hyprland lock auth is required

`nvidia`
- installs proprietary NVIDIA packages for current Arch-family NVIDIA hosts
- fails fast if conflicting `nvidia-open` kernel packages are installed
- installs NVIDIA modprobe files and `/etc/modules-load.d/nvidia.conf`
- persists `nvidia-drm.modeset=1` through the shared bootloader helper

`amd_gpu`
- installs host-specific AMD GPU packages for `dragon` and `firedragon`
- installs AMD modprobe files and `/etc/modules-load.d/amd.conf`
- installs host-specific AMD GPU resume units and CoreCtrl polkit rules when present
- persists `amdgpu.modeset=1` through host drop-ins and the shared bootloader helper

### Tranche 4 ownership boundary

`fingerprint` now owns only:

- fprintd package installation
- fingerprint udev policy
- fingerprint suspend/resume system hook
- PAM fingerprint policy
- host-specific `hyprlock` PAM state for fingerprint-backed lock auth

`fingerprint` explicitly does not own:

- `/etc/sddm.conf.d/*`
- SDDM theme assets
- Hyprland user config
- user-level watchdog timers under `$HOME`
- GPU drivers or GPU resume units

`nvidia` now owns only:

- NVIDIA driver packages
- NVIDIA modprobe state
- NVIDIA modules-load state
- persistent NVIDIA DRM kernel parameter state

`amd_gpu` now owns only:

- AMD GPU driver packages
- AMD modprobe state
- AMD modules-load state
- AMD GPU resume units
- GPU-tool polkit rules
- persistent AMD GPU kernel parameter state

### Implementation rule applied

Tranche 4 was intentionally limited to the current real Arch-family hardware fleet:

- `fingerprint` currently targets `goldendragon`
- `nvidia` currently targets `goldendragon`
- `amd_gpu` currently targets `dragon` and `firedragon`
- no Debian-family fingerprint or GPU path was inferred

### Validation completed

- `ReadLints` reported no issues on the tranche-4 additions
- `ansible-playbook -i inventory/hosts.yml playbooks/hot-path-tranche-4.yml --syntax-check` passed
- `ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check` passed

### Recommended next step

The clean next move after tranche 4 is to finish the remaining hot-path and then enter review:

1. define `tlp`, `resolved`, and `openfortivpn` as the remaining explicit hot-path owners
2. begin the first real chezmoi migration slice for rendered Hyprland and adjacent user-session files
3. run the first ownership-overlap review across tranches 1 through 4 before starting edge-case work

## Hot-Path Tranche 5 Progress

Tranche 5 has now been defined and started.

### Tranche 5 scope

Included roles:

- `tlp`
- `resolved`
- `openfortivpn`

### New tranche 5 artifacts

Created:

- `infra/ansible/playbooks/hot-path-tranche-5.yml`
- `infra/ansible/roles/tlp/...`
- `infra/ansible/roles/resolved/...`
- `infra/ansible/roles/openfortivpn/...`
- `docs/architecture/hot-path-tranche-5.md`

Updated:

- `infra/ansible/inventory/hosts.yml`
- `infra/ansible/playbooks/site.yml`

### What tranche 5 currently does

`tlp`
- installs TLP packages for laptop hosts
- installs host-specific `/etc/tlp.d` configuration
- enables `tlp.service` and `tlp-sleep.service`
- disables conflicting `power-profiles-daemon`
- masks conflicting `systemd-rfkill` units

`resolved`
- installs host-specific `/etc/systemd/resolved.conf.d/dns.conf`
- enables and restarts `systemd-resolved.service`

`openfortivpn`
- installs `openfortivpn`
- ensures the `openfortivpn` system group and operator membership
- seeds `/etc/openfortivpn/config` if absent
- generates `/etc/openfortivpn/waybar.conf`
- installs the Avular DNS helper
- installs `openfortivpn.service` and `openfortivpn-cleanup.service`

### Validation completed

- `ReadLints` reported no issues on the tranche-5 additions
- `ansible-playbook -i inventory/hosts.yml playbooks/hot-path-tranche-5.yml --syntax-check` passed
- `ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check` passed

## First chezmoi Migration Slice

The original mirrored `infra/chezmoi/dot_config/...` approach has been removed.

Current chezmoi direction:

- `packages/` remains the canonical shared user-state source
- `hosts/<host>/dotfiles/` remains the canonical host-specific user-state source
- `infra/chezmoi/` is now orchestration-only
- generated chezmoi source is materialized under `infra/chezmoi/generated/<host>/`

Migration rule documented in `infra/chezmoi/README.md`:

- preserve imported file contents exactly whenever possible
- keep source package contents untouched
- treat generated chezmoi source as rebuildable output, not canonical content

New artifacts for this redesign:

- `docs/architecture/chezmoi-canonical-source-model.md`
- `infra/chezmoi/manifests/session-core.manifest`
- `infra/chezmoi/scripts/build-source.sh`
- `infra/chezmoi/.gitignore`

Validation completed:

- `bash -n infra/chezmoi/scripts/build-source.sh` passed
- `bash infra/chezmoi/scripts/build-source.sh --host goldendragon` generated a host-specific source tree successfully

This is now a real generated-source model, but still not a full ownership cutover of all session files.

## Ownership Review: Tranches 1-4

The first ownership-overlap review across tranches 1 through 4 has been documented in:

- `docs/architecture/ownership-review-tranches-1-4.md`

Current review result:

- no direct ownership violations found in tranche contracts
- residual risk has shifted from Ansible role overlap to the future Stow-to-chezmoi cutover of `$HOME` content

## Generated-source Expansion and Cutover Design

The generated-source model now expands beyond the first session-core slice.

New artifacts:

- `infra/chezmoi/manifests/session-shell.manifest`
- `infra/chezmoi/scripts/verify-generated-source.sh`
- `docs/architecture/chezmoi-cutover-procedure.md`

Updated artifacts:

- `infra/chezmoi/scripts/build-source.sh`
- `infra/chezmoi/README.md`
- `docs/architecture/chezmoi-canonical-source-model.md`

### Current generated slice set

`session-core.manifest`
- `dot_config/hypr`
- `dot_config/waybar`
- `dot_config/walker`
- `dot_config/elephant`
- optional `dot_config/waybar-hosts/<host>`

`session-shell.manifest`
- `dot_config/autostart`
- `dot_config/clipse`
- `dot_config/swaync`
- `dot_config/swayosd`

### Builder and verifier behavior

- `build-source.sh` now composes multiple manifests in order
- the default build includes both `session-core.manifest` and `session-shell.manifest`
- `verify-generated-source.sh` checks that all required generated destinations exist for the selected manifests

### Current cutover guidance

The cutover procedure is now explicitly documented.

The critical current exceptions before real chezmoi ownership are:

- `~/.config/swaync/style.css` is merged runtime output from theme-manager
- `~/.config/clipse/theme.toml` is generated runtime theme state
- legacy setup scripts must stop rewriting migrated paths before Stow ownership is removed

### Validation completed

- `bash -n infra/chezmoi/scripts/build-source.sh` passed
- `bash -n infra/chezmoi/scripts/verify-generated-source.sh` passed
- `bash infra/chezmoi/scripts/build-source.sh --host goldendragon` passed with the default manifest set
- `bash infra/chezmoi/scripts/verify-generated-source.sh --host goldendragon` confirmed all required generated paths exist
- `ReadLints` reported no issues in the updated chezmoi control-plane files
