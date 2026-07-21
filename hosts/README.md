# Host-Specific Configurations

This directory contains host-specific source payloads and legacy reference material for machines modeled by the dotfiles repository.

## Runtime Source Of Truth

Managed hosts are declared in Ansible, not inferred from this directory.

Current runtime authority lives in:

- `infra/ansible/inventory/hosts.yml`
- `infra/ansible/inventory/host_vars/<host>.yml`
- `infra/ansible/inventory/group_vars/*.yml`

Use `./install --host <hostname>` for managed-host convergence. Use `./infra/validate-parity.sh --host <hostname>` for read-only parity checks.

## Directory Structure

```bash
hosts/
├── desktop/          # Generic desktop / Hyprland validation profile
├── dragon/           # AMD desktop workstation
├── firedragon/       # ASUS VivoBook AMD laptop
├── goldendragon/     # Lenovo ThinkPad P16s (Intel/NVIDIA)
├── headless/         # Generic terminal-only/headless profile
├── microdragon/      # Debian server profile
├── opencode-runtime/ # Headless OpenCode container runtime
└── shared/           # Shared host resources
```

## Creating Or Updating A Managed Host

1. Add the host to `infra/ansible/inventory/hosts.yml` under the correct platform, role, and execution groups.
2. Add `infra/ansible/inventory/host_vars/<host>.yml` with `host_role`, `host_platform_family`, `host_desktop_stack`, `host_gpu_stack`, `host_capabilities`, `managed_users`, and `legacy_host_directory`.
3. Put host-specific system payloads under `hosts/<host>/etc/` only when an Ansible role consumes them explicitly.
4. Put host-specific user payloads under `hosts/<host>/dotfiles/` only when a chezmoi manifest consumes them explicitly.
5. Validate with `ansible-inventory` and `./infra/validate-parity.sh --host <host>`.

## Legacy Reference Files

These files can remain useful for parity analysis and emergency recovery, but they are not runtime authority in the new architecture:

- `hosts/<host>/.traits`
- `hosts/<host>/.hyprland`
- `hosts/<host>/HYPRLAND`
- `hosts/<host>/setup.sh`

Do not add new behavior by teaching scripts to infer state from these files. Add explicit inventory variables, groups, role defaults, or manifest entries instead.

## Capability Model

Inventory groups are execution selectors. Host variables describe identity and capabilities.

Examples:

- `host_role: desktop`, `laptop`, or `server`
- `host_platform_family: arch` or `debian`
- `host_desktop_stack: hyprland` or `none`
- `host_gpu_stack: [amd-gpu]`, `[intel, nvidia]`, or `[]`
- `host_capabilities: [tlp, fingerprint, fortinet_vpn]`

Some groups are rollout selectors rather than permanent host traits. For example, `resolved`, `sddm`, and `v4l2loopback` are inventory-owned execution groups unless host-model docs say otherwise.

## Payload Ownership

System payloads:

- Must be copied, templated, enabled, or validated by an Ansible role.
- Must not rely on `hosts/<host>/setup.sh` as the active owner.

User payloads:

- Must be referenced by `infra/chezmoi/manifests/*.manifest`.
- Are synced through `infra/chezmoi/bin/chezmoi-sync` and applied by chezmoi.

Runtime-generated files:

- Must stay out of manifests unless ownership is explicitly changed.
- Examples include theme-manager outputs, caches, clipboard history, and systemd user `*.target.wants` symlinks.

## Verification

```bash
ansible-inventory -i infra/ansible/inventory/hosts.yml --host <hostname>
./infra/validate-parity.sh --host <hostname>
```

For syntax-only Ansible validation:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/foundation.yml --syntax-check
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check
```

## Troubleshooting

If a managed host receives the wrong behavior, inspect these first:

1. Inventory group membership in `infra/ansible/inventory/hosts.yml`.
2. Host variables in `infra/ansible/inventory/host_vars/<host>.yml`.
3. Role defaults and validation for the role that should own the behavior.
4. Chezmoi manifests if the issue is user state.

Only use legacy host setup scripts for historical diagnosis or explicit recovery work.
