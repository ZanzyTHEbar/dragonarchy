# Host Bringup Parity Catalog

## Purpose

This document catalogs what is required for full host bringup parity between:

- the legacy architecture on `main`
- the current Ansible + chezmoi architecture on `feat/ansible-chezmoi-foundation`

The goal is not a vague migration summary.

The goal is a host-by-host implementation catalog of:

1. legacy source files and behaviors
2. current new-architecture ownership and coverage
3. exact parity gaps
4. a surgical checklist to reach 1:1 bringup parity

## Comparison basis

The comparison uses these facts:

- `main` has no `infra/` control plane
- host trees under `hosts/dragon`, `hosts/firedragon`, `hosts/goldendragon`, and `hosts/microdragon` are unchanged on this branch
- the current branch adds the new architecture primarily under:
  - `infra/ansible/`
  - `infra/chezmoi/`
  - `infra/packer/`

That means most parity analysis is:

- legacy host tree and shell installer on `main`
- versus additive inventory, roles, manifests, and runbooks on the current branch

## In-scope hosts

Current modeled hosts from `infra/ansible/inventory/hosts.yml`:

- `dragon`
- `firedragon`
- `goldendragon`
- `microdragon`

## Current new-architecture host mapping

### `dragon`

- groups: `arch`, `desktop`, `resolved`, `hyprland`, `amd_gpu`, `netbird`
- host vars: `infra/ansible/inventory/host_vars/dragon.yml`
- capabilities: `aio-cooler`, `netbird`

### `firedragon`

- groups: `arch`, `desktop`, `laptop`, `tlp`, `resolved`, `hyprland`, `amd_gpu`, `netbird`
- host vars: `infra/ansible/inventory/host_vars/firedragon.yml`
- capabilities: `tlp`, `asus`, `netbird`

### `goldendragon`

- groups: `arch`, `desktop`, `laptop`, `tlp`, `resolved`, `hyprland`, `fingerprint`, `nvidia`, `fortinet_vpn`
- host vars: `infra/ansible/inventory/host_vars/goldendragon.yml`
- capabilities: `tlp`, `fingerprint`, `fortinet_vpn`

### `microdragon`

- groups: `debian`, `server`, `netbird`
- host vars: `infra/ansible/inventory/host_vars/microdragon.yml`
- capabilities: `netbird`

## Shared new-architecture ownership

Current role set from `infra/ansible/roles/README.md`:

- `common`
- `base`
- `packages`
- `users`
- `sddm`
- `hyprland`
- `fingerprint`
- `nvidia`
- `amd_gpu`
- `tlp`
- `asus_laptop`
- `resolved`
- `netbird`
- `openfortivpn`

Current chezmoi scope is partial but now covers the first session-oriented slices plus zsh:

- `infra/chezmoi/manifests/session-core.manifest`
- `infra/chezmoi/manifests/session-shell.manifest`
- `infra/chezmoi/manifests/session-zsh.manifest`

Current Packer scope is validation infrastructure, not host bringup ownership:

- `infra/packer/`

## Shared parity gaps

These gaps affect multiple hosts and must be understood before claiming 1:1 parity.

### 1. No replacement for the legacy top-level bringup path

Legacy full bringup still flows through:

- `install.sh`
- `scripts/install/*`
- `hosts/<host>/setup.sh`

The current branch does not replace that with a single new-architecture entrypoint.

Ansible and chezmoi exist, but they are not yet the only bringup path.

### 2. Duplicate package truth

**Closed for Ansible convergence:** `scripts/install/deps.manifest.toml` is canonical. The `packages` role resolves plans via `scripts/install/export-package-plan.sh` (see `docs/architecture/package-manifest-contract.md`). Role-local package lists were removed or emptied where migrated (e.g. `amd_gpu`, `nvidia`, `tlp` stacks; `roles/packages/vars/main.yml` retired).

**Remaining seams (incremental):** some roles still carry install lists for session/UI stacks (`hyprland`, `sddm`, `fingerprint`, `openfortivpn`) until those are folded into manifest-backed groups or host profiles in a later batch.

### 3. NetBird is now role-owned, but not yet parity-complete

Hosts and capability mapping now have a real `roles/netbird`.

That means:

