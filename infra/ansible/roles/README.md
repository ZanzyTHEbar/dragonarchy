# Ansible Role Contract

Every role in `infra/ansible/roles` must follow the same contract.

## Required properties

- explicit ownership
- explicit distro support
- explicit variables
- explicit validation
- no fallback logic
- no hidden side effects

## Required layout

```text
roles/<role>/
  defaults/main.yml
  tasks/main.yml
  handlers/main.yml
  meta/main.yml
```

Additional files like `templates/`, `files/`, `vars/`, and split task files are added only when the role actually needs them.

## Role rules

1. A role must own a clear concern.
2. A role must fail if required inputs are missing.
3. A role must not silently continue on unsupported platforms.
4. A role must not edit files or manage services that belong to another role.
5. A role must validate the state it is responsible for.

## Current foundation role

`common` is the only role in the foundation batch.

Its purpose is to:

- validate the shared architecture contract
- validate core host metadata
- expose a deterministic host summary

It does not install packages or manage services yet.
