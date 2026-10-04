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

### Catalog Find
On create, `findCatalogEntries` matches the typed query against the catalog (URL equivalence after create-time expansion, plus case-insensitive substring on title/description/id/channelUrl). Hits (capped) render as a subordinate included-feeds list under the URL field via `catalogFeedHref` (path + parameter defaults). Create stays primary. Browse stays on the docs Feed Directory.

### CreateEntry remount
Visiting create (including hashbang `#!/…` → `#/…`) bumps `createEntryKey` so the create surface remounts. Remount alone does not auto-submit; auto-submit requires `prefillUrl`.

### Config Studio
Selector refinement for a token holder when studio is enabled. One result frame has two phases: **unresolved** (create returned `EXTRACTION_EMPTY`, studio on, access token present — in-memory `#/result` with no feed token; the flat editor mounts immediately; **Save and generate feed** is primary; wire `Decision#message` is the notice) and **ready** (`#/result/:token` after items mint — **Copy feed URL** primary; flat editor mounts with zero clicks to reveal; **Save and generate feed** stays demoted until the draft changes; one meadow; live studio output replaces the result preview after an edit). Studio off or no token keeps empty extraction on create. The listing URL stays the subject; **Create another feed** starts a new listing. The visual builder and YAML are one document: validate exports `channel.url` plus selectors. A successful validate echo keeps the server’s items selector and enhance flag; the client keeps the field selectors it authored. Only `studioService` unwraps the studio envelope and maps ranked `candidates` (items / title / link / published) into domain suggestion buckets. Candidates never auto-apply. Suggestion outcomes are explicit: loading, ready, valid-empty, and failed+retry stay non-blocking while the editor remains editable. Optional Title / Link / Published fields appear only for selector, candidate, issue, or manual evidence; one **Add …** activator reveals dormant fields. Chips add or remove selector parts on the authored comma-joined string; suggest does not write that string, and chips do not change Enhance. Field extractors remain fixed by the draft mapper. Save posts studio selectors through Creation IO and stays on the result view (unresolved → ready when items mint). On ready, demoted **Open Feed Directory issue** opens a prefilled html2rss-configs GitHub issue (no tokens); it is a handoff for Riley, not SPA directory authoring. There is no `#/refine` route and no collapsed Refine disclosure.

### SelectorsDocument
The full gem `selectors` subtree a token holder may attach on feed creation after the root-key gate (`CLIENT_ROOT_KEYS`) and gem schema validate. Runtime type `Html2rss::Web::SelectorsDocument`; OpenAPI component `SelectorsDocument`. Signed into the feed token and resolved on later serves. Not a full config: channel, headers, and strategy stay denied by the root-key gate (not a second web shape allowlist).

### StudioSelectors
SPA studio outbound / draft projection only: `items` (selector + optional enhance), `title`, `url`, `published_at`. Hydrate fails closed when the document carries keys outside that subset (e.g. `order`, `pagination`, `guid`). Not the full `SelectorsDocument`.

### Unmatched result
A result route without matching in-memory workspace: ready requires a created feed whose token matches (or leads) the route `feedToken`; unresolved requires in-memory empty-extraction workspace on bare `#/result`. Feed Flow replaces to create without prefill (no second journey decide elsewhere).

### Renderer
Backend feed HTTP assembly: `Feeds::Renderer` owns the HTTP envelope and success serialization, and orchestrates `Feeds::FormatNegotiation` (Accept/path negotiation; `FormatNegotiation::MediaRange` for Accept scoring). Empty FEED bodies dump `ErrorClassifier::Decision#message`.

### Responder
Backend feed route orchestration: resolve → render → emit `feed.render` from `RenderResult` fields only (Decision + Diagnostics). Exception `emit_failure` is for failures outside a completed Service result.

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
