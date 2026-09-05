# Project Documentation & Contributor Guide

Welcome! This is the canonical source of truth for contributing to `html2rss-web`.

## Docs Index

- **Start here for contributors**: This document.
- **Architecture & Request Lifecycle**: [docs/architecture.md](architecture.md)
- **UI/Design rules**: [docs/design-system.md](design-system.md)
- **Agent execution constraints**: [AGENTS.md](../AGENTS.md)
- **Generated contract artifacts**: `public/openapi.yaml`
- **Public-facing intro**: [README.md](../README.md)

---

## System Snapshot & Architecture

`html2rss-web` converts arbitrary websites into RSS 2.0 feeds.

- **Backend**: Ruby + Roda under the `Html2rss::Web` namespace.
- **Frontend**: Preact + Vite, built into `frontend/dist` and served at `/` in production.
- **Feed extraction**: Delegated to the `html2rss` gem.
- **Distribution**: Docker Compose / Dev Container first.

### Source Of Truth

- **Runtime behavior**: Application code plus tests.
- **HTTP contract**: Request specs plus generated OpenAPI.
- **Config catalog API**: `GET /api/v1/configs` — embedded data from `Html2rss::Configs::Catalog`, merged with local `feeds.yml` entries that include `directory.title`. Disabled when `CONFIG_CATALOG_ENABLED=false` (`404`, `catalog_disabled`). CORS is enabled on this route only.
- **This file**: Contributor conventions and current project rules.

---

## Development Setup (Dev Container)

Use the repository's [Dev Container](../.devcontainer/README.md) for all local development and tests.
Running the app directly on the host is not supported.

### Common Commands (Inside Dev Container)

| Command                        | Purpose                                                    |
| ------------------------------ | ---------------------------------------------------------- |
| `make setup`                   | Install Ruby and Node dependencies.                        |
| `make dev`                     | Run Ruby (port 4000) and frontend (port 4001) dev servers. |
| `make ready`                   | Pre-commit gate: `make quick-check` + `bundle exec rspec`. |
| `make ci-ready`                | CI parity gate: `make ready` + `make openapi-verify` + frontend e2e smoke. |
| `make test`                    | Run Ruby and frontend test suites.                         |
| `make lint`                    | Run all linters.                                           |
| `make yard-verify-public-docs` | Enforce typed YARD docs for public methods in `app/`.      |
| `make openapi`                 | Regenerate `public/openapi.yaml` from request specs.       |
| `make openapi-verify`          | Verify generated OpenAPI and frontend client artifacts are current. |
| `make openapi-lint`            | Lint OpenAPI with Redocly + Spectral.                      |

### Frontend pnpm Scripts

| Command                 | Purpose                                      |
| ----------------------- | -------------------------------------------- |
| `pnpm run dev`          | Vite dev server with hot reload (port 4001). |
| `pnpm run build`        | Build static assets into `frontend/dist/`.   |
| `pnpm run lint`         | Run ESLint across the frontend workspace.    |
| `pnpm run test:run`     | Unit tests (Vitest).                         |
| `pnpm run test:contract`| Contract tests with MSW.                     |

Development routing defaults:

- `http://127.0.0.1:4000` is API-only in development (`/api/v1` metadata and API endpoints).
- `http://127.0.0.1:4001` is the canonical frontend SPA entrypoint in development.
- Vite keeps proxying `/api` and `/rss.xsl` to `:4000` so frontend code can use same-origin-style paths.

---

## Contract-Driven Development Loop

To change or add API endpoints, follow this sequence:

1. **Ruby Request Spec**: Define the new behavior or endpoint in `spec/html2rss/web/app_integration_spec.rb` or a dedicated request spec.
2. **OpenAPI Generation**: Run `make openapi` inside the Dev Container to regenerate `public/openapi.yaml` from the spec metadata.
3. **Verify Contract**: Run `make openapi-verify` and `make openapi-lint` to ensure the generated file matches the specs and is valid.
4. **Frontend Client**: Keep generated client artifacts in `frontend/src/api/generated` aligned with `public/openapi.yaml`.

Always verify the contract before committing API changes.

---

## Verification & Testing Strategy

