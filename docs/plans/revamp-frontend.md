# Revamp: Frontend & Governance — Delivery Plan

**Branch:** `feat/revamp-frontend`
**Release type:** Major — breaking changes; no backward compatibility.
**Regression gate:** Manual e2e by author.
**Primary quality goal:** Elegant, simple, readable Ruby. Subtract accidental complexity; add only what earns its weight.

---

## Scope

Focus areas 2, 4, 5, 6:

- **2** — AppContext and typed application state wiring
- **4** — Observability contract (event schema)
- **5** — OpenAPI as source of truth (code-first)
- **6** — Centralized feature flag model

---

## Principles

- **Code-first OpenAPI.** Implement, then generate the spec. The spec reflects what the code does — not a design artifact written ahead of it.
- **Design-first docs.** Each governance document is written before its phase begins. Docs gate implementation.
- **No backward compatibility.** No adapters, shims, or migration layers. This is a major release.
- **Hard-fail on misconfiguration.** Unknown or malformed flags raise at startup. No graceful degradation.
- **Simplicity over structure.** Every added layer must justify itself. Prefer flat, direct, readable code. When in doubt, do less.

---

## Assumptions Check (Code-Backed, 2026-03-01)

1. Assumption: `AppContext` already exists or has a migration scaffold.
Status: **invalid**.
Evidence:
- No `AppContext` implementation found in `app/` or `frontend/`.
- Boot still wires dependencies directly in [`app.rb`](/Users/gil/versioned/html2rss/html2rss-web/app.rb).

2. Assumption: typed application state wiring is already centralized.
Status: **partially confirmed**.
Evidence:
- Frontend uses typed interfaces and hook-local state in [`frontend/src/components/App.tsx`](/Users/gil/versioned/html2rss/html2rss-web/frontend/src/components/App.tsx) and [`frontend/src/hooks/useAuth.ts`](/Users/gil/versioned/html2rss/html2rss-web/frontend/src/hooks/useAuth.ts).
- No shared frontend AppContext/store abstraction exists yet.

3. Assumption: governance docs referenced by this plan already exist.
Status: **invalid**.
Evidence:
- Missing: `docs/adr/0006-app-context.md`, `docs/flags/FLAG_MODEL.md`, `docs/observability/EVENT_SCHEMA.md`, `docs/api/CONTRACT_POLICY.md`.

4. Assumption: feature-flag reads are centralized and validated.
Status: **invalid**.
Evidence:
- Direct `ENV` feature/config reads exist in [`app/environment_validator.rb`](/Users/gil/versioned/html2rss/html2rss-web/app/environment_validator.rb), [`app.rb`](/Users/gil/versioned/html2rss/html2rss-web/app.rb), [`app/feed_runtime.rb`](/Users/gil/versioned/html2rss/html2rss-web/app/feed_runtime.rb), [`app/api/v1/health.rb`](/Users/gil/versioned/html2rss/html2rss-web/app/api/v1/health.rb), and [`app/auth.rb`](/Users/gil/versioned/html2rss/html2rss-web/app/auth.rb).

5. Assumption: observability schema fields in this plan are already emitted.
Status: **partially confirmed**.
Evidence:
- Request context provides `request_id`, `route_group`, `actor` in [`app/request_context.rb`](/Users/gil/versioned/html2rss/html2rss-web/app/request_context.rb).
- Structured logs currently emit `security_event` and context fields in [`app/security_logger.rb`](/Users/gil/versioned/html2rss/html2rss-web/app/security_logger.rb), but not the proposed contract fields `event_name`, `schema_version`, `outcome`.

6. Assumption: OpenAPI and frontend client drift checks are fully enforced in CI.
Status: **partially confirmed**.
Evidence:
- `Makefile` contains `openapi`, `openapi-verify`, `openapi-client-verify`, and `openapi-lint` targets.
- CI currently enforces backend spec drift (`bundle exec rake openapi:verify`) in [`.github/workflows/ci.yml`](/Users/gil/versioned/html2rss/html2rss-web/.github/workflows/ci.yml), but does not explicitly run `make openapi-lint` or `npm run openapi:verify` in frontend CI.

