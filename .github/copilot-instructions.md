# html2rss-web AI Agent Instructions

This repository uses a centralized documentation structure. All AI agents (including Copilot, Gemini CLI, etc.) must follow the constraints and rules defined in the following files:

## Canonical Documentation

- **Agent Constraints**: [AGENTS.md](../AGENTS.md) (Execution rules, verification, and UI principles)
- **Contributor Guide**: [docs/README.md](../docs/README.md) (Architecture, security, setup, and coding style)
- **Design System**: [docs/design-system.md](../docs/design-system.md) (Visual and CSS rules)

## Quick Reference for Agents

- **Environment**: All commands MUST run inside the Dev Container.
- **Verification**: Run `make ready` before any commit.
- **Security**: Follow strict [Security & Safety Rules](../docs/README.md#security--safety-rules).
- **Style**: Follow [Architectural Constraints](../docs/README.md#architectural-constraints) (YARD docs, Roda organization).
