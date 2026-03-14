# ADR-0006: AppContext as Dependency Wiring Root

## Status
Accepted (2026-03-01)

## Context
Application dependencies are currently referenced through module constants and implicit globals from route entrypoints. This makes startup contracts and dependency ownership harder to reason about.

## Decision
Introduce `Html2rss::Web::AppContext` as the single dependency wiring root used by `App`.

`AppContext` owns boot-time dependency references for:
- config (`LocalConfig`, `EnvironmentValidator`)
- auth (`Auth`)
- flags (`Flags`)
- logging/observability (`SecurityLogger`, `Observability`)
- API handlers (`Api::V1::*`)
- route assemblers (`Routes::*`)

Route composition must receive dependencies from `AppContext` rather than looking them up ad hoc in `App`.

## Consequences
- Positive: explicit boot graph, simpler dependency audits, easier future test seams.
- Negative: more keyword wiring in route entry modules.

## Rollback
Remove `AppContext`, restore direct module constant references from `App` route assembly.
