# Project Notes

This is the only hand-written project document in `docs/`.

Keep this file short, current, and operational. Do not add planning docs, migration diaries, redesign notes, or parallel architecture narratives back into this directory.

The only generated artifact intentionally exposed by the app is [`public/openapi.yaml`](/Users/gil/versioned/html2rss/html2rss-web/public/openapi.yaml).

## System Snapshot

- Backend: Ruby + Roda under the `Html2rss::Web` namespace.
- Frontend: Preact + Vite, built into `frontend/dist` and served at `/`.
- Feed extraction: delegated to the `html2rss` gem.
- Distribution: Docker Compose / Dev Container first.

## Source Of Truth

- Runtime behavior: application code plus tests.
- HTTP contract: request specs plus generated OpenAPI.
- This file: contributor conventions and current project rules only.

## Verification

Primary local gate:

```text
docker compose -f .devcontainer/docker-compose.yml exec -T app make ready
```

Useful commands:

```text
docker compose -f .devcontainer/docker-compose.yml exec -T app make setup
docker compose -f .devcontainer/docker-compose.yml exec -T app make dev
docker compose -f .devcontainer/docker-compose.yml exec -T app bundle exec rspec
docker compose -f .devcontainer/docker-compose.yml exec -T app make openapi
docker compose -f .devcontainer/docker-compose.yml exec -T app make openapi-verify
docker compose -f .devcontainer/docker-compose.yml exec -T app make openapi-lint
```

Frontend verification lives at `http://127.0.0.1:4001/` while the dev container is running.

## Backend Structure Rules

- `app/` is the Zeitwerk root for `Html2rss`.
- `app/web/**` maps directly to `Html2rss::Web::*`.
- Match constant, filename, and directory exactly.
- Keep route composition in `app/web/routes/**`.
- Keep `/api/v1` contract-specific code in `app/web/api/**`.
- Keep feed fetching, caching, and orchestration in `app/web/feeds/**`.
- Keep auth, token handling, SSRF strategy, and security logging in `app/web/security/**`.
- Keep request-scoped context in `app/web/request/**`.
- Keep boot/runtime setup in `app/web/boot/**`.
- Do not create generic buckets such as `services`, `helpers`, `utils`, or `concerns`.

## API Contract Rules

- `public/openapi.yaml` is generated output, not hand-edited design prose.
- Backend behavior and request specs define the contract.
- Regenerate with `make openapi`.
- Drift must fail with `make openapi-verify`.
- Quality must fail with `make openapi-lint`.
- Frontend generated client code under `frontend/src/api/generated` is machine-generated only.

## Runtime Flags

Managed flags:

| Name                              | Env key                           | Type           | Default                                  |
| --------------------------------- | --------------------------------- | -------------- | ---------------------------------------- |
| `auto_source_enabled`             | `AUTO_SOURCE_ENABLED`             | boolean        | `true` in development/test, else `false` |
| `async_feed_refresh_enabled`      | `ASYNC_FEED_REFRESH_ENABLED`      | boolean        | `false`                                  |
| `async_feed_refresh_stale_factor` | `ASYNC_FEED_REFRESH_STALE_FACTOR` | integer `>= 1` | `3`                                      |

Rules:

- Invalid managed flag values must fail fast at boot.
- Unknown managed feature-style env keys must fail fast at boot.
- Add or change flags in code, tests, and this table together.

## Observability Contract

Canonical event fields:

- `event_name`
- `schema_version`
- `request_id`
- `route_group`
- `actor`
- `outcome`

Optional request context fields:

- `path`
- `method`
- `strategy`
- `started_at`
- `details`

Critical-path event families:

- auth
- feed create
- feed render
- request errors

## Documentation Policy

- Prefer deleting stale docs over archiving them in-place.
- If a rule matters to contributors, keep it here.
- If a detail is generated from code, keep it out of prose docs.
- If a design idea is temporary, keep it in the PR or issue, not under `docs/`.
