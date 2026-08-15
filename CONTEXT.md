# Domain Context: html2rss-web

This documents the ubiquitous language and domain concepts of the `html2rss-web` service.

## Glossary

### Session
The user's active session context containing the Access Token (for authentication/privileges) and the API Metadata (defining instance config, features, and featured feeds).

### Access Token
A persistent secret token used to authenticate feed creation requests against the instance's security gate.

### Feed Flow
The process of capturing a target page URL, validating it, converting it to an RSS/JSON feed, and monitoring the preview.

### Auto-Submit
A mechanism that automatically initiates feed creation when a prefilled URL is passed to the application route (e.g. from the bookmarklet).

### Renderer
Backend feed HTTP assembly: `Feeds::Renderer` owns the HTTP envelope and success serialization, and orchestrates `Feeds::FormatNegotiation` (Accept/path negotiation; `FormatNegotiation::MediaRange` for Accept scoring). Empty FEED bodies dump `ErrorClassifier::Decision#message`.

### Decision
`ErrorClassifier::Decision` owns HTTP status, code, client message, kind, cacheability, and retry metadata for classified outcomes. Feed serve and API create/error paths share it; serializers only apply it (JSON via `ErrorResponder`, plain text via `Feeds::Renderer`).

### Create-Time Extraction
Feed creation runs `Feeds::Service` (same owner as serve) before minting a feed token. Fail closed on empty. On `:ok`, mint and reuse the warmed `Feeds::Cache` entry.

### Observability
Product telemetry: dotted `event_name` + `outcome`. Includes `auth.*`, `feed.*`, `request.error`, `cache.lifecycle`, `config.validation`. No IP / user-agent.

### Security Logging
Audit channel: snake_case `security_event` with IP / user-agent / token hash. Auth, rate-limit, token usage, blocked requests. Dual-emit with Observability on auth is required.

### LogEvent
Shared emit plumbing for both channels (`RequestContext`, `LogSanitizer`, `AppLogger` / Sentry). Not a third public facade.
