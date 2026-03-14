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
          openapi_url: 'http://example.test/api/v1/openapi.yaml',
        },
        demo: {
          enabled: true,
          token: 'CHANGE_ME_DEMO_TOKEN',
          strategy: 'ssrf_filter',
          sources: [
            { id: 'chip-de-testberichte', url: 'https://www.chip.de/testberichte' },
            { id: 'news-ycombinator-com', url: 'https://news.ycombinator.com' },
            { id: 'github-com-trending', url: 'https://github.com/trending' },
          ],
        },
      },
    });
  }),
  http.get('/api/v1/strategies', () => {
    return HttpResponse.json({
      success: true,
      data: {
        strategies: [
          {
            id: 'ssrf_filter',
            name: 'ssrf_filter',
            display_name: 'Standard (recommended)',
          },
          {
            id: 'browserless',
            name: 'browserless',
            display_name: 'JavaScript pages',
          },
        ],
      },
      meta: { total: 2 },
    });
  })
);

export interface FeedResponseOverrides {
  id?: string;
  name?: string;
  url?: string;
  strategy?: string;
  feed_token?: string;
  public_url?: string;
  created_at?: string;
  updated_at?: string;
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
        strategy: overrides.strategy ?? 'ssrf_filter',
        feed_token: overrides.feed_token ?? 'example-token',
        public_url: overrides.public_url ?? '/api/v1/feeds/example-token',
        created_at: timestamp,
        updated_at: overrides.updated_at ?? timestamp,
      },
    },
    meta: { created: true },
  };
}
