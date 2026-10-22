# Managed Lifecycle Stability Contract (Active Fleet)

## Purpose

This document defines the canonical capability, provider, payload, activation, and verification matrix for the **four active managed inventory hosts**:

- `firedragon` (`arch`, `laptop`, `hyprland`, `sddm`, `tlp`, `asus`, `hibernation`, `amd_gpu`, `resolved`, `netbird`)
- `microdragon` (`debian`, `server`, `netbird`)
- `opencode-runtime` (`debian`, `server`, `container` target profile)
- `ubuntu-mobile-dev` (`debian`, `desktop`, `hyprland`, `sddm`)

### Scope Boundaries

- **Archived hosts (`dragon`, `goldendragon`)**: Retained as reference material under `hosts/legacy/<host>` and excluded from active `infra/ansible/inventory/hosts.yml`.
- **Mobile profile (`poco-x3-pro`)**: Managed through the isolated `--host poco-x3-pro --profile mobile` chezmoi path (`infra/chezmoi/manifests/mobile/`), not as an Ansible inventory host.
- **Historical six-host retirement ledgers**: Prior completion counts and six-host retirement records are historical provenance, not current fleet readiness.
- **Native VM qualification**: Explicitly deferred by the scope owner; static and isolated unit checks verify control-plane contracts and fail-closed gates, not live hardware or OS package availability.

### Controller Prerequisites

- `ansible-core` 2.16 or newer for the active fleet, with `community.general` 10.x installed from `infra/ansible/requirements.yml` (`ansible-galaxy collection install -r infra/ansible/requirements.yml`). The collection supplies `community.general.ufw` and supports ansible-core 2.15+.
- `mikefarah` yq v4 and `jq` on the controller. The managed Ansible path invokes the plan exporter with `--no-bootstrap`, so it never downloads or bootstraps yq during provisioning.
- A clean Git checkout for `install --update`; the public updater refuses dirty, detached, ahead, or diverged checkouts before fetching.


---

## Active Four-Host Capability & Ownership Matrix

| Host | Target Profile / Connection | Logical Package Groups (`deps.manifest.toml`) | System Roles (`site.yml`) | User Manifest Selection (`chezmoi-sync`) | Current Provisioning Gate Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`firedragon`** | `remote-host` / `ssh` (`daofficialwizard`) | `core_cli`, `dev`, `host_firedragon_laptop`, `laptop_power_tlp`, `hyprland_session`, `sddm` | `common`, `base`, `packages`, `users`, `sddm`, `hyprland`, `amd_gpu`, `tlp`, `resolved`, `netbird`, `asus_laptop`, `hibernation` | All 5 manifests (`devtools-core`, `git-ssh`, `session-core`, `session-shell`, `session-zsh`) + `hosts/firedragon/dotfiles/` overlays | **Blocked on pending AUR tier**: `pending.paru = ["libinput-gestures"]` until a managed AUR provider or explicit reclassification is approved. |
| **`microdragon`** | `remote-host` / `ssh` (`daofficialwizard`) | `core_cli` | `common`, `base`, `packages`, `users`, `netbird` | All five global manifests; desktop payloads are inert on a headless host (see known gap 1) | **Blocked on pending script tier**: `pending.script = ["gum"]` until a managed Debian provider or package reclassification is approved. |
| **`opencode-runtime`** | `container` / `local` (`coder`) | `core_cli` | `common`, `base` (`base_manage_time: false`), `packages`, `users` | All five global manifests; desktop payloads are inert on a headless host (see known gap 1) | **Blocked on pending script tier**: `pending.script = ["gum"]` until a managed Debian provider or package reclassification is approved. |
| **`ubuntu-mobile-dev`** | `remote-host` / `ssh` (`ubuntu`) | `core_cli`, `dev`, `hyprland_session`, `sddm` | `common`, `base`, `packages`, `users`, `sddm`, `hyprland` | All 5 manifests (`devtools-core`, `git-ssh`, `session-core`, `session-shell`, `session-zsh`) | **Blocked on pending script tier**: `pending.script = ["gh", "gum"]` until a managed Debian provider or package reclassification is approved. |

---

## Lifecycle Invariants Enforced in Code

1. **Truthful Package Convergence (`infra/ansible/roles/packages`)**:
   - Every group selected by `host_profile_packages` (plus `sddm` when `display_manager == 'sddm'`) is required.
   - `packages_pending_paru_policy` and `packages_pending_script_policy` default to `fail` and reject `report` overrides before resolution or installation.
   - `resolve.yml` validates the full `export-package-plan.sh` JSON schema, group provenance, and flattened manager arrays before `install.yml` runs. Any non-empty `pending.paru` or `pending.script` list fails closed before the `packages` role installs a native package.

2. **Idempotent Time Management and Explicit Collection Dependencies (`infra/ansible/roles/base`, `infra/ansible/requirements.yml`)**:
   - System timezone and NTP state are inspected via `timedatectl show` and mutated via `timedatectl set-timezone` / `timedatectl set-ntp true` only when drifted. This removes the invalid `ansible.builtin.timezone` reference and the unconditional `changed_when: true` churn.
   - `infra/ansible/requirements.yml` declares `community.general` for `community.general.ufw`.

3. **Explicit `UNKNOWN` Platform Facts (`infra/ansible/inventory/group_vars/all.yml`)**:
   - Exact distro release version, CPU architecture, kernel family/version, boot firmware/bootloader, filesystem, encryption, and Secure Boot state remain `UNKNOWN` until collected from target hardware or an approved disposable VM.

---

## Current Supported Product

The repository currently supports a **fail-closed managed control plane**, not a fleet-ready provisioning claim:

- The canonical `install` must select an inventory host and a non-root user; remote user state is shipped as a manifest-only archive and reconciled on the target. The legacy `install.sh` recovery path is not the managed contract.
- `site.yml` resolves packages from `scripts/install/deps.manifest.toml`; required repo-native tiers install only after the whole plan validates.
- `update.yml` performs targeted package upgrades for the selected host; it does not invent a target.
- Host-level secret, service, and activation ownership remains Ansible; static user files remain chezmoi.

### Known Gaps

1. **No desktop/headless manifest selection yet.** `chezmoi-sync` and `scripts/lib/remote-sync.py` currently plan every global manifest for every non-mobile host. `session-core` and `session-shell` payloads therefore land in the source tree on `microdragon` and `opencode-runtime`; they are inert without a graphical session, but they are not capability-scoped. Implementing selection must update both paths and the fixture tests together.
2. **Every active host is currently blocked by the truthful package gate on full `site.yml` convergence.** `firedragon` has `libinput-gestures` in the AUR tier; `microdragon` and `opencode-runtime` have `gum`; `ubuntu-mobile-dev` has `gh` and `gum`. Closing these requires an approved provider or an explicit reclassification; no provider URL, version, or installer should be guessed. `--user-only` and `--update` do not run the package gate and report only their own scoped completion.
3. **Native qualification is deferred.** Static parsing, isolated Ansible task evaluation, and shell tests do not prove kernel, package availability, display-manager, bootloader, container, or hardware behavior on the targets.
