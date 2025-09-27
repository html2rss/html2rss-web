---
title: Testing Overview
description: Required test suites for html2rss-web
---

# Testing Overview

The project keeps a lean set of tests that cover the core request paths. Run them before shipping changes.

## Backend (RSpec)

- Location: `spec/html2rss/web`
- Covers boot, feed creation, feed retrieval, token validation, and authenticated health checks.
- Command: `bundle exec rspec`

## Frontend (Vitest)

- Location: `frontend/src/__tests__`
- Unit suite: `npm run test:run`
- Contract suite with MSW: `npm run test:contract`

## Docker Smoke (RSpec)

- Location: `spec/smoke`
- Requires the Docker task via `bundle exec rake`
- Command: `RUN_DOCKER_SPECS=true bundle exec rspec --tag docker`

## Recommended Flow

1. `bundle exec rspec`
2. `cd frontend && npm run test:run`
3. Optional: `bundle exec rake` followed by the Docker-tagged specs

Add new tests only when a change affects behaviour covered by these paths or demonstrates a bug fix.
