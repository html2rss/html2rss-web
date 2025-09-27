![html2rss logo](https://github.com/html2rss/html2rss/raw/master/support/logo.png)

# html2rss-web

html2rss-web converts arbitrary websites into RSS 2.0 feeds with a slim Ruby backend and an Astro-powered frontend.

## 🌐 Community & Resources

| Resource                              | Description                                                 | Link                                                               |
| ------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------ |
| **📚 Documentation & Feed Directory** | Complete guides, tutorials, and browse 100+ pre-built feeds | [html2rss.github.io](https://html2rss.github.io)                   |
| **💬 Community Discussions**          | Get help, share ideas, and connect with other users         | [GitHub Discussions](https://github.com/orgs/html2rss/discussions) |
| **📋 Project Board**                  | Track development progress and upcoming features            | [View Project Board](https://github.com/orgs/html2rss/projects)    |
| **💖 Support Development**            | Help fund ongoing development and maintenance               | [Sponsor on GitHub](https://github.com/sponsors/gildesmarais)      |

**Quick Start Options:**

- **New to RSS?** → Start with the [web application guide](https://html2rss.github.io/web-application)
- **Need a specific feed?** → Browse the [feed directory](https://html2rss.github.io/feed-directory)
- **Want to deploy?** → Check out [deployment guides](https://html2rss.github.io/web-application/how-to/deployment)
- **Want to contribute?** → See our [contributing guide](https://html2rss.github.io/get-involved/contributing)

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
The in-repo docs live under `frontend/src/content/docs/` and are published by Astro.
- [Configuration Guide](frontend/src/content/docs/configuration.md)
- [Security Guide](frontend/src/content/docs/security.md)
- [REST API v1](frontend/src/content/docs/api/v1.md)
- [Testing Overview](frontend/src/content/docs/testing.md)

## REST API Snapshot
```bash
# List feeds available to the token
curl -H "Authorization: Bearer <token>" \
  "https://your-domain.com/api/v1/feeds"

# Create a feed and capture the signed public URL
curl -X POST "https://your-domain.com/api/v1/feeds" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","name":"Example Feed"}'
```

## Deploy with Docker Compose
The supported path is Docker Compose.

### Prerequisites
- Docker Engine and Docker Compose
- Git for cloning the repository

### Steps
1. Clone the repository and change into the directory.
2. Generate a 64-character hexadecimal key: `openssl rand -hex 32`.
3. Update `docker-compose.yml` with the key via the `HTML2RSS_SECRET_KEY` environment variable.
4. Start the stack: `docker-compose up`.

The application serves the UI and API at `http://localhost:3000`. It fails fast if the secret key is missing.

## Frontend Development
```
cd frontend
npm install
npm run dev
```
The Ruby server continues to serve the production build while Astro runs with hot reload on port 4321.

## Make Targets

| Command | Purpose |
| --- | --- |
| `make help` | List available shortcuts. |
| `make setup` | Install Ruby and Node dependencies. |
| `make dev` | Run Ruby (port 3000) and Astro (port 4321) dev servers. |
| `make dev-ruby` | Start only the Ruby server. |
| `make dev-frontend` | Start only the Astro dev server. |
| `make test` | Run Ruby and frontend test suites. |
| `make test-ruby` | Run Ruby specs. |
| `make test-frontend` | Run frontend unit and contract tests. |
| `make lint` | Run all linters. |
| `make lintfix` | Auto-fix lint warnings where possible. |
| `make clean` | Remove build artefacts. |

## Frontend npm Scripts

| Command | Purpose |
| --- | --- |
| `npm run dev` | Astro dev server with hot reload. |
| `npm run build` | Production build. |
| `npm run test:run` | Unit tests (Vitest). |
| `npm run test:contract` | Contract tests with MSW. |

## Testing Strategy

| Layer | Tooling | Focus |
| --- | --- | --- |
| Ruby API | RSpec + Rack::Test | Feed creation, retrieval, auth paths. |
| Frontend unit | Vitest + Testing Library | Component rendering and hooks with mocked fetch. |
| Frontend contract | Vitest + MSW | End-to-end fetch flows against mocked API responses. |
| Docker smoke | RSpec (`:docker`) | Net::HTTP probes against the containerised service. |

## Contributing

Contributions are welcome. See the [html2rss project guidelines](https://html2rss.github.io/get-involved/contributing) before opening a pull request.

## Sponsoring

Support ongoing development via [GitHub Sponsors](https://github.com/sponsors/gildesmarais).
