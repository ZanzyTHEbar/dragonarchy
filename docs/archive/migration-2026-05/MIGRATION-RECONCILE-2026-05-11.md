# Dotfiles Migration Reconciliation — 2026-05-11

## Executive Summary

This repository is in the middle of a transition from a legacy **imperative bash-script + GNU Stow** driven flow to a new **declarative Ansible + chezmoi** driven flow. The goal is a **100% cutover with 1:1 parity** of functionality and featuresets (plus improvements where possible).

**Current State:**
- **Legacy system:** 1,223-line `install.sh`, 1,873-line package installer, 68 theme-manager scripts, 31 Stow packages. Still the primary bringup path.
- **New system:** 15 Ansible roles, 8 playbooks, 3 chezmoi manifests, 3 Packer validation templates. Well-structured but incomplete.
- **Migration progress:** ~35% complete. The "hot path" (foundation, base, packages, users, display manager, session substrate, GPU, power, networking) is largely migrated to Ansible. Chezmoi only covers the Hyprland session + Zsh core. The long tail of Stow packages, theme management, hardware utilities, and host-specific edge cases remains in legacy.

**Critical blocker:** There is no unified entrypoint for the new flow. Users must still run `install.sh` or manually invoke Ansible playbooks and chezmoi commands.

---

## 1. Legacy System Inventory

### 1.1 Top-Level Orchestrator
| Component | File | Lines | Status |
|-----------|------|-------|--------|
| Main installer | `install.sh` | 1,223 | Active, with control-plane gating |

**Phases:** prerequisites → packages → dotfiles (Stow) → setup scripts → host config → migrations → themes → icons → shell → post-setup → utilities → secrets → validation → system config → first-run.

### 1.2 Core Libraries (`scripts/lib/`)
| Component | File | Purpose | New Owner |
|-----------|------|---------|-----------|
| Logging | `logging.sh` | Color-coded terminal output | **Retained** (no Ansible/chezmoi equivalent needed) |
| Install state | `install-state.sh` | Marker-file idempotency | **Ansible** (built-in) |
| Host detection | `hosts.sh` | MAC/hostname detection, trait loading | **Ansible inventory** |
| Platform | `platform.sh` | OS/arch detection | **Ansible `common` role** |
| System mods | `system-mods.sh` | Safe `/etc` modifications with backup | **Ansible roles** |
| Stow helpers | `stow-helpers.sh` | GNU Stow conflict resolution | **Chezmoi** |
| Manifest TOML | `manifest-toml.sh` | `deps.manifest.toml` parser | **Partial** — Ansible `packages` role still uses `export-package-plan.sh` |
| Control-plane mode | `control-plane-mode.sh` | Gating for Ansible/chezmoi ownership | **Retained** (migration seam) |

### 1.3 Installation Scripts (`scripts/install/`)
| Component | File | Lines | Migrated To | Status |
|-----------|------|-------|-------------|--------|
| Package installer | `install-deps.sh` | 1,873 | Ansible `packages` role | **Partial** — still used by Ansible via `export-package-plan.sh` |
| Setup orchestrator | `setup.sh` | ~200 | Ansible playbooks | **Partial** — some setup scripts still only in legacy |
| System config | `system-config.sh` | ~400 | Ansible `nvidia`, `amd_gpu`, `asus_laptop` | **Partial** — Intel GPU path, general hardware detection not migrated |
| First-run | `first-run.sh` | ~300 | Ansible `base` role | **Partial** — timezone, firewall still in legacy |
| Validation | `validate.sh` | ~500 | Role `validate.yml` / `verify.yml` | **Partial** — no unified parity gate yet |
| Migrations | `run-migrations.sh` | ~150 | N/A | **Not migrated** |
| System Stow | `stow-system.sh` | ~100 | Ansible roles | **Partial** — SDDM, polkit still in system Stow scope |

