![html2rss logo](https://github.com/html2rss/html2rss/raw/main/support/logo.png)

# html2rss-web

`html2rss-web` turns website sources into RSS/JSON feeds.

## Quickstart Trial

Run the published trial stack:

```bash
docker compose -f docker-compose.quickstart.yml up -d
```

Open `http://localhost:4000/`.
When the UI asks for an access token, use `CHANGE_ME_ADMIN_TOKEN`.
For secure hosting and full setup, use the getting-started docs:
- https://html2rss.github.io/web-application/getting-started

## Deployment Docs

- Published Docker image and tags: https://hub.docker.com/r/html2rss/web
- End-user deployment and operations docs: https://html2rss.github.io/web-application/getting-started

## Development (Dev Container Only)

All local development and test execution should run inside the repository Dev Container.

```bash
make setup
make dev
make ready
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for contributor workflows, verification gates, and architectural constraints.

## Development / Contributing

- Project guidelines: https://html2rss.github.io/get-involved/contributing
- Repo contributor guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Discussions: https://github.com/orgs/html2rss/discussions
- Sponsor: https://github.com/sponsors/gildesmarais
