# ADR-0003: Typed Validated Config Snapshot

## Status
Accepted

## Context
Config loading is centralized but callers consume dynamic hashes with uneven validation.

## Decision
Materialize an immutable typed config snapshot from `config/feeds.yml` with explicit validation and defaults.

## Consequences
- Positive: deterministic runtime behavior, clearer boot-time failures.
- Negative: schema maintenance overhead.

## Rollout
- Build snapshot models and validators.
- Keep hash compatibility for existing callers.
- Migrate consumers to typed readers incrementally.

## Rollback
Use legacy hash accessors while retaining snapshot parsing behind compatibility methods.
