# Agent Workflow Constraints

This document defines execution constraints for AI agents. For general contributor rules, setup commands, architectural constraints, and security policies, see [docs/README.md](docs/README.md).

## Collaboration Agreement (Agent ↔ User)

- **DoD:** `make ready` in Dev Container; if applicable, user completes manual smoke test with agent-provided steps.
- **Verification:** Always smoke Dev Container + `make ready`.
- **PR open gate:** Do not push or open a PR until the quality gate passes **inside the Dev Container**. Host-only shortcuts (e.g. frontend `vitest` + `eslint` alone) are not a substitute. Never mark Validation as done or open a PR with “gate skipped / unavailable” — start the Dev Container and run the gate, or stop and report the blocker without opening the PR.
- **Commits:** Group by logical unit after smoke-tested (feature / improvement / refactor).
- **Responses:** Changes → Commands → Results → Next steps, ending with a concise one-line summary.
- **KISS vs Refactor:** KISS by default; boy-scout refactors allowed if low-risk and simplifying.
- **Ambiguity:** Proceed with safest assumption, then confirm.
- **Non-negotiables:** Dev Container only; security first.

## Agent-Specific Verification Rules

- Always run Dev Container smoke + `make ready` for changes.
- For frontend changes or API contract/spec changes, run `make ci-ready` before push/PR open to mirror CI parity checks (`ready` + OpenAPI verify + frontend e2e smoke).
- For frontend-only changes when `make ci-ready` is too heavy mid-task, still run at minimum inside Dev Container: `make ready` (includes `pnpm run format:check` via `lint-js`). Prettier failures are a common CI break — never skip format check.
- For frontend changes, also verify in `chrome-devtools` MCP at `http://127.0.0.1:4001/` while the Dev Container is running.
- Capture a quick state check for all affected UI states (e.g., guest/member/result) to enforce state parity and avoid duplicate actions.

### Frontend Smoke Checklist

- Start the Dev Container and app (`make dev`).
- Open `http://127.0.0.1:4001/` with `chrome-devtools` MCP.
- Validate the primary user path touched by the change.
- Verify all affected states (e.g., guest/member/result) keep the same layout grammar.
- Confirm action uniqueness: one canonical control per outcome in each state.

## UI Execution Principles

See [docs/design-system.md](docs/design-system.md) for visual rules.

- **Task Dominance:** Each UI state should make one user objective obvious and primary. Supporting surfaces and links must yield priority.
- **Copy Minimalism:** Remove text that repeats what the interface already communicates. Prefer action-oriented wording.
- **State Skeleton:** Adjacent UI states should read as the same frame with content changes, not as separate pages.
- **Focus Contract:** Verify browser autofocus and return-focus behavior on initial load and after transitions.
- **Support Compression:** When a user has advanced past setup, reduce the visual weight of support content.

## Response Format

1. **Changes:** Briefly list files/symbols modified.
2. **Commands:** Show the verification commands run.
3. **Results:** Summarize the outcome.
4. **Next steps:** Propose the immediate follow-up.
5. **One-line Summary:** End with a concise summary.

## Non-Negotiables

- **Security first:** No leaking secrets or insecure patterns. See [Security & Safety Rules](docs/README.md#security--safety-rules).
- **YARD docs:** Strict for public Ruby methods in `app/`. Every public method must have a YARD docstring with typed `@param` and `@return`. See [Architectural Constraints](docs/README.md#architectural-constraints).
- **No host execution:** All commands MUST run inside the Dev Container via `make` or `bundle exec`.
- **No skipped quality gate:** Opening a PR without a green Dev Container gate is forbidden. If the gate cannot run, do not open the PR; fix the environment or hand off with explicit blocker + next command for the user.

## Config catalog API

Public feed-directory metadata from verified registry bundles and local `feeds.yml` entries.

| Item | Detail |
| --- | --- |
| Endpoint | `GET /api/v1/configs` |
| Flag | `CONFIG_CATALOG_ENABLED` (default `true`; set `false` to disable) |
| Disabled response | `404` with `{ "error": "catalog_disabled" }` |
| Registry entries | `Registry::Index.current.catalog_rows` — loads signed bundles from `config/registries.yml`; adds `source: registry`, `registry: <id>` |
| Local entries | `Registry::LocalCatalog` includes `feeds.yml` feeds only when `directory.title` is set (`source: local`) |
| Per-registry privacy | `catalog: false` in `registries.yml` omits that registry from the API (feeds still served) |
| Starter feeds (UI) | Frontend `selectStarterFeeds` when feed creation is disabled; catalog find uses full catalog when enabled |
| Catalog find | `findCatalogEntries` → multi-hit list under create URL; links via `catalogFeedHref` (path + defaults) |
| CORS | Route-scoped on `/api/v1/configs` only (`GET`, `OPTIONS`) |
| Root metadata | `GET /api/v1/` exposes `instance.catalog: { enabled, url }` and `instance.registries` sync status |
| Contract SSOT | Request specs under `spec/html2rss/web/api/v1_spec.rb` and generated `public/openapi.yaml` |

Registry sync: `bin/registry-sync --status`; boot seed + optional sync via `Registry::Sync.boot!`. See [docs/README.md](docs/README.md#registry-sync-runbook).

After handler or envelope changes: `make openapi` and `make ci-ready`.