- `dragon`
- `firedragon`
- `microdragon`

all have a canonical system owner for NetBird installation and service state.

The remaining gap is host-specific parity around surrounding behavior:

- `microdragon` routing-peer behavior must stay verified
- `firedragon` still has additional DNS integration behavior outside the basic NetBird role
- legacy host setup scripts still remain as historical/reference paths until they are retired

### 4. Chezmoi does not yet cover full host user-state

Current manifests cover the first session-oriented slices plus zsh overlays.

Remaining gaps are other non-session host dotfiles and user-state that still sits outside the current manifests.

### 5. Validation is still split

Legacy validation remains strong in:

- `scripts/install/validate.sh`

Ansible has syntax checking and role validation tasks, but there is not yet a single parity gate that proves full host bringup only through the new architecture.

## Shared duplicate ownership seams

These are the repo-wide cases where the new architecture is not yet the only meaningful owner.

They matter because parity is not enough if runtime ownership is still ambiguous.

If legacy shell, Stow, or host trees can still write or source the same concern, then the pivot is incomplete even when a new role exists.

### Duplicate ownership matrix


| Domain                                            | Legacy owner paths                                                                                                                                     | Current new owner paths                                                                                             | Conflict type    | Canonical owner                                                                            | Remaining pivot work                                                                                                                          |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| top-level bringup                                 | `install.sh`, `scripts/install/*`, `hosts/<host>/setup.sh`                                                                                             | `infra/ansible/playbooks/*.yml`, `infra/chezmoi/scripts/*.sh`                                                       | migration seam   | Ansible + chezmoi                                                                          | define one supported end-to-end bringup entrypoint and retire mixed-mode operator flow                                                        |
| validation gate                                   | `scripts/install/validate.sh`                                                                                                                          | role `validate.yml` and `verify.yml`, CI syntax checks, VM cutover lane                                             | migration seam   | Ansible/chezmoi parity gate                                                                | map trait checks into inventory/capability-based validation and produce one authoritative parity proof                                        |
| package truth                                     | `scripts/install/deps.manifest.toml`                                                                                                                   | `infra/ansible/roles/packages` (manifest plan consumer) + optional legacy role overrides                                                           | **resolved**     | **`deps.manifest.toml` + `export-package-plan.sh`**                                        | keep thinning role-local lists (`hyprland`, `sddm`, …) into manifest groups                                                                    |
| SDDM theme payload and active theme               | `packages/sddm/**`, `scripts/install/stow-system.sh`, `scripts/theme-manager/refresh-sddm`, `scripts/theme-manager/sddm-set`                           | `infra/ansible/roles/sddm/tasks/configure.yml`                                                                      | partial overlap  | Ansible `sddm` role                                                                        | stop using system Stow and theme-manager as the runtime writer for managed hosts                                                              |
| baseline polkit admin rule                        | `packages/polkit/etc/polkit-1/rules.d/49-wheel-admin.rules`                                                                                            | `infra/ansible/roles/base/tasks/configure.yml`                                                                      | full duplication | Ansible `base` role                                                                        | remove `polkit` from system-Stow bringup for managed hosts                                                                                    |
| fingerprint PAM insertion                         | `hosts/goldendragon/setup.sh`, `hosts/goldendragon/etc/pam.d/*`                                                                                        | `infra/ansible/roles/fingerprint/defaults/main.yml`, `infra/ansible/roles/fingerprint/tasks/configure.yml`          | partial overlap  | Ansible `fingerprint` role                                                                 | stop relying on `setup.sh` edits; own `sudo`, `polkit-1`, `system-local-login`, and `sddm` insertion only through the role                    |
| fingerprint sleep hook and hyprlock PAM           | `hosts/goldendragon/etc/systemd/system-sleep/99-fprintd-reset.sh`, `hosts/goldendragon/etc/pam.d/hyprlock`                                             | `infra/ansible/roles/fingerprint/tasks/configure.yml`, `infra/ansible/roles/fingerprint/files/hosts/goldendragon/*` | partial overlap  | Ansible `fingerprint` role                                                                 | stop using host setup as a second writer and eventually delete or archive the legacy reference copy                                           |
| fingerprint watchdog                              | `hosts/goldendragon/etc/systemd/user/fprintd-watchdog.*`, `hosts/goldendragon/.local/bin/fprintd-watchdog`, `hosts/goldendragon/scripts/fingerprint/*` | no current owner                                                                                                    | migration seam   | explicit new owner required                                                                | decide whether watchdog is system-owned by Ansible or user-owned by chezmoi, then port it completely                                          |
| hyprlock PAM base path                            | `packages/hyprland/hyprlock.pam`, `scripts/install/setup/pam-hyprlock.sh`                                                                              | `infra/ansible/roles/fingerprint/tasks/configure.yml` for fingerprint hosts                                         | partial overlap  | Ansible for managed `/etc/pam.d/hyprlock`                                                  | define one policy for non-fingerprint and fingerprint hosts, then retire shell installers                                                     |
| Hyprland session packages                         | `scripts/install/install-deps.sh`, `scripts/install/deps.manifest.toml`                                                                                | `infra/ansible/roles/hyprland/*`, `infra/ansible/roles/packages/*`                                                  | partial overlap  | Ansible `hyprland` + `packages`                                                            | stop using installer package paths for Ansible-managed hosts                                                                                  |
| Hyprland user-state rendering                     | Stow of `packages/hyprland/**`, host dotfiles under `hosts/<host>/dotfiles/**`                                                                         | `infra/chezmoi/manifests/*.manifest`, `infra/chezmoi/scripts/*.sh`                                                  | migration seam   | chezmoi                                                                                    | finish manifest expansion and carve migrated trees out of Stow permanently                                                                    |
| theme-generated user files                        | `scripts/theme-manager/*` writes runtime state under `$HOME`                                                                                           | chezmoi manifests are beginning to own adjacent trees                                                               | migration seam   | split by concern: chezmoi for static user files, theme-manager for runtime-generated state | document every runtime-generated exception and either keep it runtime-owned or move generation into the new model                             |
| NVIDIA kernel and module state                    | `scripts/install/system-config.sh`, `hosts/goldendragon/etc/modprobe.d/*`                                                                              | `infra/ansible/roles/nvidia/*`, `infra/ansible/roles/nvidia/files/hosts/goldendragon/**`                            | partial overlap  | Ansible `nvidia` role                                                                      | stop applying NVIDIA kernel and module state through legacy shell on managed hosts and eventually delete or archive the legacy reference copy |
| AMD GPU kernel, module, polkit, and service state | `scripts/install/system-config.sh`, `hosts/dragon/etc/**`, `hosts/firedragon/etc/**`                                                                   | `infra/ansible/roles/amd_gpu/*`, `infra/ansible/roles/amd_gpu/files/hosts/{dragon,firedragon}/**`                   | partial overlap  | Ansible `amd_gpu` role                                                                     | stop applying AMD state through legacy shell on managed hosts and eventually delete or archive the legacy reference copy                      |
| laptop power policy                               | `scripts/install/setup/power-management.sh`, host TLP config under `hosts/*/etc/tlp.d/*`                                                               | `infra/ansible/roles/tlp/*`, `infra/ansible/roles/tlp/files/hosts/*`                                                | partial overlap  | Ansible `tlp` role                                                                         | retire shell-side service toggles for managed hosts and eventually delete or archive the legacy reference copy                                |
| resolved DNS drop-ins                             | `hosts/<host>/etc/systemd/resolved.conf.d/dns.conf`                                                                                                    | `infra/ansible/roles/resolved/*`, `infra/ansible/roles/resolved/files/hosts/*`                                      | partial overlap  | Ansible `resolved` role                                                                    | stop treating host `etc/` as a live source for this role and eventually delete or archive the legacy reference copy                           |
| OpenFortiVPN units and helper                     | `hosts/goldendragon/etc/systemd/system/openfortivpn*.service`, `hosts/goldendragon/dotfiles/.local/bin/avular-vpn-dns`                                 | `infra/ansible/roles/openfortivpn/*`, `infra/ansible/roles/openfortivpn/files/hosts/goldendragon/*`                 | partial overlap  | Ansible `openfortivpn` role                                                                | stop treating host files as a live source and eventually delete or archive the legacy reference copy                                          |
| NetBird capability                                | `scripts/utilities/netbird-install.sh`, `hosts/*/setup.sh`                                                                                             | `infra/ansible/roles/netbird/*`                                                                                     | partial overlap  | Ansible `netbird` role                                                                     | retire host setup logic and finish any host-specific DNS or routing parity that still lives outside the role                                  |
| timezone policy                                   | `scripts/install/first-run.sh`                                                                                                                         | `infra/ansible/roles/base/tasks/configure.yml`                                                                      | partial overlap  | Ansible `base` role                                                                        | set real per-host timezone vars and stop relying on first-run mutation for managed hosts                                                      |
| secrets flow                                      | `scripts/utilities/secrets.sh`, `install.sh` secrets setup                                                                                             | no new-system replacement yet                                                                                       | migration seam   | explicit product decision required                                                         | choose out-of-band secrets, Ansible Vault, or chezmoi-backed secret rendering and document it                                                 |
| host-specific hardware and service extras         | `hosts/dragon/setup.sh`, `hosts/firedragon/setup.sh`, `hosts/goldendragon/setup.sh`, assorted `hosts/*/etc/**`                                         | only partially represented in current roles                                                                         | migration seam   | explicit role ownership, chezmoi for `$HOME` only                                          | port remaining host `/etc`, service, and hardware slices into explicit roles or mark them as intentional exceptions                           |


