# Configuration Guide

## Environment Variables

### Auto Source Configuration

| Variable                      | Description                            | Default           | Example                                               |
| ----------------------------- | -------------------------------------- | ----------------- | ----------------------------------------------------- |
| `AUTO_SOURCE_ENABLED`         | Enable auto source feature             | `false`           | `true`                                                |
| `AUTO_SOURCE_USERNAME`        | Basic auth username                    | Required          | `admin`                                               |
| `AUTO_SOURCE_PASSWORD`        | Basic auth password                    | Required          | `changeme`                                            |
| `AUTO_SOURCE_ALLOWED_ORIGINS` | Allowed request origins                | Required          | `localhost:3000,example.com`                          |
| `AUTO_SOURCE_ALLOWED_URLS`    | **URL whitelist for public instances** | `""` (allows all) | `https://github.com/*,https://news.ycombinator.com/*` |

### Health Check Configuration

| Variable                | Description           | Default        | Example    |
| ----------------------- | --------------------- | -------------- | ---------- |
| `HEALTH_CHECK_USERNAME` | Health check username | Auto-generated | `health`   |
| `HEALTH_CHECK_PASSWORD` | Health check password | Auto-generated | `changeme` |

### Ruby Integration

| Variable    | Description                | Default | Example         |
| ----------- | -------------------------- | ------- | --------------- |
| `RUBY_PATH` | Path to Ruby executable    | `ruby`  | `/usr/bin/ruby` |
| `APP_ROOT`  | Application root directory | `.`     | `/app`          |

## URL Restriction Patterns

The `AUTO_SOURCE_ALLOWED_URLS` variable supports:

- **Exact URLs**: `https://example.com/news`
- **Wildcard patterns**: `https://example.com/*` (matches any path)
- **Domain patterns**: `https://*.example.com` (matches subdomains)
- **Multiple patterns**: Comma-separated list

### Examples

```bash
# Allow only specific sites
AUTO_SOURCE_ALLOWED_URLS=https://github.com/*,https://news.ycombinator.com/*,https://example.com/news

# Allow all subdomains of a domain
AUTO_SOURCE_ALLOWED_URLS=https://*.example.com/*

# Allow everything (for private instances)
AUTO_SOURCE_ALLOWED_URLS=

# Block everything (disable auto source)
AUTO_SOURCE_ENABLED=false
```

## Security Considerations

### Public Instances
- **Always set** `AUTO_SOURCE_ALLOWED_URLS` to restrict URLs
- Use strong authentication credentials
- Monitor usage and set up rate limiting
- Consider IP whitelisting for additional security

### Private Instances
- Leave `AUTO_SOURCE_ALLOWED_URLS` empty to allow all URLs
- Still use authentication to prevent unauthorized access
- Consider network-level restrictions

## Deployment Examples

### Public Demo Instance
```bash
AUTO_SOURCE_ENABLED=true
AUTO_SOURCE_USERNAME=demo
AUTO_SOURCE_PASSWORD=secure_password
AUTO_SOURCE_ALLOWED_URLS=https://github.com/*,https://news.ycombinator.com/*,https://example.com/*
```

### Private Instance
```bash
AUTO_SOURCE_ENABLED=true
AUTO_SOURCE_USERNAME=admin
AUTO_SOURCE_PASSWORD=very_secure_password
AUTO_SOURCE_ALLOWED_URLS=
```

### Disabled Auto Source
```bash
AUTO_SOURCE_ENABLED=false
```
