---
name: teleport-infra-connect
description: Connects to company infrastructure via Teleport (tsh CLI or Web UI). Covers login, SSH to nodes, connection path (Proxy → Auth → Node), and access patterns. Use when connecting to remote machines, using Teleport, tsh, SSH through Teleport, or accessing company infrastructure.
---

# Teleport Infrastructure Connect

Connect to company infrastructure through Teleport. You never SSH directly to a host; all access is **you → Proxy → Node (on remote machine)**.

## When to use this skill

- User wants to SSH into a server or "remote machine" at work
- User mentions Teleport, `tsh`, or "company infra"
- User needs to run commands on internal hosts or debug connectivity
- User asks how access to company infrastructure works

## Quick startaction-runner-orchestrator

1. **Login once** (SSO, local user, or MFA via Proxy):
   ```bash
   tsh login --proxy=teleport.example.com
   ```
   Or with Web UI: open the Proxy URL in a browser and authenticate.

2. **List available nodes** (machines you can reach):
   ```bash
   tsh ls
   ```

3. **SSH to a node** (by label or hostname):
   ```bash
   tsh ssh user@node-name
   ```
   Replace `user` with your OS user on that host; `node-name` is the Teleport node name (from `tsh ls`).

4. **Run a single command** without an interactive shell:
   ```bash
   tsh ssh user@node-name -- command here
   ```

## Company infrastructure (Avular)

**Login** (password + OTP):

```bash
tsh login --proxy=https://teleport.avular.dev --user=z.heim
```

You’ll be prompted for Teleport password and an OTP code. Successful login looks like:

```
Profile URL:        https://teleport.avular.dev:443
Logged in as:       z.heim
Cluster:            avular_robots
Roles:              avular-developer, avular-devops
Logins:             avular, root, infrastructure, github
Kubernetes:         enabled
Valid until:        <timestamp> [valid for 7h59m]
Extensions:         login-ip, permit-agent-forwarding, permit-pty, private-key-policy
```

**Allowed OS logins** (use one of these as the SSH user on nodes): `avular`, `root`, `infrastructure`, `github`.

**Then:**

```bash
tsh ls                                    # list nodes
tsh ssh avular@<node-name>                # or root, infrastructure, github
tsh ssh avular@<node-name> -- <command>   # one-off command
```

Certs are short‑lived (~8h); re-run `tsh login` when expired or after logout.

## Connection model (essential)

| Step | What happens |
|------|----------------|
| You run `tsh ssh user@node` | `tsh` talks to the **Proxy** (HTTPS) |
| Proxy | Checks identity/roles with **Auth Server**, issues short‑lived cert |
| Proxy | Connects to **Node** (Teleport agent on the remote machine) |
| Node | Already enrolled with Auth; keeps tunnel to Proxy |
| Result | SSH session flows: you ↔ Proxy ↔ Node; no direct TCP to host:22 |

You do **not** connect to the host’s IP:22. Teleport (Proxy + Auth) gates all access; the "remote machine" is the host where the Teleport Node (SSH service) runs.

## Workflow checklist

Use this when guiding a user or debugging connection issues:

```
- [ ] Teleport CLI installed (`tsh` in PATH)
- [ ] Logged in: `tsh login --proxy=<proxy>` (or Web UI)
- [ ] Node visible: `tsh ls` shows target host
- [ ] SSH: `tsh ssh <user>@<node>` (user = OS user on node)
- [ ] For one-off commands: `tsh ssh user@node -- cmd`
```

## Common issues

| Problem | Check / fix |
|--------|-------------|
| "node not found" or empty `tsh ls` | Confirm login (`tsh status`), correct proxy, and roles that grant access to that node |
| Permission denied (SSH) | Use the OS username that exists on the **remote** host, not your Teleport username |
| Proxy unreachable | Verify `--proxy` host/port and network (VPN, firewall) |
| Cert expired | Run `tsh login` again to refresh short‑lived certs |

## Resources (progressive disclosure)

- **Architecture and components**: See [reference.md](reference.md) for Proxy, Auth Server, Node, and the full connection path.
- **Commands and troubleshooting**: See [commands.md](commands.md) for full `tsh` command set, scp, port forwarding, and troubleshooting steps.

## Output format when helping

When explaining Teleport access to a user:

1. State that access goes through Teleport (no direct SSH to host IP).
2. Give the exact `tsh login` and `tsh ssh` commands with their proxy/node names if known.
3. If something fails, walk through the checklist (login → `tsh ls` → `tsh ssh`) and point to [commands.md](commands.md) for deeper troubleshooting.

For **Avular** company infra use: proxy `https://teleport.avular.dev`, cluster `avular_robots`, and allowed logins `avular`, `root`, `infrastructure`, `github`. For other clusters, use placeholders or ask for proxy and node names.
