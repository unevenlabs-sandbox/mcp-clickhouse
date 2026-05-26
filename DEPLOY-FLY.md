# Deploying to Fly.io

This fork carries `fly.toml` for deploying the upstream
[ClickHouse/mcp-clickhouse](https://github.com/ClickHouse/mcp-clickhouse) MCP
server to Fly.io with a static egress IP suitable for whitelisting in a
VPN-gated ClickHouse cluster.

## Prereqs

- `flyctl` installed (`brew install flyctl`)
- `fly auth login` complete
- An app already created: `fly apps create <app-name> --org <org>`
  - The current production app is `mcp-clickhouse-unevenlabs` in the `personal` org
- The `app` field in `fly.toml` matches the app you created

## Required secrets

These are NOT in `fly.toml` — set them via `fly secrets set`:

| Secret | Description |
| --- | --- |
| `CLICKHOUSE_HOST` | ClickHouse host (DNS or IP) |
| `CLICKHOUSE_PORT` | ClickHouse port (HTTP interface) |
| `CLICKHOUSE_USER` | ClickHouse username |
| `CLICKHOUSE_PASSWORD` | ClickHouse password |
| `CLICKHOUSE_DATABASE` | Default database name |
| `CLICKHOUSE_SEND_RECEIVE_TIMEOUT` | Send/receive timeout in seconds |
| `CLICKHOUSE_MCP_AUTH_TOKEN` | Bearer token clients must present on `/mcp` |

`CLICKHOUSE_SECURE` is in `[env]` for visibility but is also overridable via a
secret. Set it to `"true"` for HTTPS ClickHouse endpoints, `"false"` for HTTP.

## Deploy

```sh
fly deploy --remote-only --ha=false
```

The MCP server exposes:

- `GET /health` — returns `200 OK` if ClickHouse is reachable, `503` otherwise
- `POST /mcp` — Streamable HTTP MCP endpoint, gated by the bearer token

## Static egress IP (for VPN whitelist)

Allocate an app-scoped egress IP per region so the outbound connection from
this app to ClickHouse always originates from the same address:

```sh
fly ips allocate-egress --region <region>
fly ips list
```

App-scoped egress IPs survive machine recreation (machine-scoped ones do not —
do not use them).

## Inbound IPs

The default shared IPv4 + dedicated IPv6 are sufficient for HTTPS+SNI. Do not
allocate a dedicated IPv4 (`fly ips allocate-v4`) unless you have a
non-HTTP/UDP/raw-TCP need.

## Notes on the Dockerfile

The `Dockerfile` here drops the upstream cache-mount and bind-mount directives
so it builds on Railway's Buildkit too. On Fly this just means slightly slower
first builds; behavior is identical.
