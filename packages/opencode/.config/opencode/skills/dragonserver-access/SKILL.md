---
name: dragonserver-access
description: Access and operate DragonServer safely through SSH aliases (`lan-proxmox`, `cool-res`), Coolify CLI/API, and browser workflows. Includes read-only audit defaults, mutation gates, and validation patterns for Proxmox, Docker, and self-hosted services. Use when the user mentions dragonserver, lan-proxmox, cool-res, coolify, proxmox, authentik, opencloud, joplinsync, or asks to audit/configure server services.
---

# DragonServer Access

Use this skill as the default operating guide for anything touching the DragonServer homelab.

## Quick Start

1. Identify objective and risk level (audit vs change).
2. Choose one access channel from the matrix below.
3. Run connectivity and target verification checks.
4. Execute read-only reconnaissance first.
5. Route mutation tasks to `dragonserver-change-execution` after explicit user approval.

## Access Channel Matrix

| Channel | Best for | Primary Entry |
|---|---|---|
| SSH to `lan-proxmox` | Proxmox host, ZFS, systemd, hardware-level audit | `ssh -o BatchMode=yes lan-proxmox "<command>"` |
| SSH to `cool-res` | Docker workloads, container logs, runtime introspection | `ssh -o BatchMode=yes cool-res "<docker command>"` |
| Coolify CLI | Service discovery, deploy actions, env management | `coolify service ...` |
| Coolify REST API | Structured service metadata and compose-level updates | `/api/v1/services/{uuid}` |
| Browser | UI-only flows in Coolify/Auth/admin panels | Browser MCP tools |

## Operating Rules

1. **Read-only by default.** Do not mutate infra without explicit instruction.
2. **Host certainty first.** Confirm whether the task belongs on `lan-proxmox` or `cool-res` before running commands.
3. **Non-interactive commands.** Prefer `BatchMode=yes` and deterministic commands suitable for automation.
4. **No secret leakage.** Redact tokens, passwords, and credential-like values in outputs and summaries.
5. **Validate after every change.** Any mutation requires a post-change health check and concise rollback note.
6. **Preserve SSH config.** NEVER add `-F /dev/null` to SSH commands — it disables `~/.ssh/config`, breaking host aliases and identity file resolution. If system SSH config causes issues, use `-F ~/.ssh/config` to read only the user config. NEVER add `-o StrictHostKeyChecking=no` unless connecting to a genuinely unknown host for the first time.

## Workflow

### 1) Preflight

- Confirm intended scope and whether changes are allowed.
- Verify channel access (SSH alias or API context).
- Capture baseline state relevant to the task.

### 2) Reconnaissance

- Gather minimum data needed to answer the request.
- Prefer structured output (`--format`, JSON, clear markers).
- Record constraints and unknowns early.

### 3) Change Execution (Only if explicitly requested)

- Stage one bounded change.
- Validate immediately.
- If validation fails, rollback and report.

### 4) Closeout

- Report what was checked, what changed (if anything), and current status.
- List concrete next actions with risk level.

## Output Template

Use this response structure for DragonServer tasks:

```markdown
## DragonServer Task Report

- Scope: [audit/change]
- Channel: [lan-proxmox | cool-res | coolify-cli | coolify-api | browser]
- Target: [host/service]
- Actions run: [high-level command summary]
- Findings: [key results]
- Risks/unknowns: [if any]
- Next steps: [ordered list]
```

## Progressive Disclosure References

- [access-map.md](access-map.md): host map, service map, and known endpoints.
- [command-recipes.md](command-recipes.md): proven command patterns by channel.
- [safety-guardrails.md](safety-guardrails.md): mutation policy, redaction policy, and rollback checklist.
- Companion skill: `dragonserver-change-execution` for mutating operations.
