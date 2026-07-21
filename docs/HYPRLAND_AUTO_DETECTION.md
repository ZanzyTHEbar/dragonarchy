# Hyprland Host Detection Contract

## Overview

Managed hosts declare Hyprland through inventory, host vars, and chezmoi manifests. Marker files document host intent only; the Ansible + chezmoi control plane does not infer host behavior from marker files, setup scripts, or documentation text.

## Problem Solved

**Before:** the legacy installer required adding new hostnames to the `hyprland_hosts` array in `install-deps.sh`:

```bash
local hyprland_hosts=("dragon" "spacedragon" "goldendragon")  # Easy to forget!
```

**After:** managed hosts declare Hyprland explicitly through inventory and host metadata.

## Declaration Inputs

Managed hosts use these explicit inputs:

### 1. Inventory and host vars

Managed hosts must be declared explicitly in `infra/ansible/inventory/hosts.yml`
and matching `host_vars`. This is the runtime source of truth for the Ansible
control plane.

### 2. Chezmoi manifest coverage

User-state rendering must be represented through the appropriate chezmoi
manifest entries before a host is considered ready for managed user-state sync.

### 3. Marker file

Create a `.hyprland` file in your host directory as a checked-in intent marker:

```bash
touch hosts/YOUR_HOST/.hyprland
```

**What it means:**

- Documents that the host is intended to run Hyprland.
- Does not make Ansible or chezmoi infer host behavior.
- Does not replace inventory, host vars, or manifest coverage.

## Quick Start

### For New Hyprland Hosts

```bash
# Create host directory
mkdir -p hosts/$(hostname)

# Create Hyprland marker as host documentation
touch hosts/$(hostname)/.hyprland

# Add inventory and host_vars entries before managed bring-up
```

### For Existing Hosts

All existing Hyprland hosts already have marker files:

- ✅ `dragon/.hyprland`
- ✅ `firedragon/.hyprland`
- ✅ `goldendragon/.hyprland`

## Verification

Check inventory and task graph for a managed host:

```bash
ansible-inventory -i infra/ansible/inventory/hosts.yml --host dragon
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit dragon --list-tasks
```

**Output example:**

```bash
play #4 (hyprland): Hot-path tranche 3
  hyprland : Assert Hyprland tranche-3 metadata exists
  hyprland : Install Hyprland system-session packages
```

## What Gets Installed for Hyprland Hosts

When declared through inventory and host vars, these packages are installed by the Ansible package plan:

### Desktop Environment (~70 packages)

- Hyprland, waybar, hyprlock, hypridle
- Swaync, swayosd, swaybg
- File managers, utilities, theming

### Applications (~25 AUR packages)

- Joplin, Kdenlive, LibreOffice
- Spotify, Zoom, Typora
- Calculators, clipboard managers

### Development Tools

- **Rust toolchain:** rustup, stable toolchain
- **Rust CLI tools:** lsd, bat, ripgrep, zoxide, eza, dua-cli, git-delta
- **Cursor IDE**

### Launchers

- Elephant launcher and plugins
- Walker, Impala

## Workflow

### Creating a New Hyprland Machine

```bash
# 1. Create host directory with marker
mkdir -p hosts/newmachine
touch hosts/newmachine/.hyprland

# 2. Add the host to infra/ansible/inventory/hosts.yml and host_vars.
# Hyprland, NetBird, and system DNS state are Ansible-owned on managed hosts.

# 3. Verify inventory membership and task graph from repo root
ansible-inventory -i infra/ansible/inventory/hosts.yml --host newmachine
infra/ansible/run-playbook.sh infra/ansible/playbooks/site.yml --limit newmachine --list-tasks

# 4. Run managed system bring-up
infra/ansible/run-playbook.sh infra/ansible/playbooks/site.yml --limit newmachine
```

### Creating a Non-Hyprland Machine

Keep the host out of the Hyprland inventory group and omit Hyprland user-state
manifest coverage:

```bash
# Server/minimal setup - no Hyprland needed
mkdir -p hosts/server
```

## Benefits

### ✅ Low Maintenance

- No hardcoded arrays to update
- Add hosts by updating inventory and host vars
- Validation fails when declarations are missing

### ✅ Self-Documenting

- Marker files document intended Hyprland support
- Ansible list-task output shows what will run
- Documentation explains the system

### ✅ Explicit

- Inventory and host vars are the source of truth
- Marker files document intent, not runtime fallback behavior
- Missing declarations fail validation instead of silently guessing

### ✅ Safe

- Explicit inventory and host vars prevent accidental role selection
- Verification before installation through inventory and list-task checks
- Clear ownership through Ansible groups and host vars

## Troubleshooting

### Host Not Declared as Hyprland

**Check inventory and task graph:**

```bash
ansible-inventory -i infra/ansible/inventory/hosts.yml --host YOUR_HOST
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --limit YOUR_HOST --list-tasks
```

**Fix:**

```bash
# Add marker file as documentation
touch hosts/YOUR_HOST/.hyprland

# Add or correct inventory and host vars, then verify task graph
ansible-inventory -i infra/ansible/inventory/hosts.yml --host YOUR_HOST
```

### Getting Hyprland Packages When You Don't Want Them

**Remove Hyprland inventory/host-var declarations and manifest coverage:**

```bash
# Optionally also remove the documentation marker.
rm hosts/YOUR_HOST/.hyprland
```

### Declaration Not Working

**Debug:**

```bash
# Check inventory and host vars
grep -n "YOUR_HOST" infra/ansible/inventory/hosts.yml
test -f infra/ansible/inventory/host_vars/YOUR_HOST.yml
```

## Technical Details

### Detection Contract

The managed-host control plane does not infer Hyprland from setup scripts or
documentation. A host is Hyprland-capable only when inventory/host vars declare
that desktop stack and the relevant chezmoi manifests cover its user state.

### Integration

Ansible inventory and `infra/chezmoi/manifests/*.manifest` are the runtime
sources for managed hosts. Legacy installer detection remains historical
context only.

## Migration Checklist

- [x] Create `.hyprland` marker files for existing hosts
- [x] Move managed-host detection to inventory and host vars
- [x] Document inventory/list-task verification path
- [x] Document the system
- [x] Test detection logic

## See Also

- [Host Configuration README](../hosts/README.md) - General host setup guide
- [Host model](architecture/host-model.md) - Inventory and capability ownership model
- [Ansible roles](../infra/ansible/roles/README.md) - Managed system-state roles

## References

- Inspired by the need for better ergonomics when adding new machines
- Follows the principle: "Configuration should be declarative, not imperative"
- Implements "Convention over Configuration" for common cases
