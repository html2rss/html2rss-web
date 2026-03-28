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
- **Frontend**: Preact + Vite, built into `frontend/dist` and served at `/`.
- **Feed extraction**: Delegated to the `html2rss` gem.
- **Distribution**: Docker Compose / Dev Container first.

### Source Of Truth

- **Runtime behavior**: Application code plus tests.
- **HTTP contract**: Request specs plus generated OpenAPI.
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
| `make ready`                   | Full pre-flight check (Lint + Test + OpenAPI + Zeitwerk).  |
| `make test`                    | Run Ruby and frontend test suites.                         |
| `make lint`                    | Run all linters.                                           |
| `make yard-verify-public-docs` | Enforce typed YARD docs for public methods in `app/`.      |
| `make openapi`                 | Regenerate `public/openapi.yaml` from request specs.       |

### Frontend npm Scripts

| Command                 | Purpose                                      |
| ----------------------- | -------------------------------------------- |
| `npm run dev`           | Vite dev server with hot reload (port 4001). |
| `npm run build`         | Build static assets into `frontend/dist/`.   |
| `npm run test:run`      | Unit tests (Vitest).                         |
| `npm run test:contract` | Contract tests with MSW.                     |

---

## Contract-Driven Development Loop

To change or add API endpoints, follow this sequence:

1. **Ruby Request Spec**: Define the new behavior or endpoint in `spec/html2rss/web/app_integration_spec.rb` or a dedicated request spec.
2. **OpenAPI Generation**: Run `make openapi` inside the Dev Container to regenerate `public/openapi.yaml` from the spec metadata.
3. **Verify Contract**: Run `make openapi-verify` and `make openapi-lint` to ensure the generated file matches the specs and is valid.
4. **Frontend Client**: The frontend generated client in `frontend/src/api/generated` is updated by the build process.

Always verify the contract before committing API changes.

---

## Verification & Testing Strategy

### Local Verification Gate

Always run this before pushing or committing:

```bash
make ready
```

### Testing Layers

| Layer             | Tooling                  | Focus                                                |
| ----------------- | ------------------------ | ---------------------------------------------------- |
| Ruby API          | RSpec + Rack::Test       | Feed creation, retrieval, auth paths.                |
| Frontend unit     | Vitest + Testing Library | Component rendering and hooks with mocked fetch.     |
| Frontend contract | Vitest + MSW             | End-to-end fetch flows against mocked API responses. |
| Docker smoke      | RSpec (`:docker`)        | Net::HTTP probes against the containerised service.  |

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

- Invalid managed flag values must fail fast at boot.
- Unknown managed feature-style env keys must fail fast at boot.
- `BUILD_TAG` and `GIT_SHA` are required in production so startup logs can identify the deployed build.
- Add or change flags in code, tests, and this table together.

---

## Observability Contract

Canonical event fields: `event_name`, `schema_version`, `request_id`, `route_group`, `actor`, `outcome`.

Critical-path event families: auth, feed create, feed render, request errors.

---

## Documentation Policy

- Prefer deleting stale docs over archiving them in-place.
- If a rule matters to contributors, keep it here.
- If a detail is generated from code, keep it out of prose docs.
- If a design idea is temporary, keep it in the PR or issue, not under `docs/`.
