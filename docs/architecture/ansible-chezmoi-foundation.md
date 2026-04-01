# Ansible + chezmoi Foundation

## Purpose

This document defines the foundation of the new control plane and how that foundation extends into the currently implemented hot-path migration work.

The approved architecture is a clean break:

- Ansible owns system state.
- chezmoi owns user state.
- fallback logic is forbidden.

The foundation batch exists to establish explicit ownership, explicit host identity, and explicit execution boundaries before any hot-path migration begins.

That foundation is no longer hypothetical in this branch.

The current branch now includes:

- the foundation control-plane skeleton
- hot-path tranches `1` through `5`
- the first chezmoi generated-source and cutover-control-plane tooling

## Foundation scope

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

Those exclusions apply to the foundation batch itself.

They do not describe the current branch as a whole, because later hot-path tranches and the first chezmoi migration-control tooling are now implemented.

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

The current execution entrypoint remains intentionally simple:

- `playbooks/foundation.yml` enforces the shared contract directly
- `playbooks/site.yml` is the main entrypoint and currently routes through `hot-path-tranche-5.yml`

The effective playbook chain is:

1. `foundation.yml`
2. `hot-path-tranche-1.yml`
3. `hot-path-tranche-2.yml`
4. `hot-path-tranche-3.yml`
5. `hot-path-tranche-4.yml`
6. `hot-path-tranche-5.yml`
7. `site.yml`

## Design constraints

- fail fast on unsupported platforms
- fail fast on missing host metadata
- no best-effort continuation on core paths
- one owner per responsibility
- one source of truth per host
