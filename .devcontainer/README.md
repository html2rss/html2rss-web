# Dev Container Workflow

This repository ships a single Dev Container for development. Open the project in VS Code (Dev
Containers extension) or GitHub Codespaces and use that environment for all work.

## What gets created

The devcontainer starts one service named `app` and exposes:

- **Port 4000:** Ruby app
- **Port 4001:** Astro dev server

The repo is mounted at `/workspace`. Bundler gems are cached in a Docker volume to speed up
future launches.

## Bootstrap

On first open, the Dev Container runs:

```
make setup
```

This installs Ruby and frontend dependencies inside the container.

If setup fails due to missing network access (e.g., GitHub DNS), rerun `make setup` once
network access is available.

## Common commands (run inside the container)

```
make dev          # Ruby + Astro
make dev-ruby     # Ruby only
make dev-frontend # Astro only
make test         # Ruby + frontend tests
make ready        # RuboCop + RSpec (pre-commit gate)
```

## Lint and tests

```
bundle exec rubocop -F
bundle exec rspec
```

## Notes

- All commands are expected to run inside the Dev Container.
- The default service command is `sleep infinity`; use the Make targets above to start servers.
