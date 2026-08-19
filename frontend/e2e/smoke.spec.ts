import { expect, test } from '@playwright/test';
import { COPY } from '../src/journey/copy';

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
              catalog: { enabled: true, url: '/api/v1/configs' },
            },
          },
        }),
      });
    });

    await page.goto('/');

    await expect(page.getByLabel(COPY.urlLabel)).toBeVisible();
    await expect(page.getByRole('button', { name: COPY.createFeed })).toBeVisible();

    await page.getByLabel(COPY.urlLabel).fill('https://example.com/articles');
    await page.getByRole('button', { name: COPY.createFeed }).click();

    await expect(page.getByRole('heading', { name: COPY.tokenTitle })).toBeVisible();
    await expect(page.getByRole('textbox', { name: COPY.tokenTitle })).toBeVisible();
    await expect(page.getByRole('button', { name: COPY.saveAndContinue })).toBeVisible();
    await expect(page.getByRole('button', { name: COPY.back })).toBeVisible();
    await expect(page.locator('dialog')).toHaveAttribute('open');
    await expect(page.getByLabel(COPY.urlLabel)).toHaveCount(1);
    await expect(page.getByText(COPY.createFailedTitle)).toHaveCount(0);

    await page.getByRole('button', { name: COPY.back }).click();
    await expect(page).toHaveURL(/#\/create(?:\?.*)?$/);
    await expect(page.getByRole('button', { name: COPY.createFeed })).toBeVisible();
    await expect(page.locator('.form-shell')).toHaveAttribute('data-state', 'create');
    await expect(page.getByLabel(COPY.utilities)).toBeVisible();
  });

  test('remounts create from BrandLockup and hashbang and clears creation chrome', async ({ page }) => {
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
                access_token_required: false,
              },
              catalog: { enabled: true, url: '/api/v1/configs' },
            },
          },
        }),
      });
    });
    await page.route(/\/api\/v1\/feeds$/, async (route) => {
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({
          success: false,
          error: {
            kind: 'server',
            code: 'INTERNAL_SERVER_ERROR',
            retryable: true,
            next_action: 'retry',
            retry_action: 'primary',
            message: 'Access denied',
          },
        }),
      });
    });

    await page.goto('/#/create');

    await page.getByLabel(COPY.urlLabel).fill('https://example.com/articles');
    await page.getByRole('button', { name: COPY.createFeed }).click();
    await expect(page.getByText(COPY.createFailedTitle)).toBeVisible();

    await page.getByRole('link', { name: 'html2rss' }).click();
    await expect(page.getByText(COPY.createFailedTitle)).toHaveCount(0);
    await expect(page.locator('.form-shell')).toHaveAttribute('data-state', 'create');
    await expect(page.getByLabel(COPY.urlLabel)).toBeFocused();

    await page.getByRole('button', { name: COPY.createFeed }).click();
    await expect(page.getByText(COPY.createFailedTitle)).toBeVisible();

    await page.evaluate(() => {
      location.hash = '#!/create';
    });
    await expect(page).toHaveURL(/\/#\/create$/);
    await expect(page.getByText(COPY.createFailedTitle)).toHaveCount(0);
    await expect(page.locator('.form-shell')).toHaveAttribute('data-state', 'create');
    await expect(page.getByLabel(COPY.urlLabel)).toBeFocused();
  });

  test('shows result after successful feed creation and recovers unmatched result routes onto create', async ({
    page,
  }) => {
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
              catalog: { enabled: true, url: '/api/v1/configs' },
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
      localStorage.setItem('html2rss_access_token', 'token-123');
    });

    await page.goto('/');
    await page.getByLabel(COPY.urlLabel).fill('https://example.com/articles');
    await page.getByRole('button', { name: COPY.createFeed }).click();

    await expect(page.getByText(COPY.feedReady)).toBeVisible();
    await expect(page.locator('.result-shell')).toHaveAttribute('data-state', 'result');
    await expect(page.getByText('Example Feed')).toBeVisible();
    await expect(page.getByRole('button', { name: COPY.copyFeedUrl })).toBeVisible();
    await expect(page.getByRole('link', { name: COPY.openFeed })).toBeVisible();
    await expect(page.getByRole('link', { name: COPY.openJsonFeed })).toBeVisible();
    await expect(page.getByRole('link', { name: COPY.openInFeedReader })).toBeVisible();
    await expect(page.getByRole('button', { name: COPY.createAnother })).toBeVisible();
    await expect(page.getByText('Sample preview item')).toBeVisible();
    await expect(page.getByText('Current preview fetch includes rendered content.')).toBeVisible();

    await page.goto('/#/result/missing-token');

    await expect(page).toHaveURL(/\/#\/create$/);
    await expect(page.getByLabel(COPY.urlLabel)).toBeVisible();
    await expect(page.getByText('Saved result unavailable')).toHaveCount(0);
    await expect(page.locator('.result-recovery')).toHaveCount(0);
  });
});
