![html2rss logo](https://github.com/html2rss/html2rss/raw/main/support/logo.png)

# html2rss-web

html2rss-web converts arbitrary websites into RSS 2.0 feeds with a slim Ruby backend and a Preact frontend.

## Links

- Docs & feed directory: https://html2rss.github.io
- Docker Hub image: https://hub.docker.com/r/html2rss/web
- OpenAPI spec in this repo: [public/openapi.yaml](public/openapi.yaml)
- Contributor Guide: [docs/README.md](docs/README.md)
- Discussions: https://github.com/orgs/html2rss/discussions
- Sponsor: https://github.com/sponsors/gildesmarais

## Highlights

- Responsive Preact interface for demo, sign-in, conversion, and result flows.
- Automatic source discovery with token-scoped permissions.
- Signed public feed URLs that work in standard RSS readers.
- Built-in URL validation, scoped feed access controls, and HMAC-protected tokens.

## Architecture Overview

- **Backend:** Ruby + Roda, backed by the `html2rss` gem for extraction.
- **Frontend:** Preact app built with Vite into `frontend/dist` and served at `/`.
- **Distribution:** Docker Compose by default.

For detailed architecture and internal rules, see [docs/README.md](docs/README.md).

## Trial Run (Docker Compose)

The published image already includes a sample `config/feeds.yml`, so you can try the app without creating or mounting one first. Use Docker Compose for the trial run because the current production boot path requires build metadata and the bundled Browserless wiring from the checked-in compose file.

Pull the image explicitly if you want to confirm the published Docker Hub tag first:

```bash
docker pull html2rss/web
```

```bash
BUILD_TAG=$(date +%F) \
GIT_SHA=trial \
HTML2RSS_SECRET_KEY=$(openssl rand -hex 32) \
HEALTH_CHECK_TOKEN=$(openssl rand -hex 24) \
BROWSERLESS_IO_API_TOKEN=trial-browserless-token \
docker compose up -d
```

Then open:

- `http://localhost:4000/` for the web UI
- `http://localhost:4000/microsoft.com/azure-products.rss` for a built-in Azure updates feed
- `http://localhost:4000/openapi.yaml` for the generated OpenAPI document

This trial run is intentionally minimal. Stop it with `docker compose down`. Keep the checked-in `docker-compose.yml` as the baseline for real deployments, especially if you want Browserless, auto-updates, or local feed overrides.

## Deploy (Docker Compose)

Quick start:

```bash
export HTML2RSS_SECRET_KEY="$(openssl rand -hex 32)"
export HEALTH_CHECK_TOKEN="replace-with-a-strong-token"
export BROWSERLESS_IO_API_TOKEN="replace-with-your-browserless-token"
export BUILD_TAG="local"
export GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo dev)"
export AUTO_SOURCE_ENABLED=true
docker-compose up
```

Optional:

```bash
export SENTRY_DSN="https://examplePublicKey@o0.ingest.sentry.io/0"
export SENTRY_ENABLE_LOGS=true
```

UI + API run on `http://localhost:4000`. The app exits if the secret key is missing.

Production defaults matter:

- `AUTO_SOURCE_ENABLED` is `false` in production unless you set it to `true`.
- The create-feed API at `/api/v1/feeds` requires a bearer token.
- `faraday` is the default strategy; the UI retries once with `browserless` when `faraday` cannot finish the page.

If you enable automatic feed generation, make sure you also configure token distribution and Browserless for JavaScript-heavy pages.

## Integration Discovery

These are the stable entry points for tooling and agents:

- OpenAPI: [`public/openapi.yaml`](public/openapi.yaml) in the repo, or `/openapi.yaml` from a running instance
- API metadata: `/api/v1`
- Generated feed creation endpoint: `POST /api/v1/feeds`

For config authoring and validation, use the `html2rss` JSON Schema from the core repo:

- Core repo file: `https://github.com/html2rss/html2rss/blob/master/schema/html2rss-config.schema.json`
- CLI export: `html2rss schema`

## Development

Use the repository's [Dev Container](.devcontainer/README.md) for all local development and tests.
Running the app directly on the host is not supported.

See the [Contributor Guide](docs/README.md) for setup commands, testing strategy, and backend structure rules.

## Contributing

See the [html2rss project guidelines](https://html2rss.github.io/get-involved/contributing).
