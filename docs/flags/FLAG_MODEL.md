# Feature Flag Model

## Purpose
Define one typed source of truth for runtime feature flags, including parsing, defaults, ownership, and startup validation rules.

## Registry

| Name | Env key | Type | Default | Owner |
|---|---|---|---|---|
| `auto_source_enabled` | `AUTO_SOURCE_ENABLED` | `boolean` | `development/test: true`, `other: false` | platform |
| `async_feed_refresh_enabled` | `ASYNC_FEED_REFRESH_ENABLED` | `boolean` | `false` | platform |
| `async_feed_refresh_stale_factor` | `ASYNC_FEED_REFRESH_STALE_FACTOR` | `integer` (`>= 1`) | `3` | platform |

## Parsing Rules
- Boolean values accepted: `true`, `false` (case-insensitive).
- Integer values must parse as base-10 integers and satisfy declared constraints.
- Missing values resolve to registry defaults.

## Validation Rules
- Boot must fail fast (`raise`) on malformed flag values.
- Boot must fail fast (`raise`) on unknown feature-style env keys matching managed prefixes:
  - `AUTO_SOURCE_`
  - `ASYNC_FEED_REFRESH_`

## Lifecycle
- Add: registry entry + docs update + tests.
- Change: update registry + migration note in PR description.
- Deprecate: remove env reads from callers first, then remove registry entry.

## Pre-Work Inventory (Current Direct ENV Feature Reads)
- `app/environment_validator.rb` (`AUTO_SOURCE_ENABLED`)
- `app.rb` (`ASYNC_FEED_REFRESH_ENABLED`) [migrated in this revamp]
- `app/feed_runtime.rb` (`ASYNC_FEED_REFRESH_STALE_FACTOR`)
