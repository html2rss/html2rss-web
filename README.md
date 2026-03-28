![html2rss logo](https://github.com/html2rss/html2rss/raw/main/support/logo.png)

# html2rss-web

`html2rss-web` serves RSS/JSON feeds from website sources using a Ruby (Roda) backend and a Preact frontend.

## Use This Repo For

- Running a self-hosted `html2rss-web` instance with Docker Compose.
- Creating signed, per-account feed URLs through `POST /api/v1/feeds`.
- Local development inside the repository Dev Container.

## Quick Links

- Public docs + feed directory: https://html2rss.github.io
- Docker Hub image: https://hub.docker.com/r/html2rss/web
- OpenAPI file in this repo: [public/openapi.yaml](public/openapi.yaml)
- Contributor guide: [docs/README.md](docs/README.md)
- Discussions: https://github.com/orgs/html2rss/discussions
- Sponsor: https://github.com/sponsors/gildesmarais

## Architecture Snapshot

- Backend: Ruby + Roda (`app.rb`, `app/web/**`)
- Frontend: Preact + Vite (built assets served from `frontend/dist`)
- Feed extraction: `html2rss` gem
- Distribution baseline: `docker-compose.yml`

For detailed architecture and contributor rules, see [docs/README.md](docs/README.md).

## Trial Run (Docker Compose)

Prerequisite: Docker Engine + Docker Compose.

Run from the repository root:

```bash
BUILD_TAG="$(date +%F)" \
GIT_SHA="trial" \
HTML2RSS_SECRET_KEY="$(openssl rand -hex 32)" \
HEALTH_CHECK_TOKEN="$(openssl rand -hex 24)" \
BROWSERLESS_IO_API_TOKEN="trial-browserless-token" \
docker compose up -d
```

Then open:

- `http://localhost:4000/` (UI)
- `http://localhost:4000/api/v1` (API metadata)
- `http://localhost:4000/openapi.yaml` (OpenAPI document)

Stop with:

```bash
docker compose down
```

## Deploy With Docker Compose

The checked-in [`docker-compose.yml`](docker-compose.yml) requires these environment variables for `html2rss-web`:

- `BUILD_TAG`
- `GIT_SHA`
- `HTML2RSS_SECRET_KEY`
- `HEALTH_CHECK_TOKEN`
- `BROWSERLESS_IO_API_TOKEN`

Optional runtime variables:

- `SENTRY_DSN`
- `SENTRY_ENABLE_LOGS` (defaults to `false`)

Example:

```bash
export HTML2RSS_SECRET_KEY="$(openssl rand -hex 32)"
export HEALTH_CHECK_TOKEN="replace-with-a-strong-token"
export BROWSERLESS_IO_API_TOKEN="replace-with-your-browserless-token"
export BUILD_TAG="local"
export GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo dev)"
export AUTO_SOURCE_ENABLED=true

docker compose up -d
```

## Runtime Behavior That Affects Operations

- In production, missing `HTML2RSS_SECRET_KEY` stops startup.
- `BUILD_TAG` and `GIT_SHA` are expected in production; missing values produce a startup warning.
- `POST /api/v1/feeds` requires a bearer token and only works when `AUTO_SOURCE_ENABLED=true`.
- `AUTO_SOURCE_ENABLED` defaults to `true` in development/test and `false` otherwise.
- Strategy support comes from `Html2rss::RequestService` (`faraday` and `browserless` availability is runtime-dependent).

## Stable Integration Entry Points

- OpenAPI: `/openapi.yaml` (or [`public/openapi.yaml`](public/openapi.yaml) in-repo)
- API metadata: `/api/v1`
- Feed creation endpoint: `POST /api/v1/feeds`
- Health endpoints: `/api/v1/health`, `/api/v1/health/ready`, `/api/v1/health/live`

For feed config authoring/validation, use the `html2rss` schema:

- https://github.com/html2rss/html2rss/blob/master/schema/html2rss-config.schema.json
- `html2rss schema`

## Development (Dev Container Only)

All local development and test execution should run inside the repository Dev Container.

```bash
make setup
make dev
make ready
```

See [docs/README.md](docs/README.md) for contributor workflows, verification gates, and architectural constraints.

## Contributing

- Project guidelines: https://html2rss.github.io/get-involved/contributing
- Repo contributor guide: [docs/README.md](docs/README.md)
