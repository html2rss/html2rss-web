# Configuration Guide

## Environment Variables

### Auto Source Configuration

| Variable              | Description                | Default | Example |
| --------------------- | -------------------------- | ------- | ------- |
| `AUTO_SOURCE_ENABLED` | Enable auto source feature | `false` | `true`  |

### Health Check Configuration

Health check authentication relies on the `health-check` account defined in `config/feeds.yml`. Expose the token via an environment variable and send it as a Bearer token when calling `/health_check.txt` or `/api/v1/health`.

| Variable             | Description                                  | Default                     | Example                     |
| -------------------- | -------------------------------------------- | --------------------------- | --------------------------- |
| `HEALTH_CHECK_TOKEN` | Token forwarded to the container health check | `health-check-token-xyz789` | `health-check-token-xyz789` |

### Ruby Integration

| Variable    | Description                | Default | Example         |
| ----------- | -------------------------- | ------- | --------------- |
| `RUBY_PATH` | Path to Ruby executable    | `ruby`  | `/usr/bin/ruby` |
| `APP_ROOT`  | Application root directory | `.`     | `/app`          |

## Security Considerations

### Public Instances
- Define per-account `allowed_urls` in `config/feeds.yml`
- Use strong authentication credentials
- Monitor usage and set up rate limiting
- Consider IP whitelisting for additional security

### Private Instances
- Use `allowed_urls: ['*']` to allow all URLs for trusted accounts
- Still use authentication to prevent unauthorized access
- Consider network-level restrictions

## Deployment Examples

### Public Demo Instance
```bash
AUTO_SOURCE_ENABLED=true
```

### Private Instance
```bash
AUTO_SOURCE_ENABLED=true
```

### Disabled Auto Source
```bash
AUTO_SOURCE_ENABLED=false
```

## Managing Accounts

Authentication for auto source is configured in `config/feeds.yml`. Define accounts with unique tokens and optional
`allowed_urls` patterns to control which sites each token may access. Tokens are stored client-side in session storage,
so treat them like sensitive credentials and rotate when necessary.
