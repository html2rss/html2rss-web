# ADR-0002: Request Context and Correlated Observability

## Status
Accepted

## Context
Structured security logs exist, but cross-event request correlation is inconsistent.

## Decision
Add request context middleware to create a per-request context and expose it to logging/error paths.

Minimum keys:
- `request_id`
- `path`
- `method`
- `route_group`
- `actor`
- `strategy`
- `started_at`

## Consequences
- Positive: faster production debugging and safer incident triage.
- Negative: small overhead in request lifecycle and context propagation.

## Rollout
- Initialize context in middleware.
- Enrich security/error logs with context keys.
- Keep response payloads stable.

## Rollback
Disable middleware usage and fall back to existing logging behavior.
