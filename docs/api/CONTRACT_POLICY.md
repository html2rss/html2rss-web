# API Contract Policy (Code-First)

## Source of Truth
- Implementation + request specs are the source of truth.
- `docs/api/v1/openapi.yaml` is generated output and must reflect code behavior.

## Required Gates
- `make openapi-verify` must fail on OpenAPI drift.
- `make openapi-lint` must fail on OpenAPI quality violations.
- Frontend generated client drift must fail CI via `npm run openapi:verify` in `frontend/`.

## Frontend Client Policy
- Generated client/types under `frontend/src/api/generated` are machine-generated only.
- Manual edits in generated files are not allowed.
- Frontend API calls should use generated SDK primitives.

## CI Contract
- CI must run:
  - backend spec drift verification
  - OpenAPI linting
  - frontend generated-client drift verification

## Change Process
1. Modify backend behavior/spec-driving tests.
2. Regenerate OpenAPI.
3. Regenerate frontend client.
4. Verify zero drift and passing lint.
