# html2rss-web RESTful API v1

This document describes the RESTful API v1 for html2rss-web, which provides a modern, standards-compliant interface for converting websites to RSS feeds.

## Overview

The API follows REST principles with:
- **Resource-based URLs**: `/api/v1/feeds`, `/api/v1/strategies`
- **HTTP methods**: GET, POST, PUT, DELETE
- **Proper status codes**: 200, 201, 400, 401, 403, 404, 500
- **JSON responses**: Consistent response format
- **Content negotiation**: XML for RSS feeds, JSON for metadata

## Base URL

```
https://your-domain.com/api/v1
```

## Authentication

Most endpoints require Bearer token authentication:

```bash
curl -H "Authorization: Bearer your-token" https://your-domain.com/api/v1/feeds
```

## Response Format

All JSON responses follow this structure:

```json
{
  "success": true,
  "data": {
    // Response data
  },
  "meta": {
    "timestamp": "2024-01-01T12:00:00Z",
    "version": "1.0.0"
  }
}
```

Error responses:

```json
{
  "success": false,
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE",
    "status": 400
  },
  "data": {},
  "meta": {
    "timestamp": "2024-01-01T12:00:00Z",
    "version": "1.0.0"
  }
}
```

## Endpoints

### Feeds

#### List Feeds
```http
GET /api/v1/feeds
```

Returns all available feeds.

**Response:**
```json
{
  "success": true,
  "data": {
    "feeds": [
      {
        "id": "example",
        "name": "Example Feed",
        "description": "RSS feed for example",
        "url": "/api/v1/feeds/example",
        "created_at": null,
        "updated_at": null
      }
    ]
  },
  "meta": {
    "total": 1,
    "timestamp": "2024-01-01T12:00:00Z",
    "version": "1.0.0"
  }
}
```

#### Create Feed
```http
POST /api/v1/feeds
Authorization: Bearer your-token
Content-Type: application/json

{
  "url": "https://example.com",
  "name": "Example Feed",
  "strategy": "ssrf_filter"
}
```

Creates a new RSS feed from a website URL.

**Response (201):**
```json
{
  "success": true,
  "data": {
    "feed": {
      "id": "abc123def456",
      "name": "Example Feed",
      "url": "https://example.com",
      "strategy": "ssrf_filter",
      "public_url": "/feeds/abc123def456?token=...&url=https%3A%2F%2Fexample.com",
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-01T12:00:00Z"
    }
  },
  "meta": {
    "created": true,
    "timestamp": "2024-01-01T12:00:00Z",
    "version": "1.0.0"
  }
}
```

#### Get Feed
```http
GET /api/v1/feeds/{id}
Accept: application/json
```

Returns feed metadata (JSON) or RSS content (XML) based on Accept header.

**JSON Response:**
```json
{
  "success": true,
  "data": {
    "feed": {
      "id": "example",
      "name": "example",
      "description": "RSS feed for example",
      "url": "/api/v1/feeds/example",
      "strategy": "ssrf_filter",
      "created_at": null,
      "updated_at": null
    }
  },
  "meta": {
    "timestamp": "2024-01-01T12:00:00Z",
    "version": "1.0.0"
  }
}
```

**XML Response (Accept: application/xml):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <!-- RSS feed content -->
</rss>
```

#### Update Feed
```http
PUT /api/v1/feeds/{id}
Authorization: Bearer your-token
Content-Type: application/json

{
  "strategy": "mechanize"
}
```

Updates feed settings (currently only strategy).

#### Delete Feed
```http
DELETE /api/v1/feeds/{id}
Authorization: Bearer your-token
```

Deletes a feed (currently a no-op for stateless feeds).

### Strategies

#### List Strategies
```http
GET /api/v1/strategies
```

Returns all available extraction strategies.

**Response:**
```json
{
  "success": true,
  "data": {
    "strategies": [
      {
        "id": "ssrf_filter",
        "name": "ssrf_filter",
        "display_name": "Ssrf Filter",
        "description": "Secure strategy with SSRF protection and content filtering",
        "available": true
      }
    ]
  },
  "meta": {
    "total": 1,
    "timestamp": "2024-01-01T12:00:00Z",
    "version": "1.0.0"
  }
}
```

#### Get Strategy
```http
GET /api/v1/strategies/{id}
```

Returns details about a specific strategy.

### Health

#### Health Check
```http
GET /api/v1/health
Authorization: Bearer health-check-token
```

Returns application health status.

**Response (200):**
```json
{
  "success": true,
  "data": {
    "health": {
      "status": "healthy",
      "timestamp": "2024-01-01T12:00:00Z",
      "version": "1.0.0",
      "environment": "production",
      "checks": {}
    }
  },
  "meta": {
    "timestamp": "2024-01-01T12:00:00Z",
    "version": "1.0.0"
  }
}
```

#### Readiness Check
```http
GET /api/v1/health/ready
```

Returns application readiness status (no auth required).

#### Liveness Check
```http
GET /api/v1/health/live
```

Returns application liveness status (no auth required).

## Error Codes

| Code | Status | Description |
|------|--------|-------------|
| `UNAUTHORIZED` | 401 | Authentication required |
| `FORBIDDEN` | 403 | Access denied |
| `NOT_FOUND` | 404 | Resource not found |
| `BAD_REQUEST` | 400 | Invalid request |
| `INTERNAL_ERROR` | 500 | Server error |
| `SERVICE_UNAVAILABLE` | 503 | Service unavailable |

## Rate Limiting

The API implements rate limiting to prevent abuse. See the main application documentation for details.

## Backward Compatibility

The legacy API endpoints remain available for backward compatibility:

- `/api/feeds.json` - Legacy feeds list
- `/api/strategies.json` - Legacy strategies list
- `/api/{feed_name}` - Legacy feed generation
- `/auto_source/*` - Legacy auto source endpoints

## OpenAPI Documentation

Full OpenAPI 3.0 specification is available at:
```
GET /api/v1/docs
```

This returns the complete API specification in YAML format, which can be used with tools like Swagger UI for interactive documentation.

## Examples

### Create and Access a Feed

```bash
# Create a feed
curl -X POST "https://your-domain.com/api/v1/feeds" \
  -H "Authorization: Bearer your-token" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "name": "Example News",
    "strategy": "ssrf_filter"
  }'

# Response includes public_url for sharing
{
  "success": true,
  "data": {
    "feed": {
      "id": "abc123def456",
      "name": "Example News",
      "url": "https://example.com",
      "strategy": "ssrf_filter",
      "public_url": "/feeds/abc123def456?token=...&url=https%3A%2F%2Fexample.com",
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-01T12:00:00Z"
    }
  }
}

# Access the feed publicly (no auth required)
curl "https://your-domain.com/feeds/abc123def456?token=...&url=https%3A%2F%2Fexample.com"
```

### List Available Strategies

```bash
curl "https://your-domain.com/api/v1/strategies"
```

### Check Application Health

```bash
curl -H "Authorization: Bearer health-check-token" \
  "https://your-domain.com/api/v1/health"
```
