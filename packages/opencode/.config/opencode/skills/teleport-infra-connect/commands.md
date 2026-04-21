# Teleport commands and troubleshooting

Reference for `tsh` and related workflows. Use when the user needs exact commands, copy/paste snippets, or step‑by‑step troubleshooting.

## Login

```bash
# Basic (prompts for auth method)
tsh login --proxy=teleport.example.com

# With user (if different from local username)
tsh login --proxy=teleport.example.com --user=alice

# Specific cluster (multi-cluster)
tsh login --proxy=teleport.example.com --cluster=prod
```

After login, `tsh` stores short‑lived certs. Re-run `tsh login` when they expire or after logout.

## Check status

```bash
# Am I logged in? Which proxy/user/cluster?
tsh status

# List nodes (machines) I can access
tsh ls

# List with labels
tsh ls -v
```

If `tsh ls` is empty, you’re either not logged in, on the wrong cluster, or your roles don’t grant access to any node.

## SSH

```bash
# Interactive shell (user = OS user on the remote host)
tsh ssh osuser@node-name

# Single command
tsh ssh osuser@node-name -- hostname
tsh ssh osuser@node-name -- "sudo systemctl status nginx"

# By node label (if supported)
tsh ssh osuser@node-name --labels env=prod
```

Use the **OS username** that exists on the remote host (e.g. `ubuntu`, `ec2-user`), not your Teleport/SSO username unless they’re the same.

## SCP (file copy)

```bash
# Copy from local to node
tsh scp ./local-file osuser@node-name:/remote/path/

# Copy from node to local
tsh scp osuser@node-name:/remote/path/file ./

# Recursive
tsh scp -r ./local-dir osuser@node-name:/remote/path/
```

## Port forwarding

```bash
# Forward remote port to local
tsh ssh -L 8080:localhost:80 osuser@node-name

# Then open http://localhost:8080 to reach the service on port 80 on the node
```

## Logout

```bash
tsh logout
```

Removes stored certs for that proxy/cluster. Run `tsh login` again to reconnect.

---

## Troubleshooting

### 1. “node not found” or empty `tsh ls`

- **Check login**: `tsh status` — must show logged in to the right proxy and cluster.
- **Check cluster**: If you have multiple clusters, `tsh login --cluster=<name>` and then `tsh ls`.
- **Check roles**: Your Teleport roles must allow access to the node (or its labels). Ask an admin if you expect access but don’t see nodes.

### 2. Permission denied (SSH)

- **Wrong user**: Use the OS user on the **remote** host (e.g. `ubuntu`, `ec2-user`), not your Teleport username.
- Example: `tsh ssh ubuntu@web-server-01`.

### 3. Proxy unreachable

- **Network**: VPN or corporate network may be required to reach the Proxy.
- **Proxy address**: Confirm `--proxy=host` or `host:port` with your team. No direct SSH to host IP; everything goes through Proxy.

### 4. Cert expired

- **Fix**: Run `tsh login` again. Teleport uses short‑lived certs; re-login refreshes them.

### 5. “access denied” or “role denied”

- Your Teleport role doesn’t grant access to that node or action. An admin must add the right role or node labels.

### 6. SCP or port-forward fails

- Same as SSH: ensure `tsh login`, correct OS user, and correct node name. For port-forward, ensure the remote service is listening on the expected address (e.g. `localhost:80` on the node).

---

## Quick reference

| Goal              | Command |
|-------------------|--------|
| Login             | `tsh login --proxy=<proxy>` |
| List nodes        | `tsh ls` |
| SSH               | `tsh ssh <osuser>@<node-name>` |
| Run one command   | `tsh ssh <osuser>@<node-name> -- <cmd>` |
| Copy file to node | `tsh scp ./file <osuser>@<node-name>:/path/` |
| Copy file from    | `tsh scp <osuser>@<node-name>:/path/file ./` |
| Port forward      | `tsh ssh -L local_port:localhost:remote_port <osuser>@<node-name>` |
| Logout            | `tsh logout` |
| Status            | `tsh status` |

Replace `<proxy>`, `<node-name>`, and `<osuser>` with your cluster’s proxy host, Teleport node name, and OS user on the remote host.
