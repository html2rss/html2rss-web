![html2rss logo](https://github.com/html2rss/html2rss/raw/master/support/logo.png)

# html2rss-web

html2rss-web converts arbitrary websites into RSS 2.0 feeds with a slim Ruby backend and an Astro-powered frontend.

## Links
- Docs & feed directory: https://html2rss.github.io
- Discussions: https://github.com/orgs/html2rss/discussions
- Sponsor: https://github.com/sponsors/gildesmarais

## Highlights
- Responsive Astro interface with gallery and custom feed creation.
- Automatic source discovery with token-scoped permissions.
- Signed public feed URLs that work in standard RSS readers.
- Built-in SSRF defences, input validation, and HMAC-protected tokens.

## Architecture
- **Backend:** Ruby + Roda, backed by the `html2rss` gem for extraction.
- **Frontend:** Astro static site with progressive enhancement.
- **Distribution:** Docker Compose by default; other deployments require manual wiring.

## Documentation
In-repo docs live under `frontend/src/content/docs/` and are published by Astro.
- [Configuration Guide](frontend/src/content/docs/configuration.md)
- [Security Guide](frontend/src/content/docs/security.md)
- [REST API v1](frontend/src/content/docs/api/v1.md)
- [Testing Overview](frontend/src/content/docs/testing.md)

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
bundle exec rubocop -F
bundle exec rspec
```

Dev URLs: Ruby app at `http://localhost:4000`, Astro dev server at `http://localhost:4001`.

## Make Targets

| Command              | Purpose                                                 |
| -------------------- | ------------------------------------------------------- |
| `make help`          | List available shortcuts.                               |
| `make setup`         | Install Ruby and Node dependencies.                     |
| `make dev`           | Run Ruby (port 4000) and Astro (port 4001) dev servers. |
| `make dev-ruby`      | Start only the Ruby server.                             |
| `make dev-frontend`  | Start only the Astro dev server (port 4001).            |
| `make test`          | Run Ruby and frontend test suites.                      |
| `make test-ruby`     | Run Ruby specs.                                         |
| `make test-frontend` | Run frontend unit and contract tests.                   |
| `make lint`          | Run all linters.                                        |
| `make lintfix`       | Auto-fix lint warnings where possible.                  |
| `make clean`         | Remove build artefacts.                                 |

## Frontend npm Scripts (inside Dev Container)

| Command                 | Purpose                           |
| ----------------------- | --------------------------------- |
| `npm run dev`           | Astro dev server with hot reload (port 4001). |
| `npm run build`         | Production build.                 |
| `npm run test:run`      | Unit tests (Vitest).              |
| `npm run test:contract` | Contract tests with MSW.          |

## Testing Strategy

| Layer             | Tooling                  | Focus                                                |
| ----------------- | ------------------------ | ---------------------------------------------------- |
| Ruby API          | RSpec + Rack::Test       | Feed creation, retrieval, auth paths.                |
| Frontend unit     | Vitest + Testing Library | Component rendering and hooks with mocked fetch.     |
| Frontend contract | Vitest + MSW             | End-to-end fetch flows against mocked API responses. |
| Docker smoke      | RSpec (`:docker`)        | Net::HTTP probes against the containerised service.  |

## Contributing
See the [html2rss project guidelines](https://html2rss.github.io/get-involved/contributing).
