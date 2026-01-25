import { setupServer } from 'msw/node';
import { rest } from 'msw';

export const server = setupServer(
  rest.get('/api/v1/strategies', (req, res, ctx) => {
    return res(
      ctx.json({
        success: true,
        data: {
          strategies: [
            {
              id: 'ssrf_filter',
              name: 'ssrf_filter',
              display_name: 'SSRF Filter',
            },
            {
              id: 'browserless',
              name: 'browserless',
              display_name: 'Browserless',
            },
          ],
        },
        meta: { total: 2 },
      })
    );
  })
);

export interface FeedResponseOverrides {
  id?: string;
  name?: string;
  url?: string;
  strategy?: string;
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
        public_url: overrides.public_url ?? '/api/v1/feeds/example-token',
        created_at: timestamp,
        updated_at: overrides.updated_at ?? timestamp,
      },
    },
    meta: { created: true },
  };
}
