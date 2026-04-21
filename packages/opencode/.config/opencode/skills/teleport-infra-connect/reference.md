# Teleport architecture and components

Reference for the Teleport infrastructure skill. Read this when you need detail on how components interact or how the connection path works.

## Components

### Teleport Proxy

- **Role**: Entry point for all client connections.
- **What hits it**: `tsh login`, `tsh ssh`, and Web UI traffic (browser).
- **Protocol**: HTTPS. Clients never speak raw SSH to the Proxy from the internet; they use the Teleport protocol (over HTTPS) or Web UI.
- **Behavior**: Accepts auth requests, talks to Auth Server to validate identity and roles, and issues short‑lived certificates. For SSH, it then connects to the appropriate Node (on the remote machine) and multiplexes the session.

### Teleport Auth Server

- **Role**: Central authority for identity and authorization.
- **Stores**: Roles, user attributes, node registrations, and issues short‑lived certs (SSH certs, etc.).
- **Used by**: Proxy (to validate login and authorize access to nodes). Nodes enroll with Auth at startup.
- **Not directly contacted by**: End users; they only talk to the Proxy (or Web UI, which talks to Proxy).

### Teleport Node (SSH service)

- **Role**: Agent running on each “remote machine” that you want to access.
- **Protocol**: Teleport protocol to the cluster (Proxy/Auth). The Node does **not** listen on the host’s traditional SSH port (22) for Teleport-originated sessions; Teleport uses its own channel (often a reverse tunnel from Node to Proxy).
- **Enrollment**: At startup, the Node authenticates to the Auth Server and registers. It keeps a connection (or reverse tunnel) to the Proxy so the Proxy can reach it.
- **SSH**: The Node can use the host’s OpenSSH under the hood or handle the session itself. From the user’s perspective, they run `tsh ssh user@node-name` and get a shell on that host.

### Client (you)

- **tsh**: CLI. Runs `tsh login` (once) and `tsh ssh user@node`, `tsh scp`, etc.
- **Web UI**: Browser to Proxy URL; authenticate there, then use the web-based SSH or other features.
- **Authentication**: Done once against the Proxy (e.g. SSO, local user, MFA). Auth Server returns short‑lived credentials; `tsh` stores and uses them until they expire.

## Connection path (step-by-step)

1. **Login**  
   You run `tsh login --proxy=teleport.example.com` (or use Web UI).  
   → Client (tsh or browser) talks to **Proxy** over HTTPS.  
   → Proxy checks **Auth Server** (identity, MFA, roles).  
   → Auth Server issues short‑lived certs.  
   → Client stores them (tsh) or session (Web UI).

2. **SSH to a node**  
   You run `tsh ssh user@remote-node`.  
   → `tsh` sends request to **Proxy** (HTTPS).  
   → Proxy checks **Auth Server**: is this user allowed to reach `remote-node`?  
   → Proxy gets or already has a path to **Node** on the remote machine (via Node’s tunnel or cluster routing).  
   → Proxy connects to **Node** (Teleport protocol).  
   → Node runs the SSH session (possibly using local OpenSSH).  
   → Your SSH stream flows: **you ↔ Proxy ↔ Node** (on the remote machine).  
   There is **no** direct TCP connection from your machine to the remote host’s port 22.

3. **In short**  
   All access is gated by Teleport (Proxy + Auth). The “remote machine” is the host where the Teleport Node (SSH service) is running. You never SSH directly to that host’s IP:22 from the client; Teleport connects you to the Node.

## Diagram (conceptual)

```
┌─────────────┐     HTTPS      ┌─────────────┐     Teleport protocol    ┌─────────────────────┐
│   Client    │ ◄─────────────► │   Proxy     │ ◄──────────────────────► │  Node (SSH service) │
│  tsh / Web  │   (login,      │  (entry     │   (session to node        │  on remote machine  │
│             │    ssh req)    │   point)    │    on remote host)       │                     │
└─────────────┘                └──────┬─────┘                           └─────────────────────┘
                                      │
                                      │ (auth, roles, certs)
                                      ▼
                               ┌─────────────┐
                               │ Auth Server │
                               │ (identity,  │
                               │  nodes)    │
                               └─────────────┘
```

## Terminology

- **Proxy** = Teleport Proxy = entry point for clients.  
- **Auth** = Auth Server = central authority.  
- **Node** = Teleport Node = agent on a “remote machine”; the thing you SSH to via `tsh ssh user@node-name`.  
- **Cluster** = Proxy + Auth (and optionally multiple Proxies). Nodes join the cluster.  
- **Short‑lived certs** = credentials issued by Auth after login; used by `tsh` (and Proxy) so you don’t type a password for every `tsh ssh`.

Use this reference when the user asks “how does Teleport work?” or when you need to explain the path from client to remote host.