### 1.4 Setup Modules (`scripts/install/setup/`)
| Script | Purpose | Migrated To | Status |
|--------|---------|-------------|--------|
| `applications.sh` | Application tweaks | N/A | **Not migrated** |
| `default-apps.sh` | MIME defaults | N/A | **Not migrated** |
| `pacman-tweaks.sh` | `pacman.conf` tweaks | N/A | **Not migrated** |
| `power-management.sh` | Power profiles | Ansible `tlp`, `asus_laptop` | **Partial** |
| `steam.sh` | Steam setup | N/A | **Not migrated** |
| `system-services.sh` | Enable systemd services | Ansible roles | **Partial** — some services only in legacy |
| `samba-usershare.sh` | Samba usershare | N/A | **Not migrated** |
| `user-services.sh` | Enable user services | N/A | **Not migrated** |
| `keyboard.sh` | Keyboard config | N/A | **Not migrated** |
| `pam-hyprlock.sh` | PAM for hyprlock | Ansible `fingerprint` | **Partial** — base hyprlock PAM not migrated |
| `plymouth.sh` | Boot splash theme | N/A | **Not migrated** |
| `clipboard*.sh` | Clipboard manager | N/A | **Not migrated** |
| `user-config.sh` | General user config | N/A | **Not migrated** |
| `post-install.sh` | Final cleanup | N/A | **Not migrated** |

### 1.5 Theme Manager (`scripts/theme-manager/`)
**68 files, ~3,000+ lines total.** This is a **completely unmigrated subsystem.**

| Category | Scripts | Status |
|----------|---------|--------|
| Theme switching | `theme-set`, `theme-next`, `theme-install`, `theme-remove`, `theme-update` | **Not migrated** |
| Backgrounds | `theme-bg-next`, `theme-bg-apply`, `theme-bg-menu`, `theme-bg-undo` | **Not migrated** |
| SDDM themes | `sddm-set`, `refresh-sddm`, `sddm-menu` | **Not migrated** (Ansible copies raw files only) |
| Plymouth | `refresh-plymouth` | **Not migrated** |
| Color generation | `generate-gtk-themes`, `generate-kitty-themes`, `generate-swaync-themes`, `generate-clipse-themes`, `generate-walker-themes` | **Not migrated** |
| Menus/utilities | `power-menu`, `network-menu`, `keybindings-menu`, `screenshot`, `screenrecord` | **Not migrated** |

**Decision needed:** Theme manager generates runtime state. It should stay as a runtime subsystem, but its integration with the new control plane needs to be defined.

### 1.6 Hardware Scripts (`scripts/hardware/`)
| Script | Purpose | Migrated To | Status |
|--------|---------|-------------|--------|
| `battery-monitor` | Battery monitoring | N/A | **Not migrated** |
| `disk-usage` | Disk usage display | N/A | **Not migrated** |
| `fido2` | FIDO2 key setup | N/A | **Not migrated** |
| `fingerprint` | Fingerprint setup | Ansible `fingerprint` | **Partial** |
| `power-saving-mode` | Power saving toggle | Ansible `tlp` | **Partial** |
| `thermal-profile-*` | Thermal management | Ansible `asus_laptop` | **Partial** |
| `thermals` | Thermal display | N/A | **Not migrated** |

### 1.7 Utilities (`scripts/utilities/`)
| Script | Purpose | Migrated To | Status |
|--------|---------|-------------|--------|
| `secrets.sh` | Secrets management | N/A | **Missing** — referenced by `install.sh` but file does not exist |
| `netbird-install.sh` | NetBird VPN install | Ansible `netbird` | **Migrated** |
| `nfs.sh` | NFS mount config | N/A | **Not migrated** |
| `web-apps.sh` | Web app launchers | N/A | **Not migrated** |
| `docker-dbs.sh` | DB containers | N/A | **Missing** — referenced but does not exist |

### 1.8 Stow Packages (`packages/`)
**31 packages total. Only ~3-4 migrated to chezmoi.**

