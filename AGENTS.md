# Agent Workflow (Dev Container)

All automated work must run inside the Dev Container. Do not run app/test commands directly on the host.

## Start the Dev Container

```
docker compose -f .devcontainer/docker-compose.yml up -d
```

## Commands (run inside the container)

```
docker compose -f .devcontainer/docker-compose.yml exec -T app make setup

docker compose -f .devcontainer/docker-compose.yml exec -T app make dev

docker compose -f .devcontainer/docker-compose.yml exec -T app make test

docker compose -f .devcontainer/docker-compose.yml exec -T app bundle exec rubocop -F

docker compose -f .devcontainer/docker-compose.yml exec -T app bundle exec rspec
```

If you need an interactive shell:

```
docker compose -f .devcontainer/docker-compose.yml exec app bash
```
