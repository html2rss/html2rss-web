# Domain Context: html2rss-web

This documents the ubiquitous language and domain concepts of the `html2rss-web` service.

## Glossary

### Session
Frontend owner of Access Token persistence (rehydrate / save / clear until Logout) and feed-creation gate predicates derived from API Metadata (`feed_creation.enabled`, `access_token_required`). Session exposes `mayCreate` / `feedCreationEnabled`; it does not own route transitions. Logout clear is Session; navigate-to-create after logout is App.

### Access Token
A persistent secret token used to authenticate feed creation requests against the instance's security gate. Durable copy lives only in Session storage; Authorization header adapter sends it on create. Ephemeral gate draft must clear on cancel, logout, and create remount — never in COPY, logs, or view-model dumps.

### Feed Flow
Sole frontend journey owner for create → submit → token prompt → result / error. Owns the closed UI kind set and journey `navigate(...)` transitions (auth rejection → token route, unmatched result → create without prefill). Distinct from backend `ErrorClassifier::Decision` and from Creation IO.

### Creation IO
Network-only feed create (`requestFeedCreation` / `useFeedCreation`). Accepts an already-normalized URL. Does not own journey kind, navigation, or user-facing sentences.

### Auto-Submit
A mechanism that automatically initiates feed creation when a prefilled URL is passed to the application route (e.g. from the bookmarklet). Bare create remount without `prefillUrl` does not auto-submit.

### Create-Time URL Expansion
Single frontend path (`expandCreateUrl`) that normalizes the create URL before Creation IO. Field-error copy for empty/invalid is mapped by Feed Flow from COPY.

### CreateEntry remount
Visiting create (including hashbang `#!/…` → `#/…`) bumps `createEntryKey` so the create surface remounts. Remount alone does not auto-submit; auto-submit requires `prefillUrl`.

### Unmatched result
A result route whose in-memory created feed token does not match the route `feedToken`. Feed Flow replaces to create without prefill (no second journey decide elsewhere).

### Renderer
Backend feed HTTP assembly: `Feeds::Renderer` owns the HTTP envelope and success serialization, and orchestrates `Feeds::FormatNegotiation` (Accept/path negotiation; `FormatNegotiation::MediaRange` for Accept scoring). Empty FEED bodies dump `ErrorClassifier::Decision#message`.

### Decision
Backend only: `ErrorClassifier::Decision` owns HTTP status, code, client message, kind, cacheability, and retry metadata for classified outcomes. Required on every non-ok `Feeds::Contracts::RenderResult` (construction fails closed). Feed serve and API create/error paths share it; serializers and CreateFeed only apply it (JSON via `ErrorResponder`, plain text via `Feeds::Renderer`). Not the frontend journey closed set (see Feed Flow).

### Diagnostics
Backend only: `ErrorClassifier::Diagnostics` owns gem strategy-attempt dig and transport-meta expansion. Attached on `RenderResult` for empty and hard-error Service outcomes; Renderer and Observability emit read it (no second dig).

### Create-Time Extraction
Feed creation runs `Feeds::Service` (same owner as serve) before minting a feed token. Fail closed on empty. On `:ok`, mint and reuse the warmed `Feeds::Cache` entry.

### Observability
Product telemetry: dotted `event_name` + `outcome`. Includes `auth.*`, `feed.*`, `request.error`, `cache.lifecycle`, `config.validation`. No IP / user-agent.

### Security Logging
Audit channel: snake_case `security_event` with IP / user-agent / token hash. Auth, rate-limit, token usage, blocked requests. Dual-emit with Observability on auth is required.

### LogEvent
Shared emit plumbing for both channels (`RequestContext`, `LogSanitizer`, `AppLogger` / Sentry). Not a third public facade.