| Package | Scope | Migrated To | Status |
|---------|-------|-------------|--------|
| `hyprland` | user | Chezmoi `session-core`, `session-shell` | **Partial** — only `.config/hypr`, `.config/waybar`, `.config/walker`, `.config/elephant`, `.config/autostart`, `.config/clipse`, `.config/swaync`, `.config/swayosd` migrated. `.local/bin/**`, `.config/theme-manager/**` still in Stow |
| `zsh` | user | Chezmoi `session-zsh` | **Migrated** |
| `sddm` | system | Ansible `sddm` role | **Partial** — theme files copied by Ansible, but theme compilation still in legacy |
| `polkit` | system | Ansible `base` role | **Partial** — `49-wheel-admin.rules` now in Ansible, but package still in system Stow |
| `alacritty` | user | N/A | **Not migrated** |
| `applications` | user | N/A | **Not migrated** |
| `dragon-cli` | user | N/A | **Not migrated** |
| `fastfetch` | user | N/A | **Not migrated** |
| `fcitx5` | user | N/A | **Not migrated** |
| `fonts` | user | N/A | **Not migrated** |
| `gh-extensions` | user | N/A | **Not migrated** |
| `git` | user | N/A | **Not migrated** |
| `gpg` | user | N/A | **Not migrated** |
| `gtk-3.0` | user | N/A | **Not migrated** |
| `gtk-4.0` | user | N/A | **Not migrated** |
| `hardware` | user | N/A | **Not migrated** |
| `icons-in-terminal` | user | N/A | **Not migrated** |
| `kitty` | user | N/A | **Not migrated** |
| `lazygit` | user | N/A | **Not migrated** |
| `nvim` | user | N/A | **Not migrated** |
| `opencode` | user | N/A | **Not migrated** |
| `qt5ct` | user | N/A | **Not migrated** |
| `ssh` | user | N/A | **Not migrated** |
| `themes` | user | N/A | **Not migrated** |
| `tmux` | user | N/A | **Not migrated** |
| `typora` | user | N/A | **Not migrated** |
| `wlogout` | user | N/A | **Not migrated** |
| `xournalpp` | user | N/A | **Not migrated** |
| `yazi` | user | N/A | **Not migrated** |
| `zed` | user | N/A | **Not migrated** |

---

## 2. New System Inventory

### 2.1 Ansible Control Plane (`infra/ansible/`)

**Roles (15 implemented, 1 missing):**

| # | Role | Status | Hosts | Description |
|---|------|--------|-------|-------------|
| 1 | `common` | Complete | All | Foundation contract validation |
| 2 | `base` | Complete | All | Timezone, polkit |
| 3 | `packages` | Complete | All | Package installation via manifest |
| 4 | `users` | Complete | All | User/group management |
| 5 | `sddm` | Complete | `sddm` group | Display manager |
| 6 | `hyprland` | Complete | `hyprland` group | Session substrate verification |
| 7 | `fingerprint` | Complete | `fingerprint` group | fprintd, PAM |
| 8 | `nvidia` | Complete | `nvidia` group | NVIDIA drivers/modules |
| 9 | `amd_gpu` | Complete | `amd_gpu` group | AMDGPU config |
| 10 | `tlp` | Complete | `tlp` group | Laptop power |
| 11 | `asus_laptop` | Complete | `asus` group | ASUS laptop services |
| 12 | `hibernation` | Complete | `hibernation` group | Swap/resume |
| 13 | `resolved` | Complete | `resolved` group | DNS config |
| 14 | `netbird` | Complete | `netbird` group | VPN |
| 15 | `openfortivpn` | Complete | `fortinet_vpn` group | Fortinet VPN |
| **16** | **`aio-cooler`** | **MISSING** | `dragon` | AIO liquid cooler control |

**Playbooks (8):**
| Playbook | Purpose | Status |
|----------|---------|--------|
| `foundation.yml` | Common contract | Complete |
| `hot-path-tranche-1.yml` | Base + packages + users | Complete |
| `hot-path-tranche-2.yml` | SDDM | Complete |
| `hot-path-tranche-3.yml` | Hyprland | Complete |
| `hot-path-tranche-4.yml` | GPU + fingerprint | Complete |
| `hot-path-tranche-5.yml` | Power/networking | Complete |
| `edge-cases.yml` | ASUS + hibernation | Complete |
| `site.yml` | Main entrypoint (imports tranche-5 + edge-cases) | Complete |

**Execution chain:** `site.yml` → `hot-path-tranche-5.yml` → `hot-path-tranche-4.yml` → ... → `foundation.yml`.

### 2.2 Chezmoi Control Plane (`infra/chezmoi/`)