### Local Verification Gate

Always run this before pushing or committing:

```bash
make ready
```

For frontend changes and API contract/OpenAPI changes, run the CI-parity gate:

```bash
make ci-ready
```

### Testing Layers

| Layer             | Tooling                  | Focus                                                |
| ----------------- | ------------------------ | ---------------------------------------------------- |
| Ruby API          | RSpec + Rack::Test       | Feed creation, retrieval, auth paths.                |
| Frontend unit     | Vitest + Testing Library | Component rendering and hooks with mocked fetch.     |
| Frontend contract | Vitest + MSW             | End-to-end fetch flows against mocked API responses. |
| Docker smoke      | RSpec (`:docker`)        | Net::HTTP probes against the containerised service.  |

---

## Release Automation

- Official releases run only after the `ci` GitHub Actions workflow completes successfully for a commit on `main`.
- Manual `release` workflow dispatch is an emergency/manual replay path and is restricted to `main`.
- Docker publish uses the exact CI-validated commit SHA for release metadata, OCI labels, and `BUILD_TAG` / `GIT_SHA` wiring.
- Branch protection on `main` must continue to require the `ci` workflow even though the release workflow also gates on successful CI.

---

## Backend Structure Rules

- `app/` is the Zeitwerk root for `Html2rss`.
- `app/web/**` maps directly to `Html2rss::Web::*`.
- Match constant, filename, and directory exactly.
- Keep route composition in `app/web/routes/**`.
- Keep `/api/v1` contract-specific code in `app/web/api/**`.
- Keep feed fetching, caching, and orchestration in `app/web/feeds/**`.
- Keep auth, token handling, URL validation, and security logging in `app/web/security/**`.
- Keep request-scoped context in `app/web/request/**`.
- Keep boot/runtime setup in `app/web/boot/**`.
- Do not create generic buckets such as `services`, `helpers`, `utils`, or `concerns`.

---

## API Contract Rules

- `public/openapi.yaml` is generated output, not hand-edited design prose.
- Backend behavior and request specs define the contract.
- Regenerate with `make openapi`.
- Drift must fail with `make openapi-verify`.
- Quality must fail with `make openapi-lint`.
- Frontend generated client code under `frontend/src/api/generated` is machine-generated only.

---

## Core Dependencies

Search these pages for examples, plugins, and configuration options:

