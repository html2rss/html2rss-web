# PR Review: html2rss-web "work" Branch

## Overview
This branch modernises the html2rss-web stack with a Roda backend, stateless feed token model, and an Astro-driven UI. The foundation is promising—security headers, SSRF filtering, and throttling are in place—but several functional gaps, UX rough edges, and at least one high-impact security bug remain before the release feels production ready.

## High-Impact / Blocking Issues
1. **Feed viewers can silently escalate strategies.** The signed feed URL does not record which extraction strategy was authorised at creation time; every GET re-reads the `strategy` query string and passes it to `AutoSource.generate_feed_object` as long as it is a registered strategy.【F:app/api/v1/feeds.rb†L98-L108】 Because the feed token is only bound to the URL, any subscriber can append `?strategy=browserless` (or any other heavy/unsafe strategy) to force the service to use it, bypassing whatever default the feed owner chose. That undermines multi-tenant safety, can reintroduce SSRF risks if an unsafe strategy is ever registered, and makes capacity planning impossible. The `create` path already stores the desired strategy in the response, but the GET handler never enforces it.【F:app/auto_source.rb†L75-L84】
   *Suggested fix:* Encode the authorised strategy into the feed token payload (or persist it server side) and ignore query string overrides when serving public feeds.

2. **Front-end build artefact missing.** The Rack app serves a fallback HTML string whenever `public/frontend/index.html` is absent, which is the case in this branch, so the rich Astro UI never loads from the Ruby server.【F:app.rb†L141-L145】【c86b2c†L1-L2】 Ship the compiled front-end (or wire the build step into the release process) so users see the intended experience.

## UX & Product Rough Edges
- **Authentication & conversion errors are swallowed.** The UI catches failures in `handleAuthSubmit`, `handleFeedSubmit`, and the demo handler but ignores them, so users get no feedback when a login or conversion fails.【F:frontend/src/components/App.tsx†L39-L73】 Surface these errors (e.g., inline messages bound to the existing `field-error` elements) to guide users.
- **Token storage lacks lifecycle cues.** Tokens live indefinitely in `sessionStorage` with no rotation or expiry hints; on refresh, stale credentials are auto-loaded with no validation prompt.【F:frontend/src/hooks/useAuth.ts†L47-L107】 Consider showing last-used info or forcing re-auth when the API responds 401 to avoid confusing silent failures.
- **Result preview hides clipboard/XML errors.** Clipboard failures only log to the console and XML fetch errors render raw strings inside the code block.【F:frontend/src/components/ResultDisplay.tsx†L49-L168】 Replace with visible notices so users understand why copy/preview failed (especially on non-secure origins where Clipboard API is blocked).
- **Demo-to-sign-in path is abrupt.** The "Sign in" CTA simply toggles the form with no explanatory copy about obtaining tokens or security expectations. A short helper link to docs would ease onboarding.

## Security Assessment
- **Positive controls already present.** Strong CSP/default headers are preconfigured,【F:app.rb†L61-L118】 rack-attack throttling guards brute-force abuse,【F:config/rack_attack.rb†L137-L174】 and the SSRF-safe request strategy is registered by default.【F:app.rb†L48-L57】【F:app/ssrf_filter_strategy.rb†L11-L19】
- **Stateless token model trade-offs.** Feed tokens are HMAC-signed, URL-bound, and expire in ten years by default.【F:app/feed_token.rb†L11-L52】 This is acceptable for decentralised hosting if operators understand the blast radius: revoking an individual feed requires rotating the global secret and forcing all users to recreate feeds.【F:frontend/src/content/docs/security.md†L31-L70】 Highlight that limitation prominently (docs already mention it) and provide tooling for mass regeneration.
- **Configuration hygiene enforced.** Environment boot validates that production secrets and per-user tokens meet strength requirements and aborts otherwise,【F:app/environment_validator.rb†L15-L87】 but the sample `feeds.yml` checked into git still contains broad-scope demo tokens.【F:config/feeds.yml†L1-L15】 Ensure deployment docs stress replacing these defaults; ideally ship a template without real tokens.
- **Session storage risk surface.** The browser keeps bearer tokens in `sessionStorage`, exposing them to any third-party script that ever gains execution on the origin.【F:frontend/src/hooks/useAuth.ts†L35-L129】 Combined with the stateless backend, compromise of the origin secret or a stored XSS would be catastrophic. The CSP mitigates this today, but continue to audit dependencies and avoid inline scripts.

## Additional Suggestions
- Enrich the feed creation response with the resolved strategy and TTL so the UI can surface what will be used by default (once the GET handler is corrected).【F:app/api/v1/feeds.rb†L126-L160】
- Provide a first-run wizard or doc link in the UI to explain how to obtain credentials and what "auto source" entails; today the YAML-powered auth model is invisible to end users.
- Consider adding lightweight monitoring endpoints or metrics exporters since the health check currently requires a dedicated credential and only validates config parse state.【F:app/api/v1/health.rb†L17-L52】 A read-only, unauthenticated liveness probe (e.g., `/healthz`) could simplify container orchestration without exposing secrets.

## Next Steps
1. Fix the strategy escalation bug and add regression coverage (RSpec and a contract test that ensures GET ignores query parameters once a feed is minted).
2. Wire the Astro build artefact into the release image and verify `render_index_page` serves it.
3. Improve error reporting in the UI so authentication/creation issues are visible.
4. Document (or better, enforce) token rotation workflows so operators can manage the stateless design safely.