**Manifests (3):**
| Manifest | Paths Covered | Status |
|----------|---------------|--------|
| `session-core.manifest` | `.config/hypr`, `.config/waybar`, `.config/walker`, `.config/elephant` | Implemented |
| `session-shell.manifest` | `.config/autostart`, `.config/clipse`, `.config/swaync`, `.config/swayosd` | Implemented |
| `session-zsh.manifest` | `.zshrc`, `.zshenv`, `.config/zsh` | Implemented |

**Generated source:** Only `goldendragon` has a committed generated tree.

**Scripts:**
| Script | Purpose | Status |
|--------|---------|--------|
| `build-source.sh` | Build generated source | Implemented |
| `verify-generated-source.sh` | Verify generated tree | Implemented |
| `plan-stow-cutover.sh` | Plan Stow carve-out | Implemented |
| `cutover-host.sh` | Execute cutover | Implemented |

### 2.3 Packer Validation (`infra/packer/`)
| Template | Purpose | Status |
|----------|---------|--------|
| `debian-14-validation` | Debian server path | Defined |
| `arch-validation` | Arch CLI path | Defined |
| `arch-graphical-validation` | Arch + Hyprland | Defined |

---

## 3. Host-by-Host Migration Status

### 3.1 `dragon` (AMD Desktop Workstation)
**Traits:** `amd-gpu`, `aio-cooler`, `hyprland`, `sddm`, `desktop`, `netbird`

| Domain | Legacy Sources | New Owner | Status |
|--------|----------------|-----------|--------|
| AMD GPU | `hosts/dragon/etc/modprobe.d/amdgpu-dragon.conf`, `etc/polkit-1/rules.d/90-corectrl.rules` | Ansible `amd_gpu` | **Migrated** |
| Resolved DNS | `hosts/dragon/etc/systemd/resolved.conf.d/dns.conf` | Ansible `resolved` | **Migrated** |
| NetBird | `hosts/dragon/setup.sh` | Ansible `netbird` | **Migrated** |
| Session (Hyprland/Waybar/Zsh) | `packages/hyprland/`, `packages/zsh/`, host dotfiles | Chezmoi manifests | **Migrated** |
| **AIO Cooler** | `hosts/dragon/dynamic_led.py`, `dynamic_led.service`, `liquidctl-dragon.service`, `etc/systemd/system-sleep/liquidctl-suspend.sh` | **MISSING** | **Gap** |
| Power/Sleep | `hosts/dragon/etc/systemd/logind.conf.d/dragon-power.conf`, `etc/systemd/sleep.conf.d/dragon-sleep.conf` | **Not migrated** | **Gap** |
| v4l2loopback | `hosts/dragon/etc/modprobe.d/v4l2loopback.conf`, `etc/modules-load.d/v4l2loopback.conf` | **Not migrated** | **Gap** |
| PipeWire audio | `hosts/dragon/pipewire/` | **Not migrated** | **Gap** |
| Host zsh overlays | `hosts/dragon/dotfiles/.config/zsh/` | Chezmoi `session-zsh` | **Migrated** |

**Parity:** ~65% — missing AIO cooler role, power/sleep drop-ins, v4l2loopback, PipeWire.

---

### 3.2 `firedragon` (ASUS VivoBook Laptop)
**Traits:** `laptop`, `amd-gpu`, `tlp`, `hyprland`, `sddm`, `asus`, `netbird`

| Domain | Legacy Sources | New Owner | Status |
|--------|----------------|-----------|--------|
| AMD GPU | `hosts/firedragon/etc/modprobe.d/amdgpu.conf`, `etc/systemd/system/amdgpu-*.service`, `etc/limine-entry-tool.d/10-amdgpu.conf` | Ansible `amd_gpu` | **Migrated** |
| TLP | `hosts/firedragon/etc/tlp.d/01-firedragon.conf` | Ansible `tlp` | **Migrated** |
| ASUS laptop | `hosts/firedragon/etc/NetworkManager/dispatcher.d/50-home-dns`, `etc/systemd/logind.conf.d/10-firedragon-lid.conf`, `etc/systemd/sleep.conf.d/10-firedragon-sleep.conf`, `etc/systemd/system-sleep/98-ax210-bt-recover.sh`, `etc/systemd/system-sleep/99-runtime-pm.sh`, `etc/tlp.d/01-firedragon.conf`, `etc/udev/rules.d/99-intel-ax210-btusb-power.rules` | Ansible `asus_laptop` | **Migrated** |
| Hibernation | `hosts/firedragon/enable-sleep-hibernate.sh` | Ansible `hibernation` | **Migrated** |
| Resolved DNS | `hosts/firedragon/etc/systemd/resolved.conf.d/dns.conf` | Ansible `resolved` | **Migrated** |
| NetBird | `hosts/firedragon/setup.sh` | Ansible `netbird` | **Migrated** |
| Session | `packages/hyprland/`, `packages/zsh/`, host dotfiles | Chezmoi manifests | **Migrated** |
| NetBird DNS integration | `hosts/firedragon/docs/NETBIRD_DNS_INTEGRATION.md` | **Partial** | **Gap** |
| kbd-backlight | User helper | **Undecided** | **Gap** |
| Host zsh overlays | `hosts/firedragon/dotfiles/.config/zsh/` | Chezmoi `session-zsh` | **Migrated** |

