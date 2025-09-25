import { test, expect } from '@playwright/test';

test.describe('API smoke checks', () => {
  test('health endpoints respond OK', async ({ request }) => {
    const ready = await request.get('/api/v1/health/ready');
    expect(ready.ok()).toBeTruthy();

    const live = await request.get('/api/v1/health/live');
    expect(live.ok()).toBeTruthy();

    const root = await request.get('/api/v1/health');
    const payload = await root.json();
    expect(payload).toMatchObject({ success: true, data: expect.any(Object) });
  });

  test('requires authentication for feed creation', async ({ request }) => {
    const response = await request.post('/api/v1/feeds', {
      data: {
        url: 'https://example.com/articles',
        strategy: 'ssrf_filter',
      },
    });

    expect(response.status()).toBe(401);
    const payload = await response.json();
    expect(payload).toMatchObject({ success: false, error: { code: 'UNAUTHORIZED' } });
  });

  test('creates a feed when provided with valid credentials', async ({ request }) => {
    const response = await request.post('/api/v1/feeds', {
      headers: {
        Authorization: 'Bearer allow-any-urls-abcd-4321',
        'Content-Type': 'application/json',
      },
      data: {
        url: 'https://example.com/articles',
        strategy: 'ssrf_filter',
      },
    });

    expect(response.status()).toBe(200);
    const payload = await response.json();
    expect(payload).toMatchObject({
      success: true,
      data: {
        feed: {
          url: 'https://example.com/articles',
          public_url: expect.stringMatching(/^\/api\/v1\/feeds\//),
        },
      },
    });
  });
});
