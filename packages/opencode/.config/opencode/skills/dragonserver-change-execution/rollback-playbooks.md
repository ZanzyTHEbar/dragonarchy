# DragonServer Rollback Playbooks

These playbooks assume you captured baseline state before mutation.

## 1) Env Variable Rollback

1. Restore previous value for the changed key.
2. Redeploy/restart affected service.
3. Re-run verification matrix.

Commands:

```bash
coolify service env update <service-uuid> <env-uuid> "<key>" "<previous-value>"
coolify deploy name <service-name>
```

## 2) Service/Compose Rollback

1. Reapply last known-good compose/service payload.
2. Redeploy service.
3. Confirm target container topology and logs.

Guidance:
- Keep a copy of pre-change service payload whenever patching via API.
- Roll back by restoring that payload, not by ad hoc edits.

## 3) Runtime Rollback for Container Restart Failures

1. Inspect logs to identify immediate fault.
2. Revert triggering config change if present.
3. Restart container once after rollback.

Commands:

```bash
ssh -o BatchMode=yes cool-res "docker logs --tail=120 <container-name>"
ssh -o BatchMode=yes cool-res "docker restart <container-name>"
```

## 4) Host Unit Rollback

1. Revert config change that triggered host unit failure.
2. Reload daemon if unit files/config changed.
3. Restart unit and verify no failed units remain.

Commands:

```bash
ssh -o BatchMode=yes lan-proxmox "systemctl daemon-reload"
ssh -o BatchMode=yes lan-proxmox "systemctl restart <unit>"
ssh -o BatchMode=yes lan-proxmox "systemctl --failed --no-pager"
```

## 5) Incident Closeout Format

```markdown
## Rollback Report

- Triggering change: [what failed]
- Rollback action: [exact action]
- Verification result: [healthy/degraded]
- Remaining risk: [if any]
- Next safe step: [single action]
```