**Retired legacy scripts:** `fix-acpi-boot.sh`, `fix-lid-close-freeze.sh`, `enable-sleep-hibernate.sh` → migrated to Ansible roles.

**Parity:** ~85% — best covered host. Minor gaps around NetBird DNS integration and kbd-backlight.

---

### 3.3 `goldendragon` (ThinkPad P16s, Intel + NVIDIA)
**Traits:** `laptop`, `nvidia`, `tlp`, `hyprland`, `sddm`, `fingerprint`, `vpn-fortinet`

| Domain | Legacy Sources | New Owner | Status |
|--------|----------------|-----------|--------|
| NVIDIA | `hosts/goldendragon/etc/modprobe.d/nvidia.conf`, `nvidia-drm.conf` | Ansible `nvidia` | **Migrated** |
| TLP | `hosts/goldendragon/etc/tlp.d/01-goldendragon.conf` | Ansible `tlp` | **Migrated** |
| Fingerprint | `hosts/goldendragon/etc/pam.d/hyprlock`, `etc/pam.d/polkit-1`, `etc/udev/rules.d/99-fingerprint-no-autosuspend.rules`, `etc/systemd/system-sleep/99-fprintd-reset.sh` | Ansible `fingerprint` | **Migrated** |
| Resolved DNS | `hosts/goldendragon/etc/systemd/resolved.conf.d/dns.conf` | Ansible `resolved` | **Migrated** |
| OpenFortiVPN | `hosts/goldendragon/etc/systemd/system/openfortivpn*.service`, `.local/bin/avular-vpn-dns` | Ansible `openfortivpn` | **Migrated** |
| Session | `packages/hyprland/`, `packages/zsh/`, host dotfiles | Chezmoi manifests | **Migrated** (only host with committed generated tree) |
| Waybar VPN marker | `hosts/goldendragon/dotfiles/.config/waybar-hosts/goldendragon/vpn-enabled` | Chezmoi (manifest optional path) | **Migrated** |
| **Fingerprint watchdog** | `hosts/goldendragon/.local/bin/fprintd-watchdog`, `etc/systemd/user/fprintd-watchdog.*`, `scripts/fingerprint/*` | **Undecided** | **Gap** |
| ACPI disable-wakeup | `hosts/goldendragon/etc/acpi/disable-wakeup.sh`, `etc/systemd/system/disable-acpi-wakeup.service` | **Not migrated** | **Gap** |
| iwd config | `hosts/goldendragon/etc/iwd/main.conf` | **Not migrated** | **Gap** |
| v4l2loopback | `hosts/goldendragon/etc/modprobe.d/v4l2loopback.conf`, `etc/modules-load.d/v4l2loopback.conf` | **Not migrated** | **Gap** |
| NetworkManager | `hosts/goldendragon/etc/NetworkManager/conf.d/10-unmanage-wlan0.conf` | **Not migrated** | **Gap** |
| Power/Sleep | `hosts/goldendragon/etc/systemd/logind.conf.d/10-goldendragon-lid.conf`, `etc/systemd/sleep.conf.d/10-goldendragon-sleep.conf` | **Not migrated** | **Gap** |
| Secure boot | `hosts/goldendragon/scripts/secure-boot/setup-secure-boot.sh` | **Not migrated** | **Gap** |
| battery-status | Created by legacy `setup.sh` | **Undecided** | **Gap** |
| Host zsh overlays | `hosts/goldendragon/dotfiles/.config/zsh/` | Chezmoi `session-zsh` | **Migrated** |

