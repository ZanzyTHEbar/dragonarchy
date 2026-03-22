# Debian Parity Matrix

This document tracks Debian parity work against the Arch-first bundle model in
`scripts/install/deps.manifest.toml`.

## Goal

Bring Debian as close as possible to Arch for:

- packages
- capabilities
- developer ergonomics
- desktop experience

When exact Debian packages do not exist, parity should prefer:

1. exact Debian package name
2. Debian package with different name
3. vendor `.deb` or vendor repository
4. upstream binary or installer
5. explicit unsupported/deferred status

## Provider and Release Matrix

| Distro family | Release track | Installer track | Hyprland strategy |
|---|---|---|---|
| Debian | `trixie`, `bookworm`, and older stable lines | `debian_legacy_no_hyprland` | keep desktop-base parity, defer Hyprland core until Debian 14+ |
| Debian | `forky`, `testing`, `sid` | `debian_hyprland_archive` | install Hyprland ecosystem from official archive packages |
| Ubuntu family | `resolute` and newer 26.x lines | `ubuntu_hyprland_archive` | enable `universe` and use the coherent official archive stack |
| Ubuntu family | `oracular`, `plucky`, `questing`, `noble`, `jammy`, older LTS-derived systems | `ubuntu_legacy_no_hyprland` | keep desktop-base parity, defer Hyprland core until the archive catches up |
| Other Debian-family derivatives | fallback based on `ID_LIKE` and release age | `debian_family_fallback_no_hyprland` | do not fake unsupported Hyprland core |

## Bundle Coverage

| Bundle | Current Debian status | Notes |
|---|---|---|
| `minimal` | Implemented and validated | Clean Debian VM run with `0 failures / 0 warnings` achieved |
| `desktop_base` | Implemented with track-aware behavior | `forky`/`sid` and `resolute+` archive tracks install Hyprland core from official packages; legacy tracks stay explicit and deferred |
| `desktop` | Implemented via `desktop_base` | Inherits the same provider-track behavior |
| `desktop_smb` | Implemented functionally | Adds repo-backed Nemo/Samba packages plus usershare setup |
| `creative` | Implemented with repo + vendor split | Repo-backed apps install by default; vendor extras stay opt-in/manual where appropriate |

## Group Status

### `core_cli`

- Debian repo coverage exists for most packages.
- Remaining parity work is mostly upstream tools and command-name normalization.

### `dev`

- Debian repo coverage exists for core developer packages.
- Remaining parity work includes `terraform` and `diff-so-fancy`.

### `fonts`

- Debian repo coverage exists for the core desktop font set.
- Nerd-font parity remains incomplete.

### `gui`

- Mostly vendor or upstream tools on Debian.
- High-priority packages:
  - `joplin-desktop`
  - `vivaldi`
  - `visual-studio-code-bin`
  - `visual-studio-code-insiders-bin`
  - `localsend`
  - `difftastic`

### `hyprland_base`

- Mixed Debian repo and upstream/vendor territory.
- A large subset should be available through `apt`.
- Remaining gaps are Wayland-session tooling and Rust/upstream utilities.

### `nemo_core`

- Debian repo parity should be mostly achievable through `apt`.

### `nemo_share`

- Debian repo parity is achieved through `apt` with Samba usershare support.
- Setup now provisions:
  - `/var/lib/samba/usershares`
  - `sambashare` group membership
  - `smb.conf` usershare settings
  - `smbd.service` enablement

### `hyprland_core`

- Highest-risk desktop parity area on Debian stable.
- Some packages may require upstream installation or newer Debian releases.
- Current strategy:
  - use official Debian archive packages on `debian_hyprland_archive`, starting at Debian 14 / `forky`
  - use official Ubuntu `universe` packages on `ubuntu_hyprland_archive`, starting with `resolute`
  - keep `trixie`, `plucky`, and other incomplete archive lines explicit and deferred
  - keep validation failures for supported archive tracks and expected warnings for deferred tracks

### `hyprland_aur`

- Mixed exact Debian packages, vendor apps, upstream tools, and AUR-only concepts.

### `creative`

- Most packages should be available via Debian repositories.

### `creative_aur`

- Vendor/proprietary installers only.
- Current split:
  - `REAPER` is supported through an official vendor tarball installer when vendor extras are opt-in
  - `DaVinci Resolve` remains documented manual-only because Blackmagic gates downloads and targets RHEL/CentOS-style environments