### Canonical-owner decisions already implied by the new architecture

These should now be treated as policy:

- Ansible is the canonical owner of system packages.
- Ansible is the canonical owner of `/etc`.
- Ansible is the canonical owner of system services and service enablement.
- chezmoi is the canonical owner of static user-state under `$HOME`.
- legacy host trees under `hosts/<host>/etc/` and `hosts/<host>/dotfiles/` are reference material until their contents are absorbed into roles or manifests.
- host setup scripts are not the long-term runtime owner of any feature that already has an Ansible role or chezmoi manifest.

### Canonical-owner decisions that still need explicit resolution

These still need a hard decision before the repo can claim a full pivot:

- whether fingerprint watchdog is system-owned by Ansible or user-owned by chezmoi
- whether PipeWire host audio drop-ins are system-owned by Ansible or intentionally left outside the parity target
- whether `battery-status` and similar host helper binaries are chezmoi-owned user state or intentionally retired
- whether secure boot, NetBird, AIO cooler, ASUS laptop behavior, and other host-specific capabilities become first-class roles or remain documented exceptions
- whether secrets stay outside the new control plane or become a first-class part of it

## Pivot plan to reach 100% ownership clarity

The repo is not fully pivoted when new roles merely copy from legacy host trees.

The repo is fully pivoted only when:

