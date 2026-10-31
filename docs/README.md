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

- **Backend**: Ruby + Falcon + Roda under the `Html2rss::Web` namespace.
- **Frontend**: Preact + Vite, built into `frontend/dist` and served at `/` in production.
- **Feed extraction**: Delegated to the `html2rss` gem (HTTPX non-blocking transport layer).
- **Distribution**: Docker Compose first (`dev` target for local work).

### Source Of Truth

- **Runtime behavior**: Application code plus tests.
- **HTTP contract**: Request specs plus generated OpenAPI.
- **Config catalog API**: `GET /api/v1/configs` — embedded data from `Html2rss::Configs::Catalog`, merged with local `feeds.yml` entries that include `directory.title`. Disabled when `CONFIG_CATALOG_ENABLED=false` (`404`, `catalog_disabled`). CORS is enabled on this route only.
- **This file**: Contributor conventions and current project rules.

---

## Development Setup (Docker)

Run `make <target>` on the host: it delegates to the `dev` stage of the root `Dockerfile` via `docker-compose.dev.yml` (built on first use). Running the app directly on the host is not supported. On Linux, export `DEV_UID=$(id -u) DEV_GID=$(id -g)` before the first `make` so bind-mounted files stay owned by you. CI runs the same image via `.github/actions/dev-image`.

```bash
make setup
make dev
```

### Common Commands

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
2. **OpenAPI Generation**: Run `make openapi` inside the `dev` image to regenerate `public/openapi.yaml` from the spec metadata.
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
| Docker smoke      | `rake` (Rakefile)        | HTTP probes against the built runtime image.         |

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
- **Compose exposure**: Web binds `4000:4000` (all interfaces) for LAN; require a strong `HTML2RSS_ACCESS_TOKEN` in production. Botasaurus must stay unpublished (quickstart) or `127.0.0.1:4010` only (production). Enforce with `bin/compose-contract-verify`.

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
| `health_check_token`              | `HEALTH_CHECK_TOKEN`              | string         | `nil`                                    |
| `build_tag`                       | `BUILD_TAG`                       | string         | `unknown` outside production             |
| `git_sha`                         | `GIT_SHA`                         | string         | `unknown` outside production             |
| `sentry_dsn`                      | `SENTRY_DSN`                      | string         | `nil`                                    |

Rules:

- Boolean flags are true only when the env value (trimmed, case-insensitive) is exactly `true`; every other value is `false` (no boot failure).
- Invalid managed integer flag values must fail fast at boot.
- Unknown managed feature-style env keys must fail fast at boot.
- `BUILD_TAG` and `GIT_SHA` are required in production so startup logs can identify the deployed build.
- `HEALTH_CHECK_TOKEN` is the credential for private `/api/v1/health`. A blank value and `CHANGE_ME_HEALTH_CHECK_TOKEN` are rejected.
- Add or change flags in code, tests, and this table together.

---

## Observability Contract

Critical-path event families: auth, feed create, feed render, request errors.

### Log contract

Stdout is one JSON object per line. Operators join app lines to proxy access logs with `request_id` (equal to the `X-Request-Id` response header).

| Field | Role |
| --- | --- |
| `event_name` | Family such as `feed.render`, `feed.create`, `request.error` |
| `outcome` | `success` or `failure` |
| `details.error_code` | Closed classifier code when present |
| `details.error_message` | Sanitized free-form failure text (URLs redacted, capped) |
| `details.strategy` | Requested scrape strategy when set |
| `details.cache` | `hit` or `miss` on `feed.render` |
| `duration_ms` | Whole-millisecond request age at emit time |
| `request_id` | Correlation id; same value as `X-Request-Id` |
| `route_group` | `health`, `catalog`, `feed_create`, `feed_render`, or `static` |

### Sentry DSN separation

Use separate Sentry projects for html2rss-web and botasaurus-scrape-api. Never share a DSN.

| Env var | Service | Project |
| --- | --- | --- |
| `SENTRY_DSN` | html2rss-web | A (web) |
| `BOTASAURUS_SENTRY_DSN` | botasaurus-scrape-api | B (scraper) |

