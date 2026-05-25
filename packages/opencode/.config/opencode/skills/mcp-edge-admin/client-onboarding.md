# MCP Client Onboarding

## Client Model

Clients connect to per-service edge URLs, not tenant containers:

| Service | URL | Scope | Resource |
|---|---|---|---|
| Mealie | `https://mcp.zacariahheim.com/mealie/mcp` | `mcp:mealie` | same as URL |
| Actual | `https://mcp.zacariahheim.com/actualbudget/mcp` | `mcp:actualbudget` | same as URL |
| Memory | `https://mcp.zacariahheim.com/memory/mcp` | `mcp:memory` | same as URL |
| Penpot | `https://mcp.zacariahheim.com/penpot/mcp` | `mcp:penpot` | same as URL |

Dynamic services follow:

```text
https://mcp.zacariahheim.com/<service-path>
scope=mcp:<serviceID>
resource=https://mcp.zacariahheim.com/<service-path>
```

## OAuth Facts

- Edge is the OAuth authorization server for MCP clients.
- Authentik is the human browser login provider and RBAC sync source.
- Clients must use authorization code + PKCE S256.
- Clients must include RFC 8707 `resource` on authorize and token requests.
- Edge-issued tokens are opaque and resource-bound.
- Authentik access tokens are not accepted at MCP service paths.
- Do not put edge access tokens in opencode `headers`, environment variables, shell wrappers, or project config.

## DCR Modes

Default production: `MCP_EDGE_DCR_ENABLED=false`.

That means `/oauth/register` requires the edge operator bearer token unless public DCR is explicitly enabled.

Supported onboarding modes:

1. Operator pre-registration with `/oauth/register` and operator token.
2. Public DCR only when deliberately enabled.
3. CIMD only when deliberately enabled and SSRF posture is accepted.
4. Credential-managed automation clients for operator-issued scoped tokens.

## opencode

Preferred OAuth-capable remote config with pre-registered client:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "mealie": {
      "type": "remote",
      "url": "https://mcp.zacariahheim.com/mealie/mcp",
      "enabled": true,
      "oauth": {
        "clientId": "<pre-registered-client-id>",
        "scope": "mcp:mealie"
      }
    }
  }
}
```

Public-DCR variant, only when intentionally enabled on the edge:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "mealie": {
      "type": "remote",
      "url": "https://mcp.zacariahheim.com/mealie/mcp",
      "enabled": true,
      "oauth": {
        "scope": "mcp:mealie"
      }
    }
  }
}
```

Headless/device behavior is client-owned. If opencode is running without a loopback browser and the edge advertises `urn:ietf:params:oauth:grant-type:device_code`, opencode should use the OAuth device authorization endpoint, display the verification URL/user code, and store tokens internally. The config remains the native `oauth` block above; do not paste device-flow access tokens into headers.

Penpot-specific note: the DragonServer Penpot service uses Penpot's official MCP server behind MCP Edge. Clients still connect to `https://mcp.zacariahheim.com/penpot/mcp` with `mcp:penpot`, but design-file tools require the Penpot browser UI to have a file open and **File -> MCP Server -> Connect** active. The expected official tools are `high_level_overview`, `penpot_api_info`, `execute_code`, and `export_shape`.

Operator-issued scoped tokens are not a static `headers` fallback for opencode. Use them only through a credential-managed plugin or local MCP bridge that keeps credentials outside config and environment:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "mealie": {
      "type": "local",
      "command": ["mcp-edge-credential-bridge", "--service", "mealie"],
      "enabled": true
    }
  }
}
```

## Cursor

Preferred remote config:

```json
{
  "mcpServers": {
    "mealie": {
      "url": "https://mcp.zacariahheim.com/mealie/mcp"
    }
  }
}
```

Pre-registered OAuth config if supported by the installed Cursor version:

```json
{
  "mcpServers": {
    "mealie": {
      "url": "https://mcp.zacariahheim.com/mealie/mcp",
      "auth": {
        "CLIENT_ID": "<pre-registered-client-id>",
        "CLIENT_SECRET": "<optional-client-secret>",
        "scopes": ["mcp:mealie"]
      }
    }
  }
}
```

## Manual Desktop Smoke Flow

1. Discover `GET /` and record service `url`, `resource`, `scope`, and PRM URL.
2. Register client with loopback redirect `http://127.0.0.1:<port>/oauth/callback`.
3. Start authorize request with `scope`, matching `resource`, and PKCE S256.
4. Login through Authentik.
5. Exchange code at `/oauth/token` with same `resource` and verifier.
6. Introspect token with operator token.
7. Call service URL with `Authorization: Bearer <access-token>`.

Expected:

- Introspection `active=true`.
- `scope` and `resource` match service.
- Service route works.
- Another service route fails with `403 insufficient_scope`.