- **Roda**: [roda.jeremyevans.net](https://roda.jeremyevans.net/documentation.html)
- **Preact & Vite**: [preactjs.com](https://preactjs.com/guide/v10/getting-started/) and [vite.dev](https://vite.dev/guide/)
- **html2rss**: [github.com/html2rss/html2rss](https://github.com/html2rss/html2rss)
- **Testing (Ruby)**: [rspec.info](https://rspec.info/features/3-13/rspec-expectations/built-in-matchers/), [rubocop.org](https://docs.rubocop.org/rubocop/cops.html), [betterspecs.org](https://www.betterspecs.org/)

---

## Security & Safety Rules

- **URL Handling**: Never use Ruby's `URI` class or `addressable` gem directly. Use `Html2rss::Url` for all URL logic.
- **SSRF Protection**: Delegated to the `html2rss` gem's built-in security features. Do not bypass these protections or weaken CSP.
- **Secrets**: Never leak stack traces, auth tokens, or internal secrets in HTTP responses.
- **Data Protection**: Auth tokens provided by users must never be exposed or logged.

---

## Architectural Constraints

- **No Persistence**: Do not add databases, ORMs, or background job systems.
- **Backend Style**:
  - Keep the main `app.rb` thin; organize routes in `Html2rss::Web::Routes::*`.
  - For helpers, use `class << self` and `private` methods. Avoid `module_function`.
  - Use YARD doc comments for all public methods in `app/`.
  - Add `# frozen_string_literal: true` to all Ruby files.
  - Do not use `send(...)` to reach into private APIs; expose what is needed at the module level.
- **Frontend Style**:
  - Follow visual and CSS rules in [design-system.md](design-system.md).
  - Use Preact components in `frontend/src/`.
  - Use shared styles in `public/shared-ui.css` or app-specific styles in `frontend/src/styles/`.
  - Do not modify `frontend/dist/` directly.
- **Testing**:
  - Use `ClimateControl.modify` for tests that change environment variables.
  - Use `:aggregate_failures` to resolve `RSpec/MultipleExpectations` warnings.

---

## Environment & Runtime Flags

Managed flags and environment keys:

| Name                              | Env key                           | Type           | Default                                  |
| --------------------------------- | --------------------------------- | -------------- | ---------------------------------------- |
| `auto_source_enabled`             | `AUTO_SOURCE_ENABLED`             | boolean        | `true` in development/test, else `false` |
| `async_feed_refresh_enabled`      | `ASYNC_FEED_REFRESH_ENABLED`      | boolean        | `false`                                  |
| `async_feed_refresh_stale_factor` | `ASYNC_FEED_REFRESH_STALE_FACTOR` | integer `>= 1` | `3`                                      |
| `health_check_token`              | `HEALTH_CHECK_TOKEN`              | string         | `nil`                                    |
| `build_tag`                       | `BUILD_TAG`                       | string         | `unknown` outside production             |
| `git_sha`                         | `GIT_SHA`                         | string         | `unknown` outside production             |
| `sentry_dsn`                      | `SENTRY_DSN`                      | string         | `nil`                                    |
| `sentry_enable_logs`              | `SENTRY_ENABLE_LOGS`              | boolean        | `false`                                  |

Rules:

- Boolean flags are true only when the env value (trimmed, case-insensitive) is exactly `true`; every other value is `false` (no boot failure).
- Invalid managed integer flag values must fail fast at boot.
- Unknown managed feature-style env keys must fail fast at boot.
- `BUILD_TAG` and `GIT_SHA` are required in production so startup logs can identify the deployed build.
- Add or change flags in code, tests, and this table together.

---

## Observability Contract

Canonical event fields: `event_name`, `schema_version`, `request_id`, `route_group`, `actor`, `outcome`.

Critical-path event families: auth, feed create, feed render, request errors.

### Sentry DSN separation

Use separate Sentry projects for html2rss-web and botasaurus-scrape-api. Never share a DSN.

| Env var | Service | Project |
| --- | --- | --- |
| `SENTRY_DSN` | html2rss-web | A (web) |
| `BOTASAURUS_SENTRY_DSN` | botasaurus-scrape-api | B (scraper) |

Compose maps `BOTASAURUS_SENTRY_DSN` into the botasaurus service as optional (`${BOTASAURUS_SENTRY_DSN:-}`). It does not fall back to web `SENTRY_DSN`. Leave it unset until you want scraper error reporting.

### Compose timeout ladder

Default `docker-compose.yml` aligns botasaurus-scrape-api, the html2rss gem client, and html2rss-web so the scraper exhausts its budget before the web tier aborts the request. Keep **scrape total (45) ≤ feed build (50) ≤ Rack (55)**; the **work** budget (30) applies only after the browser is ready on the scraper.

| Variable | Service | Default | Role |
| --- | --- | --- | --- |
| `SCRAPE_TIMEOUT_SECONDS` | botasaurus-scrape-api | `45` | Handler wall (queue, boot, navigate, wait) |
| `SCRAPE_WORK_TIMEOUT_SECONDS` | botasaurus-scrape-api | `30` | Post-boot navigate, selector wait, scroll |
| `BOTASAURUS_SCRAPE_TIMEOUT_SECONDS` | html2rss (web) | `45` | Faraday POST `/scrape` cap (mirrors scrape total) |
| `BOTASAURUS_SCRAPE_WORK_TIMEOUT_SECONDS` | html2rss | `30` | Max `wait_timeout_seconds` in feed YAML |
| `HTML2RSS_TOTAL_TIMEOUT_SECONDS` | html2rss-web | `50` | Feed build budget (scrape + extraction) |
| `RACK_TIMEOUT_SERVICE_TIMEOUT` | html2rss-web | `55` | Rack outer wall |

When triaging `GATEWAY_TIMEOUT`, capacity-shaped `SERVICE_UNAVAILABLE` (queue/boot), or `error_category:timeout`, confirm both projects use this ladder. Scraper terminal timeouts near **45s** with web failures near **50–55s** indicate aligned budgets; scraper failures near **20–25s** while web waits longer usually mean stale `SCRAPE_*` / `BOTASAURUS_*` env on one side. Split queue/boot timeouts from work timeouts before blaming the ladder (see **Alert baselines**).

## Sentry Runbook

With `SENTRY_DSN` set, html2rss-web sends unhandled exceptions (Rack middleware) and P0 operational server failures (`SentryOps`: `SCRAPER_UNAVAILABLE`, `SERVICE_UNAVAILABLE`, `INTERNAL_SERVER_ERROR`) to Sentry Issues. Transient target timeouts (`GATEWAY_TIMEOUT`) and extraction warnings stay in structured stdout logs (`feed.render` / `request.error`) and Sentry breadcrumbs to prevent alert fatigue from slow external websites. Release is `BUILD_TAG+GIT_SHA`; environment is `RACK_ENV`.

Structured log intake is opt-in: set `SENTRY_ENABLE_LOGS=true`. A DSN alone does not enable `SentryLogs`.

Start triage from the newest `feed.create`, `feed.render`, and `request.error` events. Check release, route group, strategy, and outcome.

### On-call triage

1. **Confirm project** — `SENTRY_DSN` (web) vs `BOTASAURUS_SENTRY_DSN` (scraper). Scraper errors in the web project usually mean DSN mix-up.
2. **Correlate** — copy `request_id` from one issue and search the other project.
3. **Decision tree**
   - `SCRAPER_UNAVAILABLE` / `navigation_error` → scraper down or unreachable
   - `SERVICE_UNAVAILABLE` with scraper `timeout_phase` `queue` or `boot` → our capacity (queue backlog) or Chromium boot (RAM/shm/prewarm) — not the target site
   - `challenge_block` (scraper) or `BLOCKED_SURFACE` (web) → site blocked automation (product signal). Unclean or unreadable hung Botasaurus surfaces fail closed as `challenge_block` (not `timeout`/`work`).
   - `EXTRACTION_EMPTY` → selectors/config (product signal)
   - `GATEWAY_TIMEOUT` / `timeout` with `timeout_phase` `work` (or nil transport hop) → slow or hostile target, or timeout ladder mismatch (see **Compose timeout ladder**)

Outer scraper deadlines reclaim Chromium via WorkLease (session force-close) so worker slots free before the HTTP 504 returns; lingering `timeout_phase:queue` under light traffic after deploy usually means reclaim or per-host admit saturation (`SCRAPE_MAX_PER_HOST`), not soft-cancel theater.
### Alert baselines

After baseline traffic, configure per project:

**Project B (scraper)**

- P0: `error_category:navigation_error` above baseline
- P0: sustained `error_category:timeout` with `timeout_phase` in `{queue, boot}` (capacity / Chromium) — scale workers or check RAM/shm/prewarm
- P1: sustained `error_category:timeout` with `timeout_phase:work` (slow or hostile targets) — distinct from capacity
- Metric: `scrape.challenge_block` anomaly (product signal; not a timeout)

**Project A (web)**

- P0: `error_code:SCRAPER_UNAVAILABLE` sustained
- P0: `error_code:SERVICE_UNAVAILABLE` sustained when correlated with scraper queue/boot timeouts (capacity)
- Metric / Log: `error_code:GATEWAY_TIMEOUT` rate (slow targets / ladder mismatch; monitored via structured logs, not Sentry Issues)
- P0: `request.error` spike with `kind:server`

### Dashboard baselines

**Scraper (B)**: outcomes by `error_category`, top `host`, `render_ms`, `scrape.challenge_block` trend

**Web (A)**: `feed.render` failures by `error_code`/`strategy`, release comparison

Tune alert thresholds from sustained `request.error` or `feed.render` failure spikes.

---

## Documentation Policy

- Prefer deleting stale docs over archiving them in-place.
- If a rule matters to contributors, keep it here.
- If a detail is generated from code, keep it out of prose docs.
- If a design idea is temporary, keep it in the PR or issue, not under `docs/`.
