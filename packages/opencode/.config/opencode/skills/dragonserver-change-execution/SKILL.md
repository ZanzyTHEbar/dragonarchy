---
name: dragonserver-change-execution
description: Execute controlled mutations on DragonServer infrastructure with preflight checks, one-change-at-a-time execution, validation gates, and rollback discipline. Covers Coolify service/env updates, container redeploys, and Proxmox-side operational changes. Use when the user asks to deploy, update, restart, patch, reconfigure, or fix running DragonServer services.
---

# DragonServer Change Execution

Use this skill for mutating operations only.
For discovery and audits, use `dragonserver-access` first.

## Scope

This skill governs safe execution for:
- Coolify service/env changes
- Docker container restarts or recreates on `cool-res`
- Proxmox/systemd operations on `lan-proxmox`
- Controlled config fixes with explicit rollback

## Hard Gates (Must Pass)

1. **Explicit approval:** user clearly requested a change.
2. **Target certainty:** host + service UUID/container identified.
3. **Baseline captured:** current health/config state recorded.
4. **Rollback ready:** rollback path written before mutation.
5. **Success checks defined:** objective verification criteria listed.

If any gate fails, stop and resolve before changing anything.

## Channel Selection

| Change Type | Preferred Channel |
|---|---|
| Service metadata / compose updates | Coolify REST API |
| Env var lifecycle and deploy actions | Coolify CLI |
| Runtime-level Docker interventions | SSH `cool-res` |
| Host services, timers, Proxmox ops | SSH `lan-proxmox` |

## Execution Workflow

### 1) Preflight

- Restate requested change in one sentence.
- Identify blast radius (single service vs shared infra).
- Confirm maintenance impact (none, brief restart, or degraded period).

### 2) Baseline Snapshot

- Record current service status and recent health signals.
- Save relevant config/state values needed for rollback.
- Capture exact target identifiers (service UUID, container name, unit name).

### 3) Apply One Atomic Change

- Perform one bounded mutation only.
- Avoid batching unrelated edits.
- Prefer deterministic commands over interactive flows.

### 4) Verify Immediately

- Run channel-appropriate verification checks.
- Confirm both technical health and expected functional behavior.
- If checks fail, rollback immediately.

### 5) Closeout

- Report changed surface area.
- Include current status and residual risks.
- List next recommended step (if any).

## Output Template

```markdown
## DragonServer Change Report

- Requested change: [single sentence]
- Target: [host/service]
- Channel: [coolify-cli | coolify-api | lan-proxmox | cool-res]
- Baseline: [what was captured]
- Mutation applied: [exact high-level action]
- Verification: [checks + result]
- Rollback status: [not needed | ready | executed]
- Residual risks: [if any]
- Next step: [ordered action]
```

## Non-Negotiables

1. Never expose secrets in logs or summaries.
2. Never perform unrelated cleanups during a change task.
3. Never proceed to a second mutation if first verification is incomplete.
4. Prefer reversible operations over destructive ones.

## Progressive Disclosure References

- [change-workflows.md](change-workflows.md): channel-specific change recipes.
- [verification-matrix.md](verification-matrix.md): required checks by change type.
- [rollback-playbooks.md](rollback-playbooks.md): quick rollback patterns.
