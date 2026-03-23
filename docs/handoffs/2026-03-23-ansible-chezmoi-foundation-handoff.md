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