**Parity:** ~75% — strong coverage but several unmanaged `/etc` files and the fingerprint watchdog decision pending.

---

### 3.4 `microdragon` (Raspberry Pi, Debian Server)
**Traits:** (none declared)

| Domain | Legacy Sources | New Owner | Status |
|--------|----------------|-----------|--------|
| Base packages | `hosts/microdragon/setup.sh` | Ansible `packages` | **Migrated** |
| NetBird | `hosts/microdragon/setup.sh` | Ansible `netbird` | **Migrated** |
| Users | `hosts/microdragon/setup.sh` | Ansible `users` | **Migrated** |
| User-state | None | N/A | N/A (server, no desktop) |

**Parity:** ~90% — minimal host, well covered. Need Debian verification of NetBird role.

---

## 4. Gap Analysis

### 4.1 Critical Gaps (Must Fix Before Cutover)

| # | Gap | Impact | Owner |
|---|-----|--------|-------|
| 1 | **No unified new-flow entrypoint** | Users cannot bring up a host with only Ansible+chezmoi | Architecture |
| 2 | **AIO cooler role missing** | `dragon` AIO liquid cooler not managed | Ansible |
| 3 | **Intel GPU role missing** | No Ansible role for Intel graphics | Ansible |
| 4 | **Fingerprint watchdog undecided** | No owner for fprintd-watchdog on `goldendragon` | Architecture |
| 5 | **Theme manager not integrated** | 68 scripts, runtime-generated files undefined in new model | Architecture |
| 6 | **Secrets management missing** | `scripts/utilities/secrets.sh` referenced but does not exist | Architecture |
| 7 | **Validation not unified** | No single parity gate proving full bringup | Architecture |

### 4.2 High-Priority Gaps

| # | Gap | Impact | Owner |
|---|-----|--------|-------|
| 8 | ~27 Stow packages not migrated to chezmoi | Long tail of user config still in legacy | Chezmoi |
| 9 | Host `/etc` files not in roles (v4l2loopback, power/sleep, iwd, NetworkManager, ACPI) | System state still partially in host trees | Ansible |
| 10 | `install.sh` still primary bringup path | Legacy system not retired | Architecture |
| 11 | Packer templates do not run Ansible playbooks | Validation only tests bootstrap, not full convergence | Validation |
| 12 | `paru`/`script` tier packages not auto-installed | AUR and custom build packages still manual | Ansible |
| 13 | `pacman-tweaks.sh` not migrated | Pacman configuration still legacy-only | Ansible |
| 14 | `plymouth.sh` not migrated | Boot splash still legacy-only | Ansible |
| 15 | `system-services.sh` / `user-services.sh` not fully migrated | Service enablement gaps | Ansible |

### 4.3 Medium-Priority Gaps

| # | Gap | Impact | Owner |
|---|-----|--------|-------|
| 16 | PipeWire host audio drop-ins | `dragon` audio config unmanaged | Architecture |
| 17 | Secure boot path | `goldendragon` secure boot still script-oriented | Ansible |
| 18 | `battery-status` helper | Undecided ownership | Architecture |
| 19 | `kbd-backlight` helper | Undecided ownership | Architecture |
| 20 | NetBird DNS integration on `firedragon` | Host-specific DNS behavior outside role | Ansible |
| 21 | `samba-usershare.sh` not migrated | SMB usershare still legacy | Ansible |
| 22 | `steam.sh` not migrated | Steam setup still legacy | Ansible |
| 23 | Migrations framework not replaced | One-time upgrade path undefined | Architecture |
| 24 | `first-run.sh` not fully migrated | Firewall, timezone still legacy | Ansible |

---

## 5. Ranked Atomic Tasks

### Phase 1: Close Critical Ownership Gaps (Blocks All Cutover)

