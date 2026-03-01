# Event Schema Contract

## Scope
Critical path events:
- auth
- feed create
- feed render
- errors

## Required Fields
- `event_name` (string)
- `schema_version` (string, current: `1.0`)
- `request_id` (string, nullable only outside request lifecycle)
- `route_group` (string)
- `actor` (string, nullable)
- `outcome` (`success` | `failure`)

## Optional Fields
- `details` (object)
- `path`, `method`, `strategy`, `started_at` from request context when available

## Categories and Log Pairing

| Category | Event examples | Log level |
|---|---|---|
| auth | `auth.authenticate` | `info` (success), `warn` (failure) |
| feed create | `feed.create` | `info` (success), `warn` (failure) |
| feed render | `feed.render` | `info` (success), `warn` (failure) |
| errors | `request.error` | `error` |

## Emission Rules
- Emit exactly one canonical event per successful critical-path action.
- Emit one failure event at the boundary where failure is determined.
- Preserve existing security logs; schema events are additive.

## Non-Goals
- CI-enforced event-count coverage metrics.
- Backfilling historic logs.
