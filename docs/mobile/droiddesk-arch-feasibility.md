# DroidDesk Arch Feasibility — Hyprland Wayland Cutover

> Superseded: the selected target is Omalauncher only. This experiment is stopped,
> not a completed feasibility study. No desktop substitution was approved.
> Earlier claims below about Wayland being abandoned, native Hyprland viability,
> and shared-dotfile compatibility were not established and must not guide setup.
> Package searches ran in vanilla Termux, not DroidDesk's private runtime.
> See `architecture.md` for the active scope and validation status.

## Objective
Run Arch Linux ARM with Hyprland as the sole compositor inside DroidDesk,
replacing its default native Termux/XFCE/X11 stack.

## Constraints
- No root, no bootloader unlock
- Preserve Android security, Wallet, NFC, Revolut
- Software rendering by default (no DRM access)

## Investigation Steps
1. Inspect DroidDesk standalone init and private prefix
2. Test PRoot availability inside private userspace
3. Test verified Arch Linux ARM rootfs install
4. Test pacman in guest
5. Test X11 display transport (Termux:X11)
6. Test Hyprland with X11 backend
7. Test GUI applications
8. Test restart persistence and recovery
9. Test resource consumption

## Decision Gate
If native Arch+Hyprland proves impractical:
- Option A: Minimal userspace extension
- Option B: Termux-based DroidDesk + independent Arch PRoot
- Option C: Small upstream patch
- Option D: Retain native DroidDesk, use Omalauncher Arch for dev

## Current Status
Investigation started. Device connected via ADB wireless debugging.

### Findings

1. **DroidDesk standalone uses native Termux userspace** (dpkg/apt), not PRoot or Arch.
   Bootstrap is Termux-based (aarch64). No PRoot by default.

2. **proot and proot-distro are installable** via `pkg install proot proot-distro` in Termux.
   Available distros include Ubuntu, Debian, and others via Docker/OCI images.

3. **Hyprland is NOT available** in Termux repositories (main, x11, tur, root).
   Sway is available as a Wayland compositor alternative.
   Hyprland would need to be built from source on Termux (not recommended, many deps missing).

4. **Termux Wayland support is limited** — X11 via Termux:X11 is the primary display path.
   Wayland compositor support in Termux is effectively abandoned (last update 2021).

### Decision

Given the constraints (no root, no PRoot by user directive, vanilla Termux):
- **Hyprland config is maintained in dotfiles** for future use when Hyprland becomes available
- **Primary Termux environment** uses X11 via Termux:X11 (DroidDesk provides this)
- **Sway** is the recommended Wayland compositor if Wayland is required on Termux
- **Hyprland config** remains as the target for Arch-based or future environments

### Updated Approach

DroidDesk will use:
- Termux native userspace (dpkg/apt) as the base
- X11 display via DroidDesk's embedded Termux:X11
- Hyprland config maintained for when/if Hyprland becomes installable
- All shared dotfiles (zsh, tmux, nvim, git) configured for Termux compatibility
