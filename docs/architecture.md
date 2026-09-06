# Architecture & Request Lifecycle

This document provides a mental model of how `html2rss-web` processes requests.

## Server & Adapter Stack

```
Client (HTTP/1.1 or HTTP/2)
   │
   ▼
[Falcon Server] (Terminates TLS / HTTP/2 multiplexing, fiber-based async reactor)
   │
   ▼
[Roda Routing Tree] (Stateless routing & parameter validation)
   │
   ├──▶ [HTTPX] (Non-blocking cooperative fiber I/O to upstream HTML)
   └──▶ [Botasaurus Scrape API] (Browser/dynamic scraping via HTTPX)
```

## High-Level Data Flow

```mermaid
flowchart TD
    user["User / RSS Reader"] --> falcon["Falcon Server (HTTP/1.1 & HTTP/2)"]
    falcon --> routes["Roda App (app/web/routes)"]
    security["Auth / Security (app/web/security)"] --> routes
    routes --> feeds["Feeds Service (app/web/feeds)"]
    cache["Cache (app/web/feeds/cache.rb)"] --> feeds
    feeds --> gem["html2rss Gem"]
    strategies["Request Strategies (HTTPX / Botasaurus)"] --> gem
    gem --> target["Target Website"]
```

## Request Lifecycle

### 1. Routing & Auth

Requests enter via `Falcon`, dispatch through `config.ru` and `app.rb`, and are routed to `app/web/routes/`.

- **Static feed pages (`/<feed_name>`)**: Routed by `app/web/routes/feed_pages.rb` and resolved as `target_kind: :static`.
  - Source: static config in `config/feeds.yml` (via `LocalConfig.find`).
  - Auth boundary: no feed token required on this route.
  - Failure mode: unknown feed names fail at static config lookup.
- **Token-backed feed reads (`/api/v1/feeds/:token`)**: Routed by `app/web/routes/api_v1/feed_routes.rb` and resolved as `target_kind: :token`.
  - Token scope: `FeedAccess.authorize_feed_token!` validates signature/expiry and re-checks account URL access.
  - Constraint: disabled when AutoSource is off (`ForbiddenError` from `SourceResolver.ensure_auto_source_enabled!`).
- **Feed creation (`POST /api/v1/feeds`)**: Authenticated via bearer token in `app/web/security/auth.rb`; this endpoint mints feed tokens for subsequent token-backed reads.

### 2. Resolution

The `Html2rss::Web::Feeds::SourceResolver` determines where feed configuration comes from based on route target:

- **Static (`target_kind: :static`)**: Pre-defined in `config/feeds.yml`.
- **Token (`target_kind: :token`)**: Generated from validated feed token payload + AutoSource globals.

### 3. Fetching & Rendering

The `Html2rss::Web::Feeds::Service` orchestrates extraction behind a gem `FeedResult`:

1. Checks the `Html2rss::Web::Feeds::Cache`.
2. If stale/missing, calls the `html2rss` gem with the resolved strategy and wraps the gem `FeedResult` in a web `RenderResult`.
3. Feed HTTP responses are split across render peers:
   - `Html2rss::Web::Feeds::FormatNegotiation` — Accept/path negotiation, `strip_known_extension`, and format/content-type constants used for negotiation (`FormatNegotiation::MediaRange` for Accept scoring).
   - `Html2rss::Web::Feeds::Renderer` — empty FEED bodies dump `ErrorClassifier::Decision#message`.
   - `Html2rss::Web::Feeds::Renderer` — HTTP envelope + success serialization; orchestrates the peers (including plain-text error bodies).

## Extension Points

### Adding a Request Strategy

Strategies are defined by the `html2rss` gem but can be configured here.

- **HTTPX**: Default non-blocking HTTP transport layer for static HTML. It natively cooperates with the Ruby Fiber scheduler for connection pooling, keep-alive, and HTTP/2 multiplexing across upstream requests.
- **Botasaurus**: Used for JavaScript-heavy websites or anti-bot protected pages (`BOTASAURUS_SCRAPER_URL`).

To add or configure strategies, see `app/web/feeds/source_resolver.rb` and the `html2rss` gem documentation.
