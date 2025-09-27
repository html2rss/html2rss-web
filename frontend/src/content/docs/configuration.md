---
title: Configuration Guide
description: Critical environment variables and account management guidance for html2rss-web
---

# Configuration Guide

Only a handful of settings are required to run the service. Set them explicitly and check them into your deployment scripts.

## Core Environment Variables

| Variable              | Required | Default | Purpose                                                                                        |
| --------------------- | -------- | ------- | ---------------------------------------------------------------------------------------------- |
| `HTML2RSS_SECRET_KEY` | ✅       | —       | HMAC key for feed token signing. Generate with `openssl rand -hex 32`.                         |
| `AUTO_SOURCE_ENABLED` | Optional | `false` | Enables automatic feed discovery for authorised accounts.                                      |
| `APP_ROOT`            | Optional | `.`     | Filesystem root used by the Ruby process. Override only if the app runs outside the repo root. |
| `RUBY_PATH`           | Optional | `ruby`  | Ruby executable path. Configure when Ruby is not on `PATH`.                                    |

## Health Check

Expose the health-check account token as `HEALTH_CHECK_TOKEN` and forward it as a Bearer token to `/health_check.txt` or `/api/v1/health`.

| Variable             | Required | Default                     | Purpose                                                         |
| -------------------- | -------- | --------------------------- | --------------------------------------------------------------- |
| `HEALTH_CHECK_TOKEN` | ✅       | `health-check-token-xyz789` | Token forwarded to the container health probe. Keep it private. |

## Account Policy

Accounts live in `config/feeds.yml`. Give each token a scoped `allowed_urls` list.

- Public deployments: restrict each account to the domains it needs. Avoid patterns such as `https://*`.
- Private deployments: `allowed_urls: ['*']` is acceptable, but still rotate tokens and guard network access.
- Tokens are stored in browser session storage. Treat them as sensitive and rotate when exposed.

## Deployment Presets

Use these examples as starting points for your environment files:

```bash
# Public demo
AUTO_SOURCE_ENABLED=true

# Private instance with auto source
AUTO_SOURCE_ENABLED=true

# Disable auto source entirely
AUTO_SOURCE_ENABLED=false
```

Automate verification of these variables in CI or infrastructure-as-code to avoid silent misconfiguration.