1. a concern has one canonical runtime owner
2. the implementation source also lives under that owner's control plane
3. the legacy host path is demoted to reference-only or deleted
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

Batch-1 progress:

- completed for `fingerprint`, `resolved`, `tlp`, and `openfortivpn`

Batch-2 progress:

- completed for `nvidia` and `amd_gpu`
- still pending for the unmanaged host-specific `/etc` surfaces that do not yet have roles at all

Batch-9 progress:

- completed for the firedragon ASUS laptop edge stack via `roles/asus_laptop`
- vendored firedragon NetworkManager dispatcher, lid/sleep drop-ins, system-sleep hooks, and AX210 udev rules into role-local payloads

Batch-11 progress:

- completed for firedragon hibernation and resume plumbing via `roles/hibernation`
- retired the direct dependency on `hosts/firedragon/enable-sleep-hibernate.sh` by moving swap, resume, mkinitcpio, and Limine state under explicit Ansible ownership

Batch-12 progress:

- retired `hosts/firedragon/fix-acpi-boot.sh` because ASUS ACPI boot parameters are already owned by `roles/asus_laptop`
- retired `hosts/firedragon/fix-lid-close-freeze.sh` because its mutation surface is now split across `roles/amd_gpu`, `roles/asus_laptop`, `roles/tlp`, and `roles/hibernation`
- ported `hosts/firedragon/verify-suspend-fix.sh` into the disposable validation lane as `tests/vm/proxmox-validation/firedragon-suspend-verify.sh`

#### Stage 3. Close capability gaps

- add a real `netbird` role
- add explicit owners for `aio-cooler`, ASUS/Vivobook behavior, secure boot, and remaining laptop/runtime PM surfaces if they are part of parity
- decide and implement ownership for fingerprint watchdog and other still-unowned host behavior

