---
name: mcp-edge-admin
description: Administer the DragonServer MCP edge platform. Covers dynamic MCP service registration, manual grants, static upstream binding, OAuth/client onboarding, Coolify deploy order, E2E canaries, cleanup, troubleshooting, and production guardrails for opencode/Cursor-compatible MCP access. Use when the user mentions MCP edge, mcp-control-plane, mcp-edge, dynamic service registration, static upstreams, MCP OAuth, opencode/Cursor MCP clients, MCP service grants, or asks to deploy/fix/test the MCP platform.
---

# MCP Edge Administration

Use this skill for admin-agent work on the DragonServer MCP platform.

The platform is made of:
- `mcp-control-plane`: internal admin/reconcile service for service catalog, grants, tenants, and static upstream bindings.
- `mcp-edge`: public MCP OAuth/resource server and proxy at `https://mcp.zacariahheim.com`.
- Shared SQLite/libSQL state for catalog, OAuth clients/sessions, grants, and tenants.
- Authentik for browser identity and group-derived RBAC.

## Required Companion Skills

Load these when relevant:

- `dragonserver-access`: read-only DragonServer access and service discovery.
- `dragonserver-change-execution`: any deploy, env, token-file, restart, or runtime mutation.
- `authentik-admin`: Authentik users/groups/bundles/OIDC debugging.

## Hard Rules

1. Keep `mcp-control-plane` internal-only. Only `mcp-edge` receives the public domain.
2. Never print admin tokens, operator tokens, OAuth tokens, client secrets, or session material.
3. Do not expose `MCP_CONTROL_PLANE_ADMIN_TOKEN_PATH` endpoints publicly.
4. Run control-plane admin calls from `cool-res`, the `coolify` Docker network, or another trusted operator channel.
5. Deploy order is `mcp-platform-db` if needed, then `mcp-control-plane`, then `mcp-edge`.
6. Validate control-plane before deploying edge when DB schema/catalog behavior changes.
7. Cleanup canary services after E2E and verify discovery returns to builtin services only.

## Key Identifiers

Verify before mutation; these are current known targets:

| Target | Identifier |
|---|---|
| Public edge URL | `https://mcp.zacariahheim.com` |
| Control-plane Coolify app UUID | `oooocsw48ksw4occ0w44wo0s` |
| Edge Coolify app UUID | `chevwo1uy2xouq35xfn9q32z` |
| Shared Docker network | `coolify` |
| Secret directory on `cool-res` | `/data/coolify/mcp-platform-secrets` |
| Control-plane admin token path in container | `/run/secrets/mcp-control-plane-admin-token` |
| Edge operator token path in container | `/run/secrets/mcp-edge-operator-token` |

## Repository Map

Repo: `/home/daofficialwizard/Documents/projects/dragonserver/dragonserver/mcp-platform`

Important paths:

- `internal/controlplane/catalog_admin.go`: service catalog admin API.
- `internal/controlplane/grants_admin.go`: manual service grants API.
- `internal/controlplane/upstreams_admin.go`: static upstream binding API.
- `internal/controlplane/store.go`: DB-backed catalog/grants/tenant operations.
- `internal/controlplane/tenant_runtime.go`: Coolify/static-upstream runtime behavior.
- `internal/edge/oauth.go`: OAuth metadata, DCR/CIMD, authorize/token/introspection.
- `internal/edge/server.go`: root discovery, MCP route authz, Bearer challenges.
- `internal/edge/resolver.go`: tenant upstream resolution and upstream URL validation.
- `docs/mcp-registration-client-rbac.md`: operator/client contract and runbook.
- `deploy/coolify/*.compose.yaml`: Coolify deployment templates.

## Admin API Summary

All control-plane admin APIs require:

```http
Authorization: Bearer <control-plane-admin-token>
```

