# html2rss-web AI Agent Instructions

## Overview

- Ruby web app that converts websites into RSS 2.0 feeds.
- Built with **Roda**, using the **html2rss** gem (+ `html2rss-configs`).
- **Principle:** _All features must work without JavaScript._ JS is only progressive enhancement.

## Core Rules

- ✅ Use **Roda routing with `hash_branch`**. Keep routes small.
- ✅ Put logic into `helpers/` or `app/`, not inline in routes.
- ✅ Validate all inputs. Pass outbound requests through **SSRF filter**.
- ✅ Add caching headers where appropriate (`Rack::Cache`).
- ✅ Errors: friendly messages for users, detailed logging internally.
- ✅ CSS: Water.css + small overrides in `public/styles.css`.
- ✅ Specs: RSpec, unit + integration, use VCR for external requests.

## Don’t

- ❌ Don’t depend on JS for core flows.
- ❌ Don’t bypass SSRF filter or weaken CSP.
- ❌ Don’t add databases, ORMs, or background jobs.
- ❌ Don’t leak stack traces or secrets in responses.

## Project Structure

- `app.rb` – main Roda app
- `app/` – core modules (config, cache, ssrf, health)
- `routes/` – route handlers (`hash_branch`)
- `helpers/` – pure helper modules (`module_function`)
- `views/` – ERB templates
- `public/` – static assets (CSS/JS, minimal)
- `config/feeds.yml` – feed definitions
- `spec/` – RSpec tests + VCR cassettes

## Environment

- `RACK_ENV` – environment
- `AUTO_SOURCE_ENABLED`, `AUTO_SOURCE_USERNAME`, `AUTO_SOURCE_PASSWORD`, `AUTO_SOURCE_ALLOWED_ORIGINS`
- `HEALTH_CHECK_USERNAME`, `HEALTH_CHECK_PASSWORD`
- `SENTRY_DSN` (optional)

## Style

- Add `# frozen_string_literal: true`
- Follow RuboCop style
- YARD doc comments for public methods