## Batch Roadmap

### Batch 1

- add in-repo parity matrix
- add generic Debian desktop validation target host
- add Debian manifest coverage for `desktop_base` repo-backed groups
- add Debian non-apt installer framework for vendor/upstream tools
- validate a fresh Debian VM package exercise for `desktop_base`

Current batch result:

- `install-deps.sh --host desktop --bundle desktop_base --no-cursor --no-setup`
  completes successfully on a fresh Debian 12 cloud VM after resizing the root
  disk to 40G.
- Full install plus validation on a fresh Debian 12 cloud VM now reaches:
  - `status: "warn"`
  - `failed: 0`
  - `warnings: 10`
- Debian repo-name mismatches fixed in this batch:
  - removed unavailable `qt6-style-kvantum`
  - moved `lazygit` to upstream install path
  - reduced `nemo_core` to the repo-backed subset on Debian 12
  - removed unavailable `pinta` from the Debian repo-backed set
- Validation/install mismatches fixed in this batch:
  - validator now accepts bundle context via `--bundle`
  - `zsh` package stow no longer loses to a pre-created `~/.zshrc`
  - kitty/walker migration no longer deletes files inside stow-managed symlinked directories
- `hyprland_core` remains the largest unresolved parity area.

Current expected warning classes for Debian `desktop_base`:

- no user SSH config
- no user Age keys / `.sops.yaml`
- large vendor binaries in `$HOME`
- missing Hyprland runtime components that belong to deferred `hyprland_core`

### Batch 2

- exercise Debian `desktop_base`
- fix repo-package naming mismatches
- decide `hyprland_core` strategy on Debian

Decision:

- Debian 12/stable does not provide `hyprland`, `hypridle`, `hyprlock`, or
  `hyprpicker` via stable `apt`, and `hyprshot` is not packaged in Debian.
- For now, `desktop_base` parity on Debian stops at the repo-backed desktop
  stack plus vendor/upstream GUI tools.
- A future fuller Debian desktop lane should choose one of:
  - Debian testing/sid as the package source for Hyprland core
  - a dedicated upstream-install path for Hyprland core binaries

### Batch 3

- add `desktop_smb` parity
- add `creative` parity
- classify remaining unsupported packages explicitly

Current batch result:

- Debian-family support now resolves explicit provider/release tracks in platform logic.
- Debian-family Hyprland bundles install from official archive packages when the release actually ships a coherent stack.
- `desktop_smb` now configures functional Samba usershare prerequisites instead of only installing packages.
- `creative` now cleanly separates repo-backed apps from vendor-backed/manual applications.

### Batch 4

- validate supported provider tracks in VM lanes
- correct release gates when real archive metadata disproves an optimistic assumption

Current batch result:

- Debian 12 `minimal` VM lane passed with `0 failures / 0 warnings`.
- A Debian 13 `desktop_base` VM lane proved the old matrix was wrong: `trixie` does not ship the required Hyprland archive stack.
- Provider-track gating is now aligned to the actual package sets:
  - Debian archive Hyprland starts at `forky`
  - Ubuntu archive Hyprland starts at `resolute`
- The Debian plugin meta-package assumption was removed from the default desktop bundle because Debian ships individually versioned Hyprland plugin packages instead.

### Batch 5

- close the supported-track VM matrix with clean `desktop_base` runs
- harden Debian-family Hyprland runtime validation against libexec-only packaging

Current batch result:

- Debian `forky` `desktop_base` VM lane passed with `0 failures / 0 warnings`.
- Ubuntu `resolute` `desktop_base` VM lane passed with `0 failures / 0 warnings`.
- Validation now recognizes archive-packaged Hyprland components that install under `/usr/libexec`, including:
  - `xdg-desktop-portal-hyprland`
  - `hyprpolkitagent`
- Desktop autostart now launches the first available PolicyKit agent in this order:
  - `hyprpolkitagent`
  - `mate-polkit`
  - `polkit-gnome`
- CI validation now treats missing per-user SSH/secrets state as optional when the install intentionally skips secrets, avoiding false-negative VM lane failures.

## Known High-Risk Areas

- Hyprland package availability on Debian stable
- vendor GUI apps with no official Debian repository package
- packages whose Arch equivalents are AUR `-git` builds
- command-name mismatches like `fd-find`/`fdfind` and `bat`/`batcat`
- session/runtime validation for desktop bundles in headless CI/VM environments
