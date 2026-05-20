# MCP Edge Admin API

Use these APIs only from trusted internal operator contexts.

## Token Handling

Never print tokens. Load them inside SSH command scope:

```bash
ssh -o BatchMode=yes cool-res '
ADMIN_TOKEN="$(sudo cat /data/coolify/mcp-platform-secrets/mcp-control-plane-admin-token)"
docker run --rm --network coolify curlimages/curl:8.10.1 -fsS \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  http://mcp-control-plane:8081/v1/services
'
```

If admin calls return `admin_token_unavailable`, check:

1. `MCP_CONTROL_PLANE_ADMIN_TOKEN_PATH=/run/secrets/mcp-control-plane-admin-token`.
2. Compose mounts `/data/coolify/mcp-platform-secrets/mcp-control-plane-admin-token` to that path.
3. Host file exists and is readable by the container. `0444 root:root` works for the distroless control-plane image.

## Register Service

```bash
PUT /v1/services/<serviceID>
```

Payload:

```json
{
  "display_name": "Example MCP",
  "upstream_service_name": "example-mcp",
  "transport_type": "streamable-http",
  "internal_port": 8080,
  "public_path": "/example/mcp",
  "internal_upstream_path": "/mcp",
  "health_path": "/health",
  "health_probe_expectation": "GET returns OK",
  "resource_profile": "small",
  "persistence_policy": "stateless",
  "adapter_requirement": "none",
  "secret_contract": []
}
```

Rules:

- `serviceID` must be stable and URL-safe.
- Builtin services cannot be mutated through admin API.
- `public_path` must not overlap existing enabled service prefixes.
- Reserved prefixes are rejected: `/oauth`, `/.well-known`, `/health`, `/v1`.
- Paths reject `//`, backslashes, `?`, `#`, raw spaces, encoded slashes/backslashes, and dot segments.

Expected success includes `source=admin_api` and `enabled=true`.

## Grant Subject

```bash
PUT /v1/subjects/<subjectSub>/grants/<serviceID>
```

Optional payload can include:

```json
{
  "subject_key": "stable-key",
  "preferred_username": "user",
  "email": "user@example.com",
  "display_name": "User"
}
```

Manual grants coexist with Authentik-derived sources. Deleting a manual grant removes only the manual source; Authentik-derived grants remain if present.

## Bind Static Upstream

```bash
PUT /v1/subjects/<subjectSub>/services/<serviceID>/upstream
```

Payload:

```json
{
  "upstream_url": "http://example-mcp:8080"
}
```

Behavior:

- Subject must already have an effective grant.
- `upstream_url` supplies the origin: scheme, host, and port.
- Catalog `health_path` controls health check URL.
- Catalog `internal_upstream_path` controls proxied MCP request path.
- Health checks do not follow redirects.
- Literal or resolved unspecified, loopback, link-local, and multicast IPs are rejected.
- RFC1918/LAN targets are allowed because this is an admin-trusted self-hosted service path.

Common errors:

| Error | Meaning |
|---|---|
| `service_not_found` | Service missing or disabled. |
| `service_not_granted` | Subject lacks effective grant. |
| `upstream_healthcheck_failed` | Target failed catalog health check. |
| `upstream_url resolved ip address is not allowed` | Host resolved to blocked IP class. |

## Cleanup

```bash
DELETE /v1/subjects/<subjectSub>/grants/<serviceID>
DELETE /v1/services/<serviceID>
```

After cleanup, wait for edge catalog refresh and verify the service disappears from root discovery.
