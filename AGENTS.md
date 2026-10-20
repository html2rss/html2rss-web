# AGENTS.md

Canonical references:
- Contributor guide, setup, architecture, security, observability: [docs/README.md](docs/README.md)
- Domain glossary and seam ownership: [CONTEXT.md](CONTEXT.md)
- Visual, CSS primitive, and journey grammar contracts: [docs/design-system.md](docs/design-system.md)

## Execution & Coding Contracts

- **Posture:** Time matters. Reduce LOC when possible. No legacy code, no backward compatibility, no shims.
- **Dev Container only:** Run all commands inside the Dev Container via `make` or `bundle exec`. Never execute on the host.
- **Quality gate:** Never push or open a PR without a green Dev Container gate (`make ready` minimum, which includes `pnpm run format:check` via `lint-js`; `make ci-ready` before push/PR for frontend or API/OpenAPI contract changes). Never mark validation done or open a PR with "gate skipped / unavailable" — start the Dev Container and run the gate, or stop and report the blocker plus next command.
- **Frontend verification:** With `make dev` running, verify touched paths in `chrome-devtools` MCP at `http://127.0.0.1:4001/`. Confirm affected states (guest/member/result) share the same frame, keep one primary task and one canonical control per outcome, and preserve autofocus/return-focus on load and transitions ([docs/design-system.md](docs/design-system.md)).
- **Security & YARD:** No leaking secrets or insecure patterns ([docs/README.md#security--safety-rules](docs/README.md#security--safety-rules)). Every public Ruby method in `app/` requires a YARD docstring with typed `@param` and `@return` ([docs/README.md#architectural-constraints](docs/README.md#architectural-constraints)).
- **Response format:** `Changes → Commands → Results → Next steps`, ending with a one-line summary.

## Ship follow-through

When a task that should ship merges to `main`, ask whether to bump the app version before any further release step. Do not dispatch [`.github/workflows/bump-version.yml`](.github/workflows/bump-version.yml) until the user answers with `auto`, `patch`, `minor`, `major`, or `custom` plus a semver (`X.Y.Z`).

### html2rss gem pickup

1. Wait until `html2rss/html2rss`'s `release gem` workflow for the tag is `success` (a merged version PR is not on RubyGems yet; `bundle update html2rss` keeps the old pin).
2. `git fetch origin main` and branch from `origin/main`. Never continue a feature branch or commit the lockfile onto `main`.
3. In the Dev Container, run `bundle update html2rss`, then `make ready`. Do not run a full `bundle update` unless asked. Keep the Gemfile constraint `~> 0.30` unless resolution fails.
4. Open a lockfile PR and watch required checks (`frontend`, `ruby`, `docker-test (false)`, `docker-test (true)`) with `gh pr checks <n> --watch`.
5. Mergify queues only Dependabot. When asked to merge and checks are green, run `gh pr merge <n> --squash --delete-branch` (merge commits disabled).
6. Stop and ask whether to bump the app version. Dispatch the version workflow only after the gem PR is on `main`.

### App version bump

Dispatch only after the user names the bump (`--ref main` is required; pass `custom_version` only when `bump_type=custom`):

```sh
gh workflow run bump-version.yml --ref main -f bump_type=<auto|patch|minor|major|custom> -f custom_version=<X.Y.Z>
```

Watch the run to `success` (`bump-version/v<version>`), wait for the same required checks, and squash-merge when asked. Do not publish the draft GitHub release unless asked.

## Config catalog API

- **Endpoint & flag:** `GET /api/v1/configs` (`CONFIG_CATALOG_ENABLED`, default `true`; `false` returns `404` with `{ "error": "catalog_disabled" }`). Route-scoped CORS on `/api/v1/configs` only (`GET`, `OPTIONS`). Root metadata `GET /api/v1/` exposes `instance.catalog: { enabled, url }`.
- **Sources & merge:** Embedded entries come from `Html2rss::Configs::Catalog.entries` (never re-walk YAML in the handler). `Catalog::Merge` includes local `feeds.yml` feeds only when `directory.title` is set.
- **Envelope & health:** `catalog_version` is `2` (clients fail closed on other versions). Every entry requires `last_result` (`ok`/`empty`/`error`/`unknown`) from process-local `Feeds::LastResults`.
- **UI wiring:** Starters use server `meta.starters` (`Catalog::Starters.pick`) and frontend `selectStarterFeeds(entries, starters)`. `findCatalogEntries` renders a multi-hit list under the create URL, demotes `empty`/`error`, and links via `catalogFeedHref`.
- **Contract SSOT:** `spec/html2rss/web/api/v1_spec.rb` and generated `public/openapi.yaml`. After handler or envelope changes, run `make openapi` and `make ci-ready`.
