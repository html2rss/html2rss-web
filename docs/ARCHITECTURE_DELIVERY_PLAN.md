# Architecture Delivery Plan

## Goal
Deliver a production-strong, low-risk architecture evolution for `html2rss-web` with phased rollout, explicit contracts, and CI-enforced safety.

This plan is based on direct code scan plus Roda documentation review (Context7: `/jeremyevans/roda`).

## Feasibility Verdict
Feasible to deliver autonomously in phased slices.

Why:
- Existing module boundaries already separate routing, feed orchestration, auth, config, and API response shaping.
- Safety rails already exist (`make ready`, strict YARD gate, OpenAPI generation/lint paths).
- Most proposed changes can be introduced behind compatibility adapters without API or XML contract breaks.

Primary constraint:
- Async feed refresh introduces the largest operational risk and should be introduced last, behind a feature toggle.

## Validated Baseline (Code-Backed)

1. Assumption: boundary contracts are hash-heavy.
Status: confirmed.
Evidence:
- `LocalConfig.find`/`global` return mutable-shape hashes.
- `Auth.authenticate`, `AccountManager` lookups, `AutoSource.create_stable_feed`, `CreateFeed.call`, `ShowFeed.call` pass hash payloads across boundaries.

2. Assumption: feed generation is mostly synchronous in request path.
Status: confirmed.
Evidence:
- `App#handle_feed_generation` calls `Feeds.generate_feed` inline.
- `ShowFeed#render_generated_feed` calls `AutoSource.generate_feed_object` and processes output inline.

3. Assumption: error handling is centralized but context-poor.
Status: partially confirmed.
Evidence:
- Centralized `plugin :error_handler` delegates to `ErrorResponder`.
- `SecurityLogger` is structured JSON but has no mandatory request correlation contract (no request context model).

4. Assumption: configuration is centralized but not typed.
Status: confirmed.
Evidence:
- `LocalConfig` loads YAML with symbolized hashes; callers use `dig` and hash semantics.
- `AccountManager` snapshots are immutable but still hash-based.

5. Assumption: OpenAPI exists but frontend generated client is not enforced.
Status: confirmed.
Evidence:
- `docs/api/v1/openapi.yaml` present.
- `Makefile` includes `openapi`, `openapi-verify`, and lint targets.
- Frontend has no generated OpenAPI client dependency/config yet.

## Target Outcomes
- Explicit immutable boundary models (`Data`) for high-churn app contracts.
- Request-context observability with durable correlation keys.
- Typed validated runtime configuration snapshots.
- Contract-first backend/frontend sync via generated client.
- Optional async/stale-while-revalidate feed pipeline with rollback control.

## Roda-Aligned Delivery Notes
- Keep route tree composition through existing `Routes::ApiV1` and `Routes::Static` seams.
- Introduce request context at Rack/request edge (`request.env`) and pass via narrow adapters.
- Keep `plugin :error_handler` as single top-level rescue path, enriching payload/log context rather than splitting rescue logic across routes.
- Prefer additive plugins/middleware and feature toggles over route rewrites.

## Phase Plan

## Phase 0: ADR + Contracts Baseline (1-2 days)
Deliverables:
- ADR-001 boundary `Data` model policy.
- ADR-002 request context + log contract.
- ADR-003 typed config schema + failure modes.
- ADR-004 OpenAPI generated client policy.
- ADR-005 async refresh architecture guardrails.

Exit criteria:
- ADRs accepted with rollback notes and migration order.

## Phase 1: Typed Config Snapshot (2-4 days)
Deliverables:
- Config schema and typed `Data` models for global/auth/feed config nodes.
- Validation at boot/reload with explicit error diagnostics.
- Compatibility adapter so existing hash consumers continue to work.

Acceptance:
- Invalid config fails fast outside development.
- Existing behavior unchanged for valid config.

Risks:
- Hidden optional keys in feeds config.
Mitigation:
- Add schema for optional keys with defaults and targeted migration warnings.

## Phase 2: Request Context + Observability Contract (2-4 days)
Deliverables:
- RequestContext model (request_id, path, method, actor, route_group, strategy, duration_ms).
- Context initializer and propagation helpers.
- `ErrorResponder` and `SecurityLogger` context-aware logging.

Acceptance:
- Logs for failures/auth/token usage include request correlation keys.
- No API response shape regression.

Risks:
- Leaking sensitive token data.
Mitigation:
- Keep hashing/fingerprinting policy; never log raw token.

## Phase 3: Boundary `Data` Models at API Edges (4-7 days)
Deliverables:
- Replace hash contracts first in:
  - Auth/account context.
  - API feed create params.
  - API feed response payload internals.
  - Feed metadata boundary between `AutoSource` and API layer.
- Add bidirectional adapters (`Hash` <-> `Data`) while migrating.

Acceptance:
- Public HTTP contracts unchanged.
- No cyclomatic complexity increase in touched methods.

Risks:
- Broad refactor blast radius.
Mitigation:
- Strangler approach by edge-first modules, one boundary at a time.

## Phase 4: OpenAPI-Generated Frontend Client (2-3 days)
Deliverables:
- Add `@hey-api/openapi-ts` setup in frontend.
- Generate typed client from `docs/api/v1/openapi.yaml`.
- Replace handwritten API types/usages for covered endpoints.
- CI drift check for generated client.

Acceptance:
- Frontend compiles against generated types.
- Spec/client drift fails CI.

Risks:
- Divergence between generated models and existing UI assumptions.
Mitigation:
- Introduce thin compatibility wrapper to phase migration.

## Phase 5: Pluggable Async Refresh (5-10 days)
Deliverables:
- Pipeline contract (`Fetch -> Extract -> Normalize -> Render -> Cache`).
- Cache-first read path with stale-while-revalidate option.
- Async refresh path with bounded retries and visibility.
- Feature flag to revert to sync path immediately.

Acceptance:
- Stable response behavior under upstream slowness/failures.
- Observable refresh outcomes and queue depth.

Risks:
- Operational complexity.
Mitigation:
- Keep minimal worker model first; add scaling patterns only with measured need.

## Autonomous Delivery Execution Plan
Delivery can be performed autonomously with pre-commit gating on each slice:

1. Implement one phase at a time behind flags/adapters.
2. Run inside Dev Container only.
3. Run `make ready` before each commit.
4. Keep commits single-concern and reversible.
5. Include short migration notes in commit body when contracts move.

## Commit Packaging Plan (commit-intent)
Expected commit sequence for implementation (example titles):

1. `docs(architecture): ratify phased delivery plan with validated assumptions`
2. `refactor(config): introduce typed config snapshot with compatibility adapter`
3. `feat(observability): add request context contract and correlated logging`
4. `refactor(api): migrate feed/auth boundaries to Data-backed contracts`
5. `feat(frontend-api): generate OpenAPI client and enforce drift checks`
6. `feat(feed-runtime): add async refresh pipeline behind feature flag`

Outlier rule:
- If a cross-cutting commit is unavoidable, mark it explicitly as an outlier with rollback boundary in the commit body.

## Definition of Done per Phase
- `make ready` passes in Dev Container.
- No regressions in API shape or feed XML semantics unless explicitly planned.
- Rollback path documented and tested for the phase.

## Immediate Next Step
Start Phase 0 ADR set and lock naming/ownership of boundary `Data` types before code changes.
