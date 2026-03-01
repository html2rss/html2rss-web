# ADR-0005: Async Feed Refresh with Cache-First Read Path

## Status
Accepted

## Context
Feed generation is synchronous in the request path, coupling latency to upstream source behavior.

## Decision
Introduce a cache-first feed runtime with optional asynchronous refresh behind a feature flag.

## Consequences
- Positive: improved resilience and latency under upstream instability.
- Negative: operational complexity (queue/worker lifecycle, visibility).

## Rollout
- Start with in-process queue + worker and bounded retries.
- Serve fresh cache when present, optionally stale-while-revalidate.
- Keep sync fallback path available by flag.

## Rollback
Disable async refresh flag and route all reads through synchronous generation.