| # | Task | Hosts | Effort | Priority |
|---|------|-------|--------|----------|
| 1.1 | **Create unified new-flow entrypoint script** — `infra/run-convergence.sh` that runs `ansible-playbook site.yml` then `chezmoi apply` for a given host | All | Medium | **P0** |
| 1.2 | **Implement `aio-cooler` Ansible role** — migrate `dynamic_led.py`, `dynamic_led.service`, `liquidctl-dragon.service`, `liquidctl-suspend.sh` from `hosts/dragon/` | dragon | Medium | **P0** |
| 1.3 | **Decide and implement fingerprint watchdog ownership** — either Ansible `fingerprint` role (system) or chezmoi (user). Port `fprintd-watchdog` binary, timer, service | goldendragon | Small | **P0** |
| 1.4 | **Document theme manager integration contract** — define which theme-manager outputs are runtime-owned vs. chezmoi-owned | All | Small | **P0** |
| 1.5 | **Create `secrets` architecture decision** — choose Ansible Vault, chezmoi templates, or out-of-band. Document and implement minimal viable path | All | Medium | **P0** |

### Phase 2: Expand Ansible System Coverage

| # | Task | Hosts | Effort | Priority |
|---|------|-------|--------|----------|
| 2.1 | **Implement `intel_gpu` Ansible role** — port Intel GPU detection and config from `scripts/install/system-config.sh` | goldendragon (future Intel hosts) | Medium | **P1** |
| 2.2 | **Port remaining host `/etc` files into roles** — v4l2loopback (all), power/sleep drop-ins (dragon, goldendragon), iwd (goldendragon), NetworkManager (goldendragon), ACPI disable-wakeup (goldendragon) | dragon, goldendragon | Medium | **P1** |
| 2.3 | **Port `pacman-tweaks.sh` into Ansible** — `pacman.conf` color, parallel downloads, etc. | arch hosts | Small | **P1** |
| 2.4 | **Port `plymouth.sh` into Ansible** — boot splash theme installation and config | All desktop | Small | **P1** |
| 2.5 | **Port `first-run.sh` tasks into Ansible** — timezone, firewall (ufw), welcome message | All | Medium | **P1** |
| 2.6 | **Port service enablement into roles** — audit `system-services.sh` and `user-services.sh`, move into relevant Ansible roles | All | Medium | **P1** |
| 2.7 | **Port `samba-usershare.sh` into Ansible** — SMB usershare config | desktop hosts | Small | **P1** |
| 2.8 | **Port `steam.sh` into Ansible** — Steam installation and tweaks | desktop hosts | Small | **P1** |
| 2.9 | **Implement `secure-boot` Ansible role** — port `setup-secure-boot.sh` from `goldendragon` | goldendragon | Medium | **P1** |
| 2.10 | **Decide and implement PipeWire audio ownership** — either Ansible role or chezmoi for `dragon` drop-ins | dragon | Small | **P2** |
| 2.11 | **Complete NetBird DNS integration** — fold `firedragon` host-specific DNS behavior into `netbird` role or `resolved` role | firedragon | Small | **P2** |
| 2.12 | **Implement `v4l2loopback` Ansible role** — modprobe, modules-load for all hosts that need it | dragon, goldendragon | Small | **P2** |

### Phase 3: Expand Chezmoi User-State Coverage

| # | Task | Hosts | Effort | Priority |
|---|------|-------|--------|----------|
| 3.1 | **Create `devtools` chezmoi manifest** — nvim, kitty, tmux, zed, lazygit, yazi | All | Medium | **P1** |
| 3.2 | **Create `git-ssh` chezmoi manifest** — git, ssh, gpg | All | Small | **P1** |
| 3.3 | **Create `apps` chezmoi manifest** — alacritty, fcitx5, fastfetch, wlogout, typora, xournalpp | All | Small | **P2** |
| 3.4 | **Create `themes` chezmoi manifest** — gtk-3.0, gtk-4.0, qt5ct, themes, icons-in-terminal | All | Small | **P2** |
| 3.5 | **Create `cli-tools` chezmoi manifest** — dragon-cli, opencode, gh-extensions | All | Small | **P2** |
| 3.6 | **Cut over all manifests per-host** — run `cutover-host.sh --execute` for each host after manifests are ready | All | Large | **P1** |
| 3.7 | **Handle runtime-generated file exclusions** — document and exclude all theme-manager outputs from chezmoi manifests | All | Small | **P1** |

