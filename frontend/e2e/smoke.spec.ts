import { expect, test } from '@playwright/test';

test.describe('frontend smoke', () => {
  test('loads create flow and inline access-token gate', async ({ page }) => {
    await page.route(/\/api\/v1$/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          success: true,
          data: {
            api: {
              name: 'html2rss-web API',
              description: 'RESTful API for converting websites to RSS feeds',
              openapi_url: 'https://example.test/openapi.yaml',
            },
            instance: {
              feed_creation: {
                enabled: true,
                access_token_required: true,
              },
              featured_feeds: [],
            },
          },
        }),
      });
    });

    await page.goto('/');

    await expect(page.getByLabel('Page URL')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Generate feed URL' })).toBeVisible();

    await page.getByLabel('Page URL').fill('https://example.com/articles');
    await page.getByRole('button', { name: 'Generate feed URL' }).click();

    await expect(page.getByRole('heading', { name: 'Enter access token' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Access token' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Save and continue' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Back' })).toBeVisible();

    await page.getByRole('button', { name: 'Back' }).click();
    await expect(page).toHaveURL(/#\/create(?:\?.*)?$/);
    await expect(page.getByRole('button', { name: 'Generate feed URL' })).toBeVisible();
    await expect(page.locator('.form-shell')).toHaveAttribute('data-state', 'create');
    await expect(page.getByLabel('Utilities')).toBeVisible();
  });

  test('shows result after successful feed creation without snapshot recovery', async ({ page }) => {
    await page.route(/\/api\/v1$/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          success: true,
          data: {
            api: {
              name: 'html2rss-web API',
              description: 'RESTful API for converting websites to RSS feeds',
              openapi_url: 'https://example.test/openapi.yaml',
            },
            instance: {
              feed_creation: {
                enabled: true,
                access_token_required: true,
              },
              featured_feeds: [],
            },
          },
        }),
      });
    });

    await page.route(/\/api\/v1\/feeds$/, async (route) => {
      await route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify({
          success: true,
          data: {
            feed: {
              id: 'feed-123',
              name: 'Example Feed',
              url: 'https://example.com/articles',
              feed_token: 'generated-token',
              public_url: '/api/v1/feeds/generated-token',
              json_public_url: '/api/v1/feeds/generated-token.json',
              created_at: '2026-04-05T08:59:00.000Z',
              updated_at: '2026-04-05T09:00:00.000Z',
            },
          },
        }),
      });
    });

    await page.route(/\/api\/v1\/feeds\/generated-token\.json$/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/feed+json',
        body: JSON.stringify({
          items: [
            {
              title: 'Sample preview item',
              content_text: 'Current preview fetch includes rendered content.',
              date_published: '2026-04-05T09:00:00.000Z',
              url: 'https://example.com/articles/sample-preview-item',
            },
          ],
        }),
      });
    });

    await page.addInitScript(() => {
      sessionStorage.setItem('html2rss_access_token', 'token-123');
    });

    await page.goto('/');
    await page.getByLabel('Page URL').fill('https://example.com/articles');
    await page.getByRole('button', { name: 'Generate feed URL' }).click();

    await expect(page.getByText('Feed ready')).toBeVisible();
    await expect(page.locator('.result-shell')).toHaveAttribute('data-state', 'result');
    await expect(page.getByText('Example Feed')).toBeVisible();
    await expect(page.getByRole('link', { name: 'Open feed' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Open JSON Feed' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Open in feed reader' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Create another feed' })).toBeVisible();
    await expect(page.getByText('Sample preview item')).toBeVisible();
    await expect(page.getByText('Current preview fetch includes rendered content.')).toBeVisible();

    await page.goto('/#/result/missing-token');

    await expect(page.getByLabel('Page URL')).toBeVisible();
    await expect(page.getByText('Saved result unavailable')).toHaveCount(0);
    await expect(page.locator('.result-recovery')).toHaveCount(0);
  });
});
