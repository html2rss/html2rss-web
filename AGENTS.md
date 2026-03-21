# Agent Workflow Constraints

This document defines execution constraints for AI agents. For general contributor rules, setup commands, architectural constraints, and security policies, see [docs/README.md](docs/README.md).

## Collaboration Agreement (Agent ↔ User)

- **DoD:** `make ready` in Dev Container; if applicable, user completes manual smoke test with agent-provided steps.
- **Verification:** Always smoke Dev Container + `make ready`.
- **Commits:** Group by logical unit after smoke-tested (feature / improvement / refactor).
- **Responses:** Changes → Commands → Results → Next steps, ending with a concise one-line summary.
- **KISS vs Refactor:** KISS by default; boy-scout refactors allowed if low-risk and simplifying.
- **Ambiguity:** Proceed with safest assumption, then confirm.
- **Non-negotiables:** Dev Container only; security first.

## Agent-Specific Verification Rules

- Always run Dev Container smoke + `make ready` for changes.
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
