# html2rss-web

Paste a page URL into the web UI and get an RSS 2.0 or JSON Feed. Auto-source extracts items without hand-written selectors; the companion `botasaurus-scrape-api` service handles JavaScript-rendered sites. The same instance also serves the Feed Directory catalog.

## 60-second quickstart (demo)

1. Download [`docker-compose.quickstart.yml`](./docker-compose.quickstart.yml):

   ```bash
   curl -O https://raw.githubusercontent.com/html2rss/html2rss-web/main/docker-compose.quickstart.yml
   ```

2. Start the stack:

   ```bash
   docker compose -f docker-compose.quickstart.yml up -d
   ```

3. Open [`http://localhost:4000/`](http://localhost:4000/) (or `http://<LAN_IP>:4000/` on your network).
4. When prompted for an access token, use `CHANGE_ME_ADMIN_TOKEN`.
5. Paste a listing, newsroom, changelog, or releases URL and create a feed.

The quickstart runs in development mode for evaluation. For permanent or public hosting, use the production compose below.

## Production deployment

1. Download compose and env template:

   ```bash
   curl -O https://raw.githubusercontent.com/html2rss/html2rss-web/main/docker-compose.yml
   curl -O https://raw.githubusercontent.com/html2rss/html2rss-web/main/.env.example
   cp .env.example .env
   ```

2. Generate secrets and edit `.env`:

   ```bash
   openssl rand -hex 32  # HTML2RSS_SECRET_KEY (>= 32 chars)
   openssl rand -hex 32  # HTML2RSS_ACCESS_TOKEN (>= 16 chars)
   ```

   Keep `AUTO_SOURCE_ENABLED=true` for URL-to-RSS. `HEALTH_CHECK_TOKEN`, `SENTRY_DSN`, and `BOTASAURUS_SENTRY_DSN` are optional.

3. Start:

   ```bash
   docker compose up -d
   ```

   Open `http://localhost:4000/` (or your LAN IP). Paste `HTML2RSS_ACCESS_TOKEN` when the UI asks for it.

## Network and reverse proxy

**Compose exposure:** `html2rss-web` publishes `4000:4000` on all interfaces so LAN devices can reach the UI; protect the instance with `HTML2RSS_ACCESS_TOKEN` (demo token only for quickstart). `botasaurus` stays on the Compose network in quickstart, or `127.0.0.1:4010` in production — never all-interfaces. CI enforces this via `bin/compose-contract-verify`.

Plain HTTP works on localhost and LAN IPs. HSTS and CSP `upgrade-insecure-requests` are set only when the request is HTTPS (including behind a reverse proxy that sends `X-Forwarded-Proto: https`).

For public internet exposure, terminate TLS with Caddy, Nginx, or Traefik and forward to port 4000:

```caddy
feed.example.com {
    reverse_proxy 127.0.0.1:4000
}
```

Alternatively, Falcon supports direct in-process TLS termination and HTTP/2 negotiation by providing certificate and private key paths:

```bash
TLS_CERTIFICATE_PATH=/path/to/fullchain.pem
TLS_KEY_PATH=/path/to/privkey.pem
```

## Custom feeds (escape hatch)

When auto-source is not enough, mount a YAML feeds file:

```yaml
# In docker-compose.yml:
volumes:
  - type: bind
    source: ./config/feeds.yml
    target: /app/config/feeds.yml
    read_only: true
```

See [Creating Custom Feeds](https://html2rss.github.io/creating-custom-feeds/).

## Development (Dev Container)

Run setup, lint, and tests inside the Dev Container:

```bash
make setup
make dev
make ready
```

Feature branches that depend on an unreleased `html2rss` API may pin the gem from GitHub in `Gemfile`. Revert to the released RubyGems version before merging to `main`.

## Resources

- Documentation: https://html2rss.github.io
- Contributing: https://html2rss.github.io/get-involved/contributing
- Docker Hub: https://hub.docker.com/r/html2rss/web
- Discussions: https://github.com/orgs/html2rss/discussions
- Sponsor: https://github.com/sponsors/gildesmarais
