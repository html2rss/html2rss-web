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

    await page.route(/\/api\/v1\/strategies$/, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          success: true,
          data: {
            strategies: [
              { id: 'faraday', name: 'Faraday' },
              { id: 'browserless', name: 'Browserless' },
            ],
          },
        }),
      });
    });

    await page.goto('/');

    await expect(page.getByLabel('PAGE URL')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Generate feed URL' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'MORE' })).toBeVisible();

    await page.getByLabel('PAGE URL').fill('https://example.com/articles');
    await page.getByRole('button', { name: 'Generate feed URL' }).click();

    await expect(page.getByRole('heading', { name: 'Add access token' })).toBeVisible();
    await expect(page.getByRole('textbox', { name: 'Access token' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Save and continue' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Back' })).toBeVisible();

    await page.getByRole('button', { name: 'Back' }).click();
    await expect(page.getByRole('button', { name: 'Generate feed URL' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'MORE' })).toBeVisible();
  });
});
