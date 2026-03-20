# DragonServer Verification Matrix

Use this matrix immediately after every mutation.

## Verification by Change Type

| Change Type | Minimum Technical Checks | Functional Check |
|---|---|---|
| Env var update | Service/container is running; no crash loop; recent logs contain no fatal errors | Target feature reads new config correctly |
| Compose/service patch | Service deploy completed; expected container set matches desired state | Endpoint/UI path behaves as expected |
| Container restart | Container returns to healthy running state; dependencies remain healthy | User-facing action works after restart |
| Host unit restart | `systemctl` reports active; no new failed units | Scheduled or operational behavior resumes |

## Standard Health Checklist

1. Runtime status is healthy.
2. Error logs are checked for regression.
3. Dependency chain remains healthy.
4. Primary endpoint/action is tested.

## Quick Commands

```bash
# Docker runtime health
ssh -o BatchMode=yes cool-res "docker ps --format 'table {{.Names}}\t{{.Status}}'"
ssh -o BatchMode=yes cool-res "docker logs --tail=80 <container-name>"

# Host unit health
ssh -o BatchMode=yes lan-proxmox "systemctl status <unit> --no-pager"
ssh -o BatchMode=yes lan-proxmox "systemctl --failed --no-pager"
```

## Failure Criteria

Rollback is required if any of these occur:
- Service does not recover to running/healthy state.
- New fatal errors appear after the change.
- Core functional path is broken or degraded.
- Unexpected side effects appear in adjacent services.