Current progress:

- `asus_laptop` is now the explicit Ansible owner of the firedragon NetworkManager dispatcher, lid/sleep policy, system-sleep hooks, and AX210 Bluetooth udev behavior
- `hibernation` is now the explicit Ansible owner of firedragon swap, resume, mkinitcpio, and Limine hibernate plumbing
- the old firedragon ACPI and lid-close repair mutators are now retired in favor of explicit role ownership plus disposable-lane validation
- remaining capability gaps still include `aio-cooler`, secure boot, fingerprint watchdog, and the user `kbd-backlight` ownership decision

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
- `hosts/dragon/etc/systemd/resolved.conf.d/dns.conf`
- `hosts/dragon/etc/systemd/logind.conf.d/dragon-power.conf`
- `hosts/dragon/etc/systemd/sleep.conf.d/dragon-sleep.conf`
- `hosts/dragon/etc/systemd/system-sleep/liquidctl-suspend.sh`
- `hosts/dragon/etc/polkit-1/rules.d/90-corectrl.rules`
- `hosts/dragon/etc/modprobe.d/amdgpu-dragon.conf`
- `hosts/dragon/etc/modprobe.d/v4l2loopback.conf`
- `hosts/dragon/etc/modules-load.d/v4l2loopback.conf`
- `hosts/dragon/pipewire/20-stereo-audient.conf`
- `hosts/dragon/pipewire/90-audient-defaults.conf`
- `hosts/dragon/pipewire/README.md`
- `hosts/dragon/dotfiles/.config/zsh/hosts/dragon.zsh`
- `hosts/dragon/dotfiles/.config/zsh/functions/dragon.zsh`

Related legacy shared sources:

- `scripts/install/deps.manifest.toml`
- `scripts/utilities/audio-setup.sh`
- `scripts/utilities/netbird-install.sh`
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
- `resolved`
- `netbird`

Chezmoi:

- no committed `dragon`-specific generated tree
- host zsh overlays are now covered by `session-zsh.manifest`

### Already covered or strongly represented

- resolved DNS via `roles/resolved`
- AMD GPU core role coverage via `roles/amd_gpu`
- CoreCtrl polkit rule copied from legacy root by `roles/amd_gpu`
- desktop user account and admin group via `roles/users`
- desktop session substrate via `roles/sddm` and `roles/hyprland`

### Missing or only partially represented

- `dynamic_led.py`
- `dynamic_led.service`
- `liquidctl-dragon.service`
- `etc/systemd/system-sleep/liquidctl-suspend.sh`
- `etc/systemd/logind.conf.d/dragon-power.conf`
- `etc/systemd/sleep.conf.d/dragon-sleep.conf`
- `etc/modprobe.d/v4l2loopback.conf`
- `etc/modules-load.d/v4l2loopback.conf`
- PipeWire host audio drop-ins under `hosts/dragon/pipewire/`
- NetBird installation and convergence
- `aio-cooler` capability as a first-class role-owned concern

### `dragon` parity checklist

- add a role for `aio-cooler` or fold its owned files into a clearly scoped role
- install `dynamic_led` and `liquidctl` units from canonical repo paths
- port `dragon` power and sleep drop-ins into Ansible-managed `/etc`
- add `v4l2loopback` modprobe and modules-load ownership
- decide whether PipeWire host audio stays script-owned or moves to chezmoi
- retire legacy NetBird setup calls once the new role is the only supported path

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
- `hosts/firedragon/etc/systemd/resolved.conf.d/dns.conf`
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
- `hosts/firedragon/docs/NETBIRD_DNS_INTEGRATION.md`
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

### Already covered or strongly represented

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
- `etc/systemd/resolved.conf.d/dns.conf` via `roles/resolved`
- NetBird installation and service ownership via `roles/netbird`
- Hyprland and SDDM session substrate via `roles/hyprland` and `roles/sddm`

### Missing or only partially represented

- NetBird DNS integration behavior beyond the dispatcher/resolved edge stack
- user `kbd-backlight` helper still lives outside chezmoi and explicit user-state ownership

### `firedragon` parity checklist

