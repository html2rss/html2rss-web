# `app/web` Rules For AI Agents

This file is intentionally prescriptive. If you are an AI coding agent changing Ruby backend code, follow these rules before adding files or moving code.

## Namespace Contract

- `app/` is the Zeitwerk root for `Html2rss`.
- `app/web/**` maps to the `Html2rss::Web` namespace.
- Do not add `require_relative` calls between files under `app/web/**` unless the file is a non-Zeitwerk boot entrypoint.
- Path, filename, and constant name must match. If a constant is `Html2rss::Web::SecurityLogger`, the file belongs at `app/web/security/security_logger.rb`.

## Directory Placement

Use the narrowest concern folder that fits the object.

- `app/web/api/`: API contract and endpoint implementation objects.
- `app/web/boot/`: process boot, loader setup, dev reload, runtime setup.
- `app/web/config/`: environment flags, local config loading, config snapshots.
- `app/web/domain/`: backend domain helpers that do not belong to API, request, rendering, or security.
- `app/web/errors/`: error classes and error response serialization.
- `app/web/feeds/`: feed fetching, rendering orchestration, cache use, feed service contracts.
- `app/web/http/`: low-level HTTP response/cache helpers.
- `app/web/rendering/`: content negotiation and feed output builders.
- `app/web/request/`: request-scoped context and middleware.
- `app/web/routes/`: Roda route composition only.
- `app/web/security/`: auth, token handling, account access, SSRF request strategy, security logging.
- `app/web/telemetry/`: observability event emission only.

## Placement Heuristics

- Put code in `routes/` only if it mounts or composes Roda request branches.
- Put code in `api/` only if it is specific to `/api/v1` contracts or endpoint behavior.
- Put code in `feeds/` if it is part of fetching, resolving, rendering, or caching feeds.
- Put code in `domain/` only as a last resort. If a better concern folder exists, use it.
- Do not create generic buckets such as `services`, `utils`, `helpers`, or `concerns`.

## Consolidation Rules

- Prefer concern folders over a flat `app/web/` root.
- Do not merge unrelated objects just to reduce file count.
- Consolidate only when one file is clearly a thin wrapper around another concept and the merged object still has a single responsibility.
- If a file defines multiple top-level constants, stop and check whether Zeitwerk naming or the public API would become less clear.

## Boot And Runtime Rules

- `app.rb` should declare the Roda app and its Rack/Roda plugins.
- Process-level boot side effects belong in `app/web/boot/**`.
- Register external runtime integrations, validate environment, and configure shared services in boot objects, not inline in the Roda class body.

## Route Rules

- Keep route composition centralized in `app/web/routes/**`.
- Split route modules by endpoint concern when a route file grows, but preserve matching order.
- Root metadata routes must use exact matching (`r.is`) so they do not swallow subpaths.

## Change Checklist

- Update or add specs for the behavior you moved.
- Run `docker compose -f .devcontainer/docker-compose.yml exec -T app make ready`.
- Smoke the app at `http://127.0.0.1:4001/` when request or UI behavior changed.
