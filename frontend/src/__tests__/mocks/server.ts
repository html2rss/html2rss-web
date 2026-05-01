import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';

export const server = setupServer(
  http.get('/api/v1', () => {
    return HttpResponse.json({
      success: true,
      data: {
        api: {
          name: 'html2rss-web API',
          description: 'RESTful API for converting websites to RSS feeds',
          openapi_url: 'http://example.test/openapi.yaml',
        },
        instance: {
          feed_creation: {
            enabled: true,
            access_token_required: true,
          },
          featured_feeds: [],
        },
      },
    });
  })
);

export interface FeedResponseOverrides {
  id?: string;
  name?: string;
  url?: string;
  feed_token?: string;
  public_url?: string;
  json_public_url?: string;
  created_at?: string;
  updated_at?: string;
}

export interface StructuredErrorOverrides {
  code?: string;
  message?: string;
  kind?: 'auth' | 'input' | 'network' | 'server';
  retryable?: boolean;
  next_action?: 'enter_token' | 'correct_input' | 'retry' | 'wait' | 'none';
  retry_action?: 'alternate' | 'primary' | 'none';
}

export function buildFeedResponse(overrides: FeedResponseOverrides = {}) {
  const timestamp = overrides.created_at ?? new Date('2024-01-01T00:00:00Z').toISOString();
  return {
    success: true,
    data: {
      feed: {
        id: overrides.id ?? 'feed-123',
        name: overrides.name ?? 'Example Feed',
        url: overrides.url ?? 'https://example.com/articles',
        feed_token: overrides.feed_token ?? 'example-token',
        public_url: overrides.public_url ?? '/api/v1/feeds/example-token',
        json_public_url: overrides.json_public_url ?? '/api/v1/feeds/example-token.json',
        created_at: timestamp,
        updated_at: overrides.updated_at ?? timestamp,
      },
    },
    meta: { created: true },
  };
}

export function buildStructuredErrorResponse(overrides: StructuredErrorOverrides = {}) {
  return {
    success: false,
    error: {
      code: overrides.code ?? 'INTERNAL_SERVER_ERROR',
      message: overrides.message ?? 'Internal Server Error',
      kind: overrides.kind ?? 'server',
      retryable: overrides.retryable ?? false,
      next_action: overrides.next_action ?? 'none',
      retry_action: overrides.retry_action ?? 'none',
    },
  };
}
