# DragonServer Change Workflows

These are mutation workflows.
Run baseline checks before each workflow.

## 1) Coolify Env Variable Change

Preferred path: Coolify CLI env commands.

1. List env vars for target service.
2. Identify target key and current state.
3. Apply a single env update.
4. Trigger deploy/restart if required.
5. Verify service health.

Starter commands:

```bash
coolify service env list <service-uuid> --format=json
coolify service env update <service-uuid> <env-uuid> "<key>" "<value>"
coolify deploy name <service-name>
```

Notes:
- In some Coolify versions, direct API env PATCH routes may be unreliable.
- Prefer CLI env operations first when available.

## 2) Coolify Compose/Service Patch

Use API when compose-level edits are required.

1. Read current service payload.
2. Build minimal patch with only required field changes.
3. Submit patch.
4. Validate runtime state and app behavior.

Pattern:

```python
# Read current service metadata first
GET /api/v1/services/<service-uuid>

# Patch only necessary fields
PATCH /api/v1/services/<service-uuid>
```

Guardrails:
- Do not submit partial payloads blindly.
- Preserve required fields returned by current service metadata.

## 3) Runtime Restart or Recreate (`cool-res`)

Use when service is healthy-configured but runtime is stale/hung.

```bash
ssh -o BatchMode=yes cool-res "docker ps --format 'table {{.Names}}\t{{.Status}}'"
ssh -o BatchMode=yes cool-res "docker restart <container-name>"
ssh -o BatchMode=yes cool-res "docker logs --tail=80 <container-name>"
```

Guardrails:
- Restart one container at a time.
- Re-check dependent containers after restart.

## 4) Proxmox / Host Service Change (`lan-proxmox`)

Use for timers/services owned by host OS.

```bash
ssh -o BatchMode=yes lan-proxmox "systemctl status <unit> --no-pager"
ssh -o BatchMode=yes lan-proxmox "systemctl restart <unit>"
ssh -o BatchMode=yes lan-proxmox "journalctl -u <unit> -n 100 --no-pager"
```

Guardrails:
- Confirm unit ownership and purpose before restart.
- Verify no new failed units appear post-change.

## 5) Sequencing Rule

For multi-part requests, execute in this order:
1. Config mutation
2. Deploy/restart
3. Health checks
4. Functional checks
5. Optional follow-up tuning
