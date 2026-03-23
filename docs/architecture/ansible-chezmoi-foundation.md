# Ansible + chezmoi Foundation

## Purpose

This document defines the foundation batch for the new control plane.

The approved architecture is a clean break:

- Ansible owns system state.
- chezmoi owns user state.
- fallback logic is forbidden.

The foundation batch exists to establish explicit ownership, explicit host identity, and explicit execution boundaries before any hot-path migration begins.

## Scope

Foundation includes:

- Ansible control-plane skeleton
- explicit inventory for current real hosts
- host variable contract
- initial shared role contract
- chezmoi source-root skeleton
- architecture documentation

Foundation excludes:

- hot-path role migration
- package parity work
- `/etc` migration
- service migration
- user dotfile migration
- secrets migration
- CI and full automation wiring

## Control-plane layout

```text
infra/
  ansible/
    ansible.cfg
    requirements.yml
    inventory/
    playbooks/
    roles/
  chezmoi/
```

## Ownership matrix

### Ansible owns

- package installation
- `/etc`
- services
- host behavior
- desktop/laptop/server composition
- hardware-specific orchestration
- validation of system state

### chezmoi owns

- files in `$HOME`
- host-aware user config rendering
- user-level secrets-backed files
- machine-to-machine user configuration differences

### Explicit non-goals for chezmoi

- system package installation
- service management
- `/etc`
- hardware state

## Host identity rules

1. Inventory hostnames are the source of truth.
2. `host_vars/<host>.yml` is the source of truth for host metadata.
3. Legacy host directories remain reference material, not the future runtime model.
4. Host capabilities must never be inferred from docs or shell code in the new architecture.

## Execution model

The long-term execution order remains:

1. foundation
2. hot paths
3. edge cases
4. review
5. iterate

Current playbook graph is intentionally minimal:

- `playbooks/foundation.yml`
- `playbooks/site.yml`

## Design constraints

- fail fast on unsupported platforms
- fail fast on missing host metadata
- no best-effort continuation on core paths
- one owner per responsibility
- one source of truth per host