- keep `roles/packages`, `roles/amd_gpu`, and `roles/asus_laptop` aligned with the firedragon package contract
- preserve firedragon DNS integration behavior around NetBird while retiring the legacy installer path
- keep the retired ACPI repair stubs reference-only while validating the Ansible-owned behavior through the disposable firedragon probe
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
- `hosts/goldendragon/etc/iwd/main.conf`
- `hosts/goldendragon/etc/modprobe.d/nvidia.conf`
- `hosts/goldendragon/etc/modprobe.d/nvidia-drm.conf`
- `hosts/goldendragon/etc/modprobe.d/v4l2loopback.conf`
- `hosts/goldendragon/etc/modules-load.d/v4l2loopback.conf`
- `hosts/goldendragon/etc/NetworkManager/conf.d/10-unmanage-wlan0.conf`
- `hosts/goldendragon/etc/pam.d/hyprlock`
- `hosts/goldendragon/etc/pam.d/polkit-1`
- `hosts/goldendragon/etc/systemd/logind.conf.d/10-goldendragon-lid.conf`
- `hosts/goldendragon/etc/systemd/resolved.conf.d/dns.conf`
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
- `openfortivpn`

Chezmoi:

- current manifests can include `hosts/goldendragon/dotfiles/.config/waybar-hosts/goldendragon/`
- host zsh overlays are now covered by `session-zsh.manifest`

### Already covered or strongly represented

- `etc/tlp.d/01-goldendragon.conf` via `roles/tlp`
- `etc/systemd/resolved.conf.d/dns.conf` via `roles/resolved`
- `etc/modprobe.d/nvidia.conf` and `nvidia-drm.conf` via `roles/nvidia`
- `nvidia-drm.modeset=1` kernel parameter via `roles/nvidia`
- fingerprint udev and PAM behavior via `roles/fingerprint`
- `etc/pam.d/hyprlock` via `roles/fingerprint`
- OpenFortiVPN service units and `/usr/local/bin/avular-vpn-dns` via `roles/openfortivpn`
- desktop session substrate via `roles/sddm` and `roles/hyprland`

### Missing or only partially represented

- `etc/acpi/disable-wakeup.sh`
- `etc/systemd/system/disable-acpi-wakeup.service`
- `etc/iwd/main.conf`
- `etc/modprobe.d/v4l2loopback.conf`
- `etc/modules-load.d/v4l2loopback.conf`
- `etc/NetworkManager/conf.d/10-unmanage-wlan0.conf`
- `etc/systemd/logind.conf.d/10-goldendragon-lid.conf`
- `etc/systemd/sleep.conf.d/10-goldendragon-sleep.conf`
- user `fprintd-watchdog` timer/service/binary
- laptop package parity from `setup_goldendragon_packages()`
- `~/.local/bin/battery-status` behavior created by legacy `setup.sh`
- exact Waybar VPN marker lifecycle for `vpn-enabled`
- secure-boot bringup path is still script-oriented and currently path-fragile

### `goldendragon` parity checklist

- port the unmanaged `etc/` system files into Ansible or explicitly keep `setup.sh` mandatory until done
- add fingerprint watchdog ownership to the new architecture
- reconcile laptop package bringup from `setup_goldendragon_packages()` with new package roles
- decide where `battery-status` lives in the new model
- add explicit management or validation for the Waybar VPN marker
- fix the secure-boot script entrypoint so it matches the actual repo path

## `microdragon`

### Legacy host sources on `main`

Host-specific sources:

- `hosts/microdragon/setup.sh`

Related legacy shared sources:

- `scripts/utilities/netbird-install.sh`
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

### Already covered or strongly represented

- Debian server identity via inventory and host vars
- base user management via `roles/users`
- baseline package/profile bringup via `roles/packages`
- non-Hyprland server posture via inventory grouping

### Missing or only partially represented

- NetBird parity verification on Debian beyond the new role contract
- any host-specific user-state
- legacy `setup.sh` Debian mismatch around `scripts/utilities/netbird-install.sh`

### `microdragon` parity checklist

- verify the new `netbird` role against real Debian behavior on `microdragon`
- replace or branch the legacy NetBird installer for Debian if it remains in use
- decide whether `microdragon` should gain a `.traits` file and/or host dotfiles source

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
