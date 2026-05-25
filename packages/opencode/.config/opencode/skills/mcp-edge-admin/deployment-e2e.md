# MCP Edge Deployment And E2E

## Local Gate

Run from `/home/daofficialwizard/Documents/projects/dragonserver/dragonserver/mcp-platform`:

```bash
sqlc generate
go test -buildvcs=false ./...
go build -buildvcs=false ./...
deploy/coolify/validate-compose.sh
git diff --check
```

## Baseline

```bash
coolify app get oooocsw48ksw4occ0w44wo0s --format json
coolify app get chevwo1uy2xouq35xfn9q32z --format json
curl -fsS https://mcp.zacariahheim.com/health/ready
```

Internal control-plane checks:

```bash
ssh -o BatchMode=yes cool-res 'docker run --rm --network coolify curlimages/curl:8.10.1 -fsS http://mcp-control-plane:8081/health/live'
ssh -o BatchMode=yes cool-res 'docker run --rm --network coolify curlimages/curl:8.10.1 -fsS http://mcp-control-plane:8081/health/ready'
```

## Deploy Order

Control-plane first:

```bash
coolify deploy uuid oooocsw48ksw4occ0w44wo0s --force --format json
```

Poll:

```bash
coolify deploy get <deployment_uuid> --format json
```

Validate control-plane before edge:

```bash
ssh -o BatchMode=yes cool-res 'docker run --rm --network coolify curlimages/curl:8.10.1 -fsS http://mcp-control-plane:8081/health/ready'
```

Edge second:

```bash
coolify deploy uuid chevwo1uy2xouq35xfn9q32z --force --format json
```

Validate edge:

```bash
curl -fsS https://mcp.zacariahheim.com/health/ready
curl -fsS https://mcp.zacariahheim.com/ | jq -c '{catalog_status, service_count:(.services|length), enriched:([.services[] | has("url") and has("resource") and has("protected_resource_metadata_url")] | all)}'
curl -fsS https://mcp.zacariahheim.com/.well-known/oauth-authorization-server
curl -fsS https://mcp.zacariahheim.com/.well-known/oauth-protected-resource/mealie
```

Penpot official MCP smoke after a Penpot cutover:

```bash
curl -fsS https://mcp.zacariahheim.com/.well-known/oauth-protected-resource/penpot
curl -i -sS https://mcp.zacariahheim.com/penpot/mcp
ssh -o BatchMode=yes cool-res 'docker run --rm --network coolify curlimages/curl:8.10.1 -fsS http://penpot-official-mcp-edge-proxy:3000/health'
```

Expected Penpot behavior:

- Protected-resource metadata advertises resource `https://mcp.zacariahheim.com/penpot/mcp` and scope `mcp:penpot`.
- Unauthenticated route returns `401` with the Penpot PRM URL.
- Authenticated `tools/list` returns the official tools: `execute_code`, `high_level_overview`, `penpot_api_info`, and `export_shape`.
- File-context calls require a Penpot file with File -> MCP Server -> Connect active in the browser.

## Dynamic Canary

Use disposable service `e2e-smoke` and subject `e2e-smoke-sub` unless user specifies alternatives.

Safe upstream target for platform canary: `http://mcp-edge:8080` with:

- `health_path=/health/live`
- `internal_upstream_path=/health/live`

Register, grant, and bind from `cool-res` with token loaded inside command scope. Then verify:

```bash
curl -fsS https://mcp.zacariahheim.com/ | jq -c '.services[] | select(.id=="e2e-smoke")'
curl -fsS https://mcp.zacariahheim.com/.well-known/oauth-protected-resource/e2e-smoke
curl -i -sS https://mcp.zacariahheim.com/e2e-smoke/mcp
```

Expected unauthenticated challenge includes:

```text
scope="mcp:e2e-smoke"
resource_metadata="https://mcp.zacariahheim.com/.well-known/oauth-protected-resource/e2e-smoke"
```

## OAuth Guardrails

Public DCR disabled check:

```bash
curl -i -sS https://mcp.zacariahheim.com/oauth/register \
  -H 'Content-Type: application/json' \
  -d '{"client_name":"no-token","redirect_uris":["http://127.0.0.1:33418/oauth/callback"],"grant_types":["authorization_code","refresh_token"],"response_types":["code"],"token_endpoint_auth_method":"none","scope":"mcp:mealie"}'
```

Expected: `401 operator_auth_required`.

Operator DCR check:

```bash
ssh -o BatchMode=yes cool-res 'OPERATOR_TOKEN="$(sudo cat /data/coolify/mcp-platform-secrets/mcp-edge-operator-token)"; docker run --rm curlimages/curl:8.10.1 -fsS -X POST https://mcp.zacariahheim.com/oauth/register -H "Authorization: Bearer ${OPERATOR_TOKEN}" -H "Content-Type: application/json" -d '\''{"client_name":"e2e-smoke-client","redirect_uris":["http://127.0.0.1:33418/oauth/callback"],"grant_types":["authorization_code","refresh_token"],"response_types":["code"],"token_endpoint_auth_method":"none","scope":"mcp:e2e-smoke"}'\'' | jq -c "{client_id:(.client_id|length), redirect_uris, scope, token_endpoint_auth_method}"'
```

## Negative Checks

- Builtin mutation: `PUT /v1/services/mealie` returns `409 builtin_service_locked`.
- Bind without grant returns `409 service_not_granted`.
- Introspection without operator token returns `401`.
- Token for one service must not access another service.

## Cleanup Verification

After canary cleanup:

```bash
curl -fsS https://mcp.zacariahheim.com/ | jq -r '.services[]?.id'
ssh -o BatchMode=yes cool-res 'docker run --rm --network coolify curlimages/curl:8.10.1 -fsS http://mcp-control-plane:8081/health/ready' | jq -c '{status,last_summary}'
```

Expected:

- No `e2e-smoke` in discovery.
- Control-plane `Failures=0`.
- Edge `services=3` unless another legitimate service exists.
