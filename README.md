![html2rss logo](https://github.com/html2rss/html2rss/raw/main/support/logo.png)

# html2rss-web

html2rss-web converts arbitrary websites into RSS 2.0 feeds with a slim Ruby backend and a Preact frontend.

## Links

- Docs & feed directory: https://html2rss.github.io
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

## Trial Run (Docker Pull And Run)

The published image already includes a sample `config/feeds.yml`, so you can try the app without creating or mounting one first.

```bash
docker run --rm \
  -p 4000:4000 \
  -e RACK_ENV=production \
  -e HTML2RSS_SECRET_KEY=$(openssl rand -hex 32) \
  html2rss/web
```

Then open:

- `http://localhost:4000/` for the web UI
- `http://localhost:4000/microsoft.com/azure-products.rss` for a built-in Azure updates feed

This trial run is intentionally minimal. Use Docker Compose for Browserless, auto-updates, or local feed overrides.

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

## Development

Use the repository's [Dev Container](.devcontainer/README.md) for all local development and tests.
Running the app directly on the host is not supported.

See the [Contributor Guide](docs/README.md) for setup commands, testing strategy, and backend structure rules.

## Contributing

See the [html2rss project guidelines](https://html2rss.github.io/get-involved/contributing).
