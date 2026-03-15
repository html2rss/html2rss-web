![html2rss logo](https://github.com/html2rss/html2rss/raw/master/support/logo.png)

# html2rss-web

html2rss-web converts arbitrary websites into RSS 2.0 feeds with a slim Ruby backend and a Preact frontend.

## Links

- Docs & feed directory: https://html2rss.github.io
- Discussions: https://github.com/orgs/html2rss/discussions
- Sponsor: https://github.com/sponsors/gildesmarais

## Highlights

- Responsive Preact interface for demo, sign-in, conversion, and result flows.
- Automatic source discovery with token-scoped permissions.
- Signed public feed URLs that work in standard RSS readers.
- Built-in SSRF defences, input validation, and HMAC-protected tokens.

## Architecture

- **Backend:** Ruby + Roda, backed by the `html2rss` gem for extraction.
- **Frontend:** Preact app built with Vite into `public/frontend`.
- **Distribution:** Docker Compose by default; other deployments require manual wiring.
- [v2 Migration Guide](docs/migrations/v2.md)

## REST API Snapshot

```bash
# List available strategies
curl -H "Authorization: Bearer <token>" \
  "https://your-domain.com/api/v1/strategies"

# Create a feed and capture the signed public URL
curl -X POST "https://your-domain.com/api/v1/feeds" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","name":"Example Feed"}'
```

## Deploy (Docker Compose)

1. Generate a key: `openssl rand -hex 32`.
2. Set `HTML2RSS_SECRET_KEY` in `docker-compose.yml`.
3. Start: `docker-compose up`.

UI + API run on `http://localhost:4000`. The app exits if the secret key is missing.

## Development (Dev Container)

Use the repository's [Dev Container](.devcontainer/README.md) for all local development and tests.
Running the app directly on the host is not supported.

Quick start inside the Dev Container:

```
make setup
make dev
make test
make ready
make yard-verify-public-docs
bundle exec rubocop -F
bundle exec rspec
make openapi
```

Dev URLs: Ruby app at `http://localhost:4000`, frontend dev server at `http://localhost:4001`.

Backend code under the `Html2rss::Web` namespace now lives under `app/web/**`, so Zeitwerk can mirror constant paths directly instead of relying on directory-specific namespace wiring.
`make ready` also runs `rake zeitwerk:verify`, which eager-loads the app and fails on loader drift early.
For contributors and AI agents changing backend structure, follow the placement rules in [docs/ai-agent-app-web.md](docs/ai-agent-app-web.md).

## Make Targets

| Command              | Purpose                                                 |
| -------------------- | ------------------------------------------------------- |
| `make help`          | List available shortcuts.                               |
| `make setup`         | Install Ruby and Node dependencies.                     |
| `make dev`           | Run Ruby (port 4000) and frontend (port 4001) dev servers. |
| `make dev-ruby`      | Start only the Ruby server.                             |
| `make dev-frontend`  | Start only the frontend dev server (port 4001).         |
| `make test`          | Run Ruby and frontend test suites.                      |
| `make test-ruby`     | Run Ruby specs.                                         |
| `make test-frontend` | Run frontend unit and contract tests.                   |
| `make lint`          | Run all linters.                                        |
| `make lintfix`       | Auto-fix lint warnings where possible.                  |
| `make yard-verify-public-docs` | Enforce typed YARD docs for public methods in `app/`. |
| `make openapi`       | Regenerate `docs/api/v1/openapi.yaml` from request specs. |
| `make openapi-verify`| Regenerate + fail if OpenAPI file is stale.             |
| `make clean`         | Remove build artefacts.                                 |

## OpenAPI Contract

The OpenAPI file is generated from Ruby request specs only.

- Regenerate: `make openapi`
- Verify drift (CI behavior): `make openapi-verify`

## Frontend npm Scripts (inside Dev Container)

| Command                 | Purpose                                       |
| ----------------------- | --------------------------------------------- |
| `npm run dev`           | Vite dev server with hot reload (port 4001).  |
| `npm run build`         | Build static assets into `public/frontend`.   |
| `npm run test:run`      | Unit tests (Vitest).                          |
| `npm run test:contract` | Contract tests with MSW.                      |

## Testing Strategy

| Layer             | Tooling                  | Focus                                                |
| ----------------- | ------------------------ | ---------------------------------------------------- |
| Ruby API          | RSpec + Rack::Test       | Feed creation, retrieval, auth paths.                |
| Frontend unit     | Vitest + Testing Library | Component rendering and hooks with mocked fetch.     |
| Frontend contract | Vitest + MSW             | End-to-end fetch flows against mocked API responses. |
| Docker smoke      | RSpec (`:docker`)        | Net::HTTP probes against the containerised service.  |

## Contributing

See the [html2rss project guidelines](https://html2rss.github.io/get-involved/contributing).