### Phase 4: Retire Legacy Paths

| # | Task | Hosts | Effort | Priority |
|---|------|-------|--------|----------|
| 4.1 | **Add control-plane gating to theme-manager scripts** — ensure theme-manager does not overwrite Ansible/chezmoi-owned paths | All | Small | **P1** |
| 4.2 | **Retire `hosts/<host>/setup.sh` for managed hosts** — delete or mark reference-only once parity proven | All | Medium | **P1** |
| 4.3 | **Retire system Stow for `/etc` packages** — remove `sddm`, `polkit` from system Stow scope for managed hosts | All | Small | **P1** |
| 4.4 | **Remove duplicate `/etc` files from host trees** — once absorbed into roles, delete legacy copies | All | Medium | **P2** |
| 4.5 | **Update `install.sh` to delegate to new flow** — when `DOTFILES_SYSTEM_OWNER=ansible`, run `ansible-playbook` instead of legacy scripts | All | Medium | **P1** |
| 4.6 | **Archive or delete retired legacy scripts** — `fix-acpi-boot.sh`, `fix-lid-close-freeze.sh`, `enable-sleep-hibernate.sh`, etc. | firedragon | Small | **P2** |

### Phase 5: Validation and Parity Proof

| # | Task | Hosts | Effort | Priority |
|---|------|-------|--------|----------|
| 5.1 | **Create unified parity validation script** — `infra/validate-parity.sh` that checks all Ansible roles and chezmoi manifests for a host | All | Large | **P1** |
| 5.2 | **Wire Packer templates to run Ansible playbooks** — ensure validation VMs actually converge the full control plane | All | Medium | **P1** |
| 5.3 | **Run disposable validation for each host** — Proxmox VM validation for dragon, firedragon, goldendragon, microdragon | All | Large | **P1** |
| 5.4 | **Mark hosts parity-complete** — once validation passes, document and tag host as fully migrated | All | Small | **P2** |

---

## 6. Decision Log

| # | Decision | Status | Blocker |
|---|----------|--------|---------|
| 1 | Fingerprint watchdog ownership (system vs user) | **Pending** | Architecture review |
| 2 | PipeWire audio drop-ins ownership | **Pending** | Architecture review |
| 3 | `battery-status` / `kbd-backlight` ownership | **Pending** | Architecture review |
| 4 | Secrets strategy (Vault vs chezmoi vs out-of-band) | **Pending** | Security review |
| 5 | Theme manager runtime contract | **Pending** | Design review |
| 6 | AUR/`paru` package auto-installation | **Pending** | Policy decision |
| 7 | Intel GPU role scope | **Pending** | Hardware access |

---

## 7. Metrics

| Metric | Legacy | New | Coverage |
|--------|--------|-----|----------|
| Top-level scripts | 1 (install.sh) | 0 (no unified entrypoint) | 0% |
| Ansible roles | 0 | 15 (+1 missing) | 94% |
| Chezmoi manifests | 0 | 3 | ~10% of Stow packages |
| Stow packages | 31 | ~4 migrated | ~13% |
| Theme-manager scripts | 68 | 0 | 0% |
| Host `/etc` files | ~40 | ~25 migrated | ~63% |
| Host-specific scripts | ~15 | ~8 retired/migrated | ~53% |
| Validation | 1 (legacy) | 0 (unified) | 0% |
| Packer templates | 0 | 3 | 100% |

---

## 8. Immediate Next Steps

1. **Make the 7 pending architecture decisions** (Section 6). These unblock multiple tasks.
2. **Implement the unified entrypoint** (Task 1.1). This is the most visible gap.
3. **Implement `aio-cooler` role** (Task 1.2). Blocks `dragon` parity.
4. **Decide fingerprint watchdog ownership** (Task 1.3). Blocks `goldendragon` parity.
5. **Create `devtools` and `git-ssh` chezmoi manifests** (Tasks 3.1, 3.2). Biggest user-state coverage wins.
6. **Port remaining host `/etc` files** (Task 2.2). Close the system-state gap.

---

*Generated: 2026-05-11*
*Basis: exhaustive audit of `install.sh`, `scripts/`, `packages/`, `hosts/`, `infra/ansible/`, `infra/chezmoi/`, and architecture docs*
