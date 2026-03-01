# ADR-0001: Boundary Contracts Use Ruby Data Models

## Status
Accepted

## Context
Boundary methods currently exchange loosely shaped hashes, increasing ambiguity and making refactors risky.

## Decision
Introduce immutable `Data` models at high-churn boundaries (auth/account identity, feed create params, feed metadata, request context).

## Consequences
- Positive: clearer contracts, safer refactors, reduced defensive nil/hash checks.
- Negative: requires adapter code while legacy hash consumers are migrated.

## Rollout
- Add `Data` models + hash adapters.
- Migrate edge modules first.
- Keep hash compatibility methods during transition.

## Rollback
Route boundary code back through hash adapters while retaining models for future retries.
