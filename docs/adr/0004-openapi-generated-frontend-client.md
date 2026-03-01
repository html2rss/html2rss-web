# ADR-0004: OpenAPI-Generated Frontend Client

## Status
Accepted

## Context
OpenAPI spec is maintained, but frontend API typing is partially handwritten.

## Decision
Use `@hey-api/openapi-ts` to generate client/types from `docs/api/v1/openapi.yaml` and enforce drift checks.

## Consequences
- Positive: tighter backend/frontend contract fidelity.
- Negative: generated artifacts add maintenance in CI and local workflows.

## Rollout
- Add generator config and npm script.
- Generate client into frontend source tree.
- Add verify target to fail on stale generated output.

## Rollback
Temporarily use existing fetch hooks while keeping generator config in place.
