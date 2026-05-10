![html2rss logo](https://github.com/html2rss/html2rss/raw/main/support/logo.png)

# html2rss-web

`html2rss-web` turns website sources into RSS/JSON feeds.

## Quickstart

Test drive the app with these steps:

1. Download [docker-compose.quickstart.yml](./docker-compose.quickstart.yml)
2. `docker compose -f docker-compose.quickstart.yml up -d`
3. Open [`http://localhost:4000/`](http://localhost:4000/) in your browser
4. When prompted for a token, use `CHANGE_ME_ADMIN_TOKEN`

> [!IMPORTANT]
> This is a first-run demo path, not a production-ready setup.

Continue with the [Getting Started](https://html2rss.github.io/web-application/getting-started) and deployment guides for real setup.

## Development (Dev Container Only)

All local development and test execution should run inside the repository Dev Container.

```bash
make setup
make dev
make ready
```

## Development and Contributing

- Contributing guidelines: https://html2rss.github.io/get-involved/contributing
- Docker image: https://hub.docker.com/r/html2rss/web
- Discussions: https://github.com/orgs/html2rss/discussions
- Sponsor: https://github.com/sponsors/gildesmarais