Core endpoints:

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/v1/services` | List catalog rows, including `source` and `enabled`. |
| `GET` | `/v1/services/<serviceID>` | Read one catalog row. |
| `PUT` | `/v1/services/<serviceID>` | Create/replace one admin-managed service. |
| `DELETE` | `/v1/services/<serviceID>` | Disable one admin-managed service. |
| `GET` | `/v1/subjects/<sub>/grants` | List effective enabled-service grants. |
| `PUT` | `/v1/subjects/<sub>/grants/<serviceID>` | Add manual grant source. |
| `DELETE` | `/v1/subjects/<sub>/grants/<serviceID>` | Remove only manual grant source. |
| `PUT` | `/v1/subjects/<sub>/services/<serviceID>/upstream` | Bind granted subject/service to static upstream. |

See [admin-api.md](admin-api.md) for payloads and expected errors.

## Standard Workflows

### Register A Self-Hosted MCP Service

1. Confirm `mcp-control-plane` admin API is enabled and internal-only.
2. Register catalog entry with `PUT /v1/services/<serviceID>`.
3. Grant subject via Authentik group `mcp-service-<serviceID>` or manual grant API.
4. Bind static upstream with `PUT /v1/subjects/<sub>/services/<serviceID>/upstream`.
5. Verify edge discovery publishes `url`, `resource`, `scope`, and PRM URL.
6. Verify `/.well-known/oauth-protected-resource/<serviceID>` returns expected resource/scope.
7. Complete OAuth with opencode/Cursor or a desktop smoke flow.

### Deploy Platform Changes

1. Run local gate in repo:

```bash
sqlc generate
go test -buildvcs=false ./...
go build -buildvcs=false ./...
deploy/coolify/validate-compose.sh
git diff --check
```

2. Commit and push only relevant files.
3. Capture baseline: Coolify app status, edge `/health/ready`, control-plane `/health/ready`.
4. Deploy control-plane app UUID `oooocsw48ksw4occ0w44wo0s`.
5. Verify control-plane readiness and admin API.
6. Deploy edge app UUID `chevwo1uy2xouq35xfn9q32z`.
7. Verify edge readiness, OAuth metadata, PRM metadata, and root discovery.
8. Run E2E canary and cleanup.

See [deployment-e2e.md](deployment-e2e.md) for command recipes.

## Validation Matrix

Minimum checks after changes:

| Area | Check |
|---|---|
| Local code | `go test -buildvcs=false ./...` and `go build -buildvcs=false ./...` |
| Compose | `deploy/coolify/validate-compose.sh` |
| Control-plane | Internal `/health/ready` and `GET /v1/services` with admin token |
| Edge | Public `/health/ready`, `/`, AS metadata, per-service PRM |
| OAuth guardrail | Public DCR without operator token returns `401` when DCR disabled |
| Service auth | Unauthenticated MCP route returns `401` with service scope and PRM URL |
| Dynamic canary | Register, grant, bind, discover, PRM, challenge, cleanup |

## Known Risks And Decisions

- Static upstreams are admin-trusted egress. Private/LAN targets are intentionally allowed.
- Static upstream hostnames are validated before binding and when resolving, but proxy dialing performs its own DNS lookup. Literal IP upstreams are safest when strict DNS rebinding resistance matters.
- Public DCR is disabled by default. Enabling it requires explicit operator intent and abuse controls.
- Authentik access JWTs are not accepted directly at MCP service paths. Edge-issued opaque tokens are required.
- Edge tokens are bound to a canonical MCP `resource` URL and one service scope.
- Old pre-resource-binding tokens require reauth.

## Troubleshooting Shortcuts

| Symptom | Likely cause | First check |
|---|---|---|
| `admin_api_not_configured` | `MCP_CONTROL_PLANE_ADMIN_TOKEN_PATH` empty or token unreadable | Env value, token mount, file mode |
| `builtin_service_locked` | Admin API attempted to mutate builtin service | Use dynamic service ID or code change |
| `public_path_conflict` | Exact or prefix route overlap | `GET /v1/services` |
| `service_not_granted` | Binding upstream before grant | `GET /v1/subjects/<sub>/grants` |
| `upstream_healthcheck_failed` | Static upstream cannot pass catalog health path | Curl from `coolify` network |
| Edge discovery missing dynamic service | Edge catalog cache not refreshed or service disabled | Wait refresh, verify service enabled |
| `invalid_resource` | Token resource does not match service URL | Introspect token |
| `insufficient_scope` | Token scope for another service | Reauth with exact `mcp:<serviceID>` |

## Output Template

```markdown
## MCP Edge Admin Report

- Scope: [audit | service registration | deploy | E2E | fix]
- Target: [control-plane | edge | serviceID | subject]
- Baseline: [health/config/commit state]
- Actions: [high-level operations, no secrets]
- Verification: [checks and results]
- Cleanup: [done/not needed/pending]
- Residual risks: [if any]
- Next step: [single recommended action]
```

## Progressive Disclosure References

- [admin-api.md](admin-api.md): payloads, errors, and curl patterns.
- [deployment-e2e.md](deployment-e2e.md): deploy and canary E2E command flow.
- [client-onboarding.md](client-onboarding.md): opencode/Cursor OAuth setup and fallback modes.
