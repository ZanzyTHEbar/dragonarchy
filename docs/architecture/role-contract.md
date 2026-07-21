# Ansible Role Contract

## Purpose

This contract keeps the new control plane deterministic and prevents drift.

## Required properties

Every role must define:

- what it owns
- which platforms it supports
- which variables it requires
- how it validates its result

## Required behavior

1. A role must fail if required inputs are missing.
2. A role must fail on unsupported platforms.
3. A role must not silently continue after a core failure.
4. A role must not manage files, services, or packages owned by another role.
5. A role must keep templates, files, handlers, and tasks scoped to its own concern.

## Required file layout

```text
roles/<role>/
  defaults/main.yml
  tasks/main.yml
  handlers/main.yml
  meta/main.yml
```

Optional additions such as `templates/`, `files/`, `vars/`, and split task files are introduced only when needed.

## Foundation role

The `common` role exists only to enforce the foundation contract.

It currently owns:

- architecture assertions
- host metadata assertions
- deterministic host summary output

It does not yet own packages, services, or configuration files.

## Deferred until hot paths

These are intentionally not implemented in the foundation role:

- distro package maps
- `/etc` templates
- systemd handlers
- hardware behavior tasks
- display manager tasks
- user-state rendering
