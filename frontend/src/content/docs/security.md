---
title: Security Guide
description: Security controls, monitoring, and incident response for html2rss-web
---

# Security Guide for html2rss-web

Keep the platform locked down through strict key management, scoped access, and disciplined monitoring. Use this guide as the runbook.

## Core Controls

### Feed Tokens

- HMAC-SHA256 signing prevents tampering.
- Tokens are bound to a single source URL and expire after ten years.
- Validation is stateless; no database entries exist to revoke a single token.

### Authentication

- All management endpoints require Bearer tokens.
- Accounts carry explicit `allowed_urls` scopes; reserve `'*'` for administrators.
- Input validation, XML sanitisation, and CSP headers guard the rendering surface.

## Deployment Checklist

### Before Launch

1. Generate a 64-character hexadecimal secret: `openssl rand -hex 32`.
2. Issue strong per-user tokens and store them outside the repository.
3. Configure `config/feeds.yml` with least-privileged `allowed_urls` entries.
4. Export `HTML2RSS_SECRET_KEY` and any user tokens via your secrets manager.

### After Launch

1. Monitor access logs for rejected tokens or URL violations.
2. Keep Ruby gems, Node dependencies, and Docker images patched.
3. Back up `config/feeds.yml` and store secrets somewhere encrypted.
4. Review account scopes quarterly and rotate secrets on schedule.

## Risks and Mitigations

| Risk                  | Impact                   | Mitigation                                                                        |
| --------------------- | ------------------------ | --------------------------------------------------------------------------------- |
| Feed URL leakage      | Exposes a single feed    | Token is URL-bound; rotate the secret key if compromise is widespread.            |
| Secret key compromise | Allows forged tokens     | Replace the key immediately, restart services, and notify users to rebuild feeds. |
| Over-broad scopes     | Grants unintended access | Use explicit domain lists; audit `allowed_urls` routinely.                        |

## Monitoring

Watch for repeated authentication failures, attempts to reach blocked domains, and unusual feed creation spikes. Set alerts for:

- > 10 failed auth requests per minute
- Requests matching denied URL patterns
- Invalid token signatures
- Elevated 5xx rates

## Incident Response

### Secret Key Compromised

1. Generate a new key and update `HTML2RSS_SECRET_KEY`.
2. Restart the application stack.
3. Invalidate cached images and queue communication to all users.
4. Provide instructions for regenerating feeds and monitor follow-up logs.

### User Token Compromised

1. Remove the entry from `config/feeds.yml`.
2. Generate and deploy a replacement token.
3. Restart if needed and notify the user that feeds must be recreated.

### Feed Token Misuse

1. Identify the token from access logs.
2. Rotate the master secret if abuse warrants global invalidation.
3. Communicate the outage and guide users through feed regeneration.

### Stateless Design Reminder

Feed tokens are intentionally stateless. Individual token revocation is impossible; secret rotation is the only invalidation path. Plan maintenance windows accordingly.

## Routine Tasks

| Cadence   | Task                                                                 |
| --------- | -------------------------------------------------------------------- |
| Monthly   | Review access logs, confirm scopes, check alert channels.            |
| Quarterly | Rotate the secret key, refresh dependency locks, test backups.       |
| Annually  | Run a security audit, revisit policies, consider a penetration test. |

## Quick Commands

```bash
# Generate secret or user tokens
openssl rand -hex 32

# Restart containers after rotating secrets
docker-compose restart
```

## References

- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [Ruby on Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [RFC 2104: HMAC](https://www.rfc-editor.org/rfc/rfc2104)
