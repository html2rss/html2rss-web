import { expect, test } from '@playwright/test';

test.describe('frontend smoke', () => {
  test('loads demo onboarding and auth toggle', async ({ page }) => {
    await page.goto('/');

    await expect(page.getByRole('heading', { name: 'Convert website to RSS' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Run demo' })).toBeVisible();

    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page.getByRole('button', { name: 'Back to demo' })).toBeVisible();
    await expect(page.getByLabel('Username')).toBeVisible();
    await expect(page.getByLabel('Token')).toBeVisible();

    await page.getByRole('button', { name: 'Back to demo' }).click();
    await expect(page.getByRole('button', { name: 'Run demo' })).toBeVisible();
  });
});