---

## Phases

### Phase A — AppContext

**Governance doc first:** `docs/adr/0006-app-context.md`

Before implementation, define:
- AppContext structure and responsibility boundary.
- Dependency graph: config, auth, flags, logger, metrics, runtime.
- Boot order and initialization contract.

**Implementation**

- Introduce AppContext as the single wiring point for application dependencies.
- Remove module-level globals; pass dependencies explicitly.
- No adapters or compatibility shims — direct wiring only.

**Rollback:** Revert phase commits on branch. No production state to unwind.

**Done when:** AppContext boots cleanly; all dependencies resolve at startup; no global state leaks.

---

### Phase B — Feature Flags

**Governance doc first:** `docs/flags/FLAG_MODEL.md`

Before implementation, define:
- Typed registry schema: name, type, default, owner, lifecycle (add / change / deprecate).
- ENV mapping policy.
- Pre-work inventory: record current direct `ENV` reads and map each to Flags registry ownership.

**Implementation**

- Introduce Flags registry as the sole source of truth for all feature flags.
- All flag reads route through the registry — zero direct `ENV[]` checks for feature decisions.
- Startup validation: `raise` on unknown or malformed flag. No warn-and-continue.

**Rollback:** Revert phase commits on branch.

**Done when:** No direct `ENV[]` feature checks exist outside the Flags module; app raises on unknown flags at boot.

---

### Phase C — Observability

**Governance doc first:** `docs/observability/EVENT_SCHEMA.md`

Before implementation, define:
- Required event fields: `event_name`, `schema_version`, `request_id`, `route_group`, `actor`, `outcome`.
- Event categories and log/metric pairing matrix.
- Coverage is a contract by convention — not enforced by an automated CI metric.

**Implementation**

- Add structured event emission at critical paths: auth, feed create, feed render, errors.
- All covered paths must emit structured log output with the required schema fields.

**Rollback:** Revert phase commits on branch.

**Done when:** All documented critical paths emit structured events with required fields; schema doc and implementation agree.

---

### Phase D — OpenAPI

**Governance doc first:** `docs/api/CONTRACT_POLICY.md`

Before implementation, define:
- Code-first generation policy: spec is generated from implementation.
- Drift enforcement: CI fails if the committed spec diverges from the freshly generated one.
- Frontend client generation policy and drift check.

**Implementation**

- Implement API endpoints (shapes are up for grabs — no contract is frozen from any prior version).
- Generate OpenAPI spec from implementation.
- Use existing `make openapi-verify` and `make openapi-lint` targets as the contract gate.
- Wire/enforce drift + lint checks in CI pipeline (including frontend generated-client drift verification).
- Regenerate frontend client from spec; wire into the frontend build.

**Rollback:** Revert phase commits on branch.

**Done when:** `make openapi-verify` and `make openapi-lint` pass; CI fails on spec/client drift; frontend client is generated, not hand-written.

---

## Acceptance Criteria

- `make ready` passes inside the Dev Container.
- `make openapi-verify` and `make openapi-lint` pass.
- CI fails on OpenAPI spec / frontend client drift.
- No direct `ENV[]` feature checks outside the Flags module.
- App raises at startup on unknown or malformed flags.
- All critical paths (auth, feed create, feed render, errors) emit structured events with required schema fields.
- No backward-compat adapters, shims, or migration layers anywhere in the codebase.

---

## Commit Slices

| # | Commit message |
|---|----------------|
| 1 | `docs(arch): AppContext design ADR and flag model spec` |
| 2 | `refactor(core): introduce AppContext and explicit dependency wiring` |
| 3 | `refactor(flags): centralize flag registry with hard-crash startup validation` |
| 4 | `docs(observability): event schema contract` |
| 5 | `feat(observability): structured event emission at critical paths` |
| 6 | `feat(api): implement endpoints and generate OpenAPI spec` |
| 7 | `feat(api-contract): add openapi-verify, openapi-lint, and CI drift enforcement` |
| 8 | `docs(architecture): contract policy and governance index` |