Compose maps `BOTASAURUS_SENTRY_DSN` into the botasaurus service as optional (`${BOTASAURUS_SENTRY_DSN:-}`). It does not fall back to web `SENTRY_DSN`. Leave it unset until you want scraper error reporting.

Sentry covers unexpected non-HTTP exceptions only. Operational alerts are log-based alerts in the operator's log backend.

### Compose timeout ladder

Default `docker-compose.yml` aligns botasaurus-scrape-api, the html2rss gem client, and html2rss-web so the scraper exhausts its budget before the web tier aborts the request. Keep **scrape total (45) ≤ feed build (50) ≤ Falcon (55)**; the **work** budget (30) applies only after the browser is ready on the scraper.

| Variable | Service | Default | Role |
| --- | --- | --- | --- |
| `SCRAPE_TIMEOUT_SECONDS` | botasaurus-scrape-api | `45` | Handler wall (queue, boot, navigate, wait) |
| `SCRAPE_WORK_TIMEOUT_SECONDS` | botasaurus-scrape-api | `30` | Post-boot navigate, selector wait, scroll |
| `BOTASAURUS_SCRAPE_TIMEOUT_SECONDS` | html2rss (web) | `45` | HTTPX POST `/scrape` cap (mirrors scrape total) |
| `BOTASAURUS_SCRAPE_WORK_TIMEOUT_SECONDS` | html2rss | `30` | Max `wait_timeout_seconds` in feed YAML |
| `HTML2RSS_TOTAL_TIMEOUT_SECONDS` | html2rss-web | `50` | Feed build budget (scrape + extraction) |
| `REQUEST_TIMEOUT_SECONDS` | html2rss-web | `55` | Falcon server request timeout |

When triaging `GATEWAY_TIMEOUT`, capacity-shaped `SERVICE_UNAVAILABLE` (queue/boot), or a scraper timeout, confirm both projects use this ladder. Scraper terminal timeouts near **45s** with web failures near **50–55s** indicate aligned budgets; scraper failures near **20–25s** while web waits longer usually mean stale `SCRAPE_*` / `BOTASAURUS_*` env on one side. Split queue/boot timeouts from work timeouts before blaming the ladder. Use `details.error_message` to separate ladder timeouts from fixed ones.

### On-call triage (log queries)

Start from the newest `feed.create`, `feed.render`, and `request.error` lines. Filter on `request_id`, `route_group`, `details.error_code`, and `outcome`.

1. **Confirm project** — `SENTRY_DSN` (web exceptions) vs `BOTASAURUS_SENTRY_DSN` (scraper). Scraper faults in the web project usually mean DSN mix-up.
2. **Correlate** — copy `request_id` / `X-Request-Id` across web logs, proxy access logs, and scraper logs.
3. **Decision tree**
   - `SCRAPER_UNAVAILABLE` → scraper down or unreachable
   - `SERVICE_UNAVAILABLE` with queue/boot timeout wording in `details.error_message` → our capacity or Chromium boot, not the target site
   - `BLOCKED_SURFACE` → site blocked automation (product signal; cached for feed TTL with `details.cacheable=true` to avoid hammering challenge pages)
   - `EXTRACTION_EMPTY` → selectors/config (product signal)
   - `GATEWAY_TIMEOUT` → slow or hostile target, or timeout ladder mismatch (see **Compose timeout ladder**)

### Instance health

`/api/v1/health/live` is the restart signal (`bin/docker-healthcheck`) and does not load config. `/api/v1/health/ready` is `LocalConfig.load_snapshot`. Private `/api/v1/health` needs a real `HEALTH_CHECK_TOKEN`.

### Not collected

Not collected: host CPU, memory, disk, network, visitor analytics, per-user streams, raw URLs, tokens, bodies, SQL, raw feed-token paths, queue depth, and botasaurus traces.

---

## Documentation Policy

- Prefer deleting stale docs over archiving them in-place.
- If a rule matters to contributors, keep it here.
- If a detail is generated from code, keep it out of prose docs.
- If a design idea is temporary, keep it in the PR or issue, not under `docs/`.
