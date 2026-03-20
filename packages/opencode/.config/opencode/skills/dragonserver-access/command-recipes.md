# DragonServer Command Recipes

Use these as stable starting patterns.
Prefer read-only variants unless the user explicitly asks for changes.

## SSH Flag Policy

**Canonical pattern:** `ssh -o BatchMode=yes <alias> "<command>"`

**NEVER use these flags:**
- `-F /dev/null` — destroys `~/.ssh/config`, breaking aliases (`cool-res`, `lan-proxmox`) and identity files
- `-o StrictHostKeyChecking=no` — masks host key issues and is unnecessary for known infrastructure

**If system SSH config causes errors** (e.g., symlink permissions in `/etc/ssh/ssh_config.d/`):
```bash
ssh -o BatchMode=yes -F ~/.ssh/config cool-res "<command>"
```
This reads ONLY the user config, bypassing system config while preserving all aliases and identity files.

## 1) Connectivity and Identity

```bash
ssh -o BatchMode=yes lan-proxmox "hostname && uname -a"
ssh -o BatchMode=yes cool-res "hostname && uname -a"
```

## 2) Proxmox Host Recon (`lan-proxmox`)

```bash
ssh -o BatchMode=yes lan-proxmox "pveversion -v"
ssh -o BatchMode=yes lan-proxmox "pct list && qm list"
ssh -o BatchMode=yes lan-proxmox "zpool status -v && zfs list"
ssh -o BatchMode=yes lan-proxmox "systemctl list-timers --no-pager"
```

## 3) Docker Runtime Recon (`cool-res`)

```bash
ssh -o BatchMode=yes cool-res "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"
ssh -o BatchMode=yes cool-res "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'"
ssh -o BatchMode=yes cool-res "docker inspect <container-name> --format '{{json .Config.Env}}'"
```

## 4) Locate Service Containers by Prefix

```bash
ssh -o BatchMode=yes cool-res "docker ps --format '{{.Names}}' | grep '^authentik-server-'"
ssh -o BatchMode=yes cool-res "docker ps --format '{{.Names}}' | grep '^joplin-'"
```

## 5) Coolify CLI Patterns (Local Workstation)

```bash
coolify instance ls
coolify service list --format=json
coolify service get <service-uuid> --format=json
coolify service env list <service-uuid> --format=json
```

## 6) Coolify API Read Pattern (Python)

```python
import json
import urllib.request
from pathlib import Path

cfg = json.loads(Path("/home/daofficialwizard/.config/coolify/config.json").read_text())
ctx = next(i for i in cfg["instances"] if i.get("name") == "dragonnest")
base = ctx["fqdn"].rstrip("/")
token = ctx["token"]

url = f"{base}/api/v1/services/<service-uuid>"
req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
with urllib.request.urlopen(req) as resp:
    data = json.load(resp)

print(data.get("uuid"), data.get("name"))
```

## 7) Authentik Introspection from Resource Host

```bash
ssh -o BatchMode=yes cool-res "docker exec authentik-server-<service-uuid> ak --help"
ssh -o BatchMode=yes cool-res "docker exec authentik-server-<service-uuid> ak shell -c \"from authentik.core.models import Application; print(Application.objects.count())\""
```

For deep Authentik workflows, use the dedicated Authentik skill if available.

## 8) Minimal Post-Change Verification Pattern

```bash
# Re-check runtime status
ssh -o BatchMode=yes cool-res "docker ps --format 'table {{.Names}}\t{{.Status}}'"

# Re-check host side if relevant
ssh -o BatchMode=yes lan-proxmox "systemctl --failed --no-pager"
```
