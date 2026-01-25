# Agent Workflow (Dev Container)

## Start the Dev Container

```text
docker compose -f .devcontainer/docker-compose.yml up -d
```

## Commands (run inside the container)

```text
docker compose -f .devcontainer/docker-compose.yml exec -T app make setup

docker compose -f .devcontainer/docker-compose.yml exec -T app make dev

docker compose -f .devcontainer/docker-compose.yml exec -T app make test

docker compose -f .devcontainer/docker-compose.yml exec -T app make ready

docker compose -f .devcontainer/docker-compose.yml exec -T app bundle exec rubocop -F

docker compose -f .devcontainer/docker-compose.yml exec -T app bundle exec rspec
```

Pre-commit gate (required):

```text
docker compose -f .devcontainer/docker-compose.yml exec -T app make ready
```

If you need an interactive shell:

```text
docker compose -f .devcontainer/docker-compose.yml exec app bash
```

---

## Collaboration Agreement (Agent ↔ User)

## Interview Answers (ID-able) + Expert Recommendations

**DoD:** `make ready` in Dev Container; if applicable, user completes manual smoke test with agent-provided steps.  
**Verification:** Always smoke Dev Container + `make ready`.  
**Commits:** Group by logical unit after smoke-tested (feature / improvement / refactor).  
**Responses:** Changes → Commands → Results → Next steps, ending with a concise one-line summary.  
**KISS vs Refactor:** KISS by default; boy-scout refactors allowed if low-risk and simplifying.  
**Ambiguity:** Proceed with safest assumption, then confirm.  
**Non-negotiables:** Dev Container only; security first.

Expert recommendation: keep workflows terminal-first and keyboard-focused (clear commands, no GUI-only steps).

## Definition of Done

- Run `make ready` inside the Dev Container.
- If applicable, user completes manual smoke test; agent provides clear instructions.

## Verification Rules

- Always run Dev Container smoke + `make ready` for changes.

## Commit Granularity

- Group commits by logical units after they have grown and been smoke-tested (feature / improvement / refactor).

## Response Format

- Default: Changes → Commands → Results → Next steps.
- End with a concise one-line summary.

## KISS vs Refactor

- KISS by default.
- Boy-scout refactors are allowed when they reduce complexity and are low-risk.

## Ambiguity Handling

- Proceed with the safest assumption, then confirm.

## Non-Negotiables

- Security first.
