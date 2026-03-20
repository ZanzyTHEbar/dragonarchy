# DragonServer Safety Guardrails

## 1) Change Policy

Default mode is read-only.
Treat every task as audit-only unless the user explicitly requests mutation.

Allowed without extra confirmation:
- Inventory and status checks
- Read-only logs and metadata inspection
- Configuration diff/review

Require explicit user approval:
- Service restarts/redeploys
- Environment variable updates
- Compose/service patch operations
- File edits on remote hosts
- Data migration or deletion

## 2) Secret Hygiene

Never expose or echo:
- API tokens
- Passwords
- Private keys
- Session cookies
- Full environment variable values when sensitive

Redaction rules:
- Show key names and high-level state (`set` / `missing`) instead of values.
- If a secret appears in command output, mask it before reporting.

## 3) Host and Scope Validation

Before running any command:
1. Confirm target host (`lan-proxmox` vs `cool-res`).
2. Confirm target service/container identifier.
3. Confirm whether the requested operation is read-only or mutating.

If host mapping is ambiguous, stop and resolve ambiguity before execution.

## 4) Mutation Checklist

Before:
- Capture baseline state (status, relevant config, health snapshot).
- Identify rollback command/path.

During:
- Make one bounded change at a time.
- Validate immediately after each change.

After:
- Confirm service health and expected behavior.
- Report exact changed surface area.
- Report rollback instructions and whether rollback is required.

## 5) Failure Handling

If a command fails:
1. Do not stack speculative fixes.
2. Collect error details and context.
3. Re-check assumptions (host, service UUID, permissions, API route).
4. Propose the smallest next diagnostic step.

If mutation causes degradation:
1. Execute rollback.
2. Verify restoration.
3. Report root cause hypothesis and next safe path.

## 6) Reporting Standard

Every DragonServer report should include:
- Scope (`audit` or `change`)
- Host/channel used
- What was verified
- What changed (if anything)
- Current risk/unknowns
- Next actions in priority order
