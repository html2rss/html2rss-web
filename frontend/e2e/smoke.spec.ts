import { type Request } from '@playwright/test';
import { COPY } from '../src/journey/copy';
import {
  buildStructuredErrorResponse,
  createdFeedBody,
  jsonPreviewItems,
  suggestSuccessBody,
} from '../src/__tests__/mocks/apiFixtures';
import {
  API_CONFIGS,
  API_FEEDS,
  API_JSON_PREVIEW,
  API_SUGGEST,
  EXAMPLE_URL,
  expect,
  isSameOriginApi,
  test,
} from './fixtures';

const EMPTY_NOTICE = 'We could not extract feed items from this page yet.';
const READY_URL = 'https://example.com/ready-articles';
const ACCESS_TOKEN = 'token-123';
const FEED_TOKEN = 'generated-token';

const VIEWPORTS = [
  { name: 'desktop', width: 1280, height: 720 },
  { name: 'mobile', width: 390, height: 844 },
] as const;

async function assertNoRefineChrome(page: import('@playwright/test').Page) {
  await expect(page.locator('details')).toHaveCount(0);
  await expect(page.locator('[class*="refine-"]')).toHaveCount(0);
}

test.describe('frontend smoke', () => {
  test('covers one member journey from token gate through ready studio', async ({
    page,
    stubSpaApi,
    stubStudioEndpoints,
    fulfillJson,
  }) => {
    await stubSpaApi({ isCatalogEnabled: false });
    await stubStudioEndpoints();
    await page.route(API_FEEDS, async (route) => {
      if (route.request().method() !== 'POST') {
        await route.fallback();
        return;
      }
      const body = route.request().postDataJSON() as { url?: string };
      if (body.url === READY_URL) {
        await route.fulfill({
          status: 201,
          contentType: 'application/json',
          body: JSON.stringify(createdFeedBody({ url: READY_URL, feed_token: FEED_TOKEN })),
        });
        return;
      }
      await route.fulfill({
        status: 422,
        contentType: 'application/json',
        body: JSON.stringify(
          buildStructuredErrorResponse({
            code: 'EXTRACTION_EMPTY',
            message: EMPTY_NOTICE,
            kind: 'input',
            retryable: false,
            next_action: 'correct_input',
            retry_action: 'none',
          })
        ),
      });
    });
    await fulfillJson(API_JSON_PREVIEW, jsonPreviewItems, 200, 'application/feed+json');

    await page.goto('/');
    await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);
    await page.getByRole('button', { name: COPY.createFeed }).click();

    await expect(page.getByRole('heading', { name: COPY.tokenTitle })).toBeVisible();
    await page.locator('#access-token').fill(ACCESS_TOKEN);
    await page.getByRole('button', { name: COPY.saveAndContinue }).click();

    await expect(page).toHaveURL(/\/#\/result$/);
    await expect(page.locator('.result-shell')).toHaveAttribute('data-state', 'unresolved');
    await expect(page.getByText(EMPTY_NOTICE)).toBeVisible();
    await expect(page.getByRole('button', { name: COPY.saveAndGenerate })).toBeVisible();
    await expect(page.getByText(COPY.feedReady)).toHaveCount(0);
    await expect(page.getByRole('button', { name: COPY.copyFeedUrl })).toHaveCount(0);
    await expect(page.getByRole('link', { name: COPY.proposeDirectory })).toHaveCount(0);

    await page.getByRole('button', { name: COPY.createAnother }).click();
    await expect(page).toHaveURL(/\/#\/create/);
    const urlField = page.getByLabel(COPY.urlLabel);
    await urlField.fill(READY_URL);
    await page.getByRole('button', { name: COPY.createFeed }).click();

    await expect(page.getByText(COPY.feedReady)).toBeVisible();
    await expect(page.locator('.result-shell')).toHaveAttribute('data-state', 'ready');
    await expect(page.getByRole('button', { name: COPY.copyFeedUrl })).toBeFocused();
    await expect(page.getByLabel(COPY.itemsSelector, { exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: COPY.saveAndGenerate })).toHaveClass(/btn--ghost/);
    await expect(
      page.getByRole('button', { name: COPY.addSelector('Sample headline') }).first()
    ).toBeVisible();
    await assertNoRefineChrome(page);
    const proposal = page.getByRole('link', { name: COPY.proposeDirectory });
    await expect(proposal).toBeVisible();
    const href = (await proposal.getAttribute('href')) ?? '';
    expect(href).toContain('https://github.com/html2rss/html2rss-configs/issues/new');
    const body = new URL(href).searchParams.get('body') ?? '';
    expect(body).toContain(READY_URL);
    expect(body).not.toContain(ACCESS_TOKEN);
    expect(body).not.toContain(FEED_TOKEN);
  });

  test('loads create flow and inline access-token gate', async ({ page, stubSpaApi }) => {
    const catalogUrls: string[] = [];
    page.on('request', (request) => {
      if (API_CONFIGS.test(new URL(request.url()).pathname)) catalogUrls.push(request.url());
    });
    await stubSpaApi();

    await page.goto('/');

    await expect(page.getByLabel(COPY.urlLabel)).toBeVisible();
    await expect(page.getByRole('button', { name: COPY.createFeed })).toBeVisible();
    await expect.poll(() => catalogUrls.length, { timeout: 5000 }).toBeGreaterThan(0);
    expect(catalogUrls.every((url) => isSameOriginApi(url, API_CONFIGS))).toBe(true);

    await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);
    await page.getByRole('button', { name: COPY.createFeed }).click();

    await expect(page.getByRole('heading', { name: COPY.tokenTitle })).toBeVisible();
    await expect(page.locator('dialog')).toHaveAttribute('open');
    await expect(page.locator('#access-token')).toBeFocused();
    await expect(page.getByLabel(COPY.urlLabel)).toHaveCount(1);
    expect(
      await page.getByLabel(COPY.urlLabel).evaluate((element) => element.closest('[inert]') !== null)
    ).toBe(true);

    await page.getByRole('button', { name: COPY.back }).click();
    await expect(page).toHaveURL(/#\/create(?:\?.*)?$/);
    await expect(page.getByRole('button', { name: COPY.createFeed })).toBeVisible();
  });

  test('remounts create from BrandLockup and hashbang and clears creation chrome', async ({
    page,
    stubSpaApi,
    fulfillJson,
  }) => {
    await stubSpaApi({ isTokenRequired: false });
    await fulfillJson(
      API_FEEDS,
      {
        success: false,
        error: {
          kind: 'server',
          code: 'INTERNAL_SERVER_ERROR',
          retryable: true,
          next_action: 'retry',
          retry_action: 'primary',
          message: 'Access denied',
        },
      },
      500
    );

    await page.goto('/#/create');

    await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);
    await page.getByRole('button', { name: COPY.createFeed }).click();
    await expect(page.getByText(COPY.createFailedRetryTitle, { exact: true })).toBeVisible();

    await page.getByRole('link', { name: 'html2rss' }).click();
    await expect(page.getByText(COPY.createFailedRetryTitle, { exact: true })).toHaveCount(0);
    await expect(page.getByLabel(COPY.urlLabel)).toBeFocused();

    await page.getByRole('button', { name: COPY.createFeed }).click();
    await expect(page.getByText(COPY.createFailedRetryTitle, { exact: true })).toBeVisible();

    await page.evaluate(() => {
      location.hash = '#!/create';
    });
    await expect(page).toHaveURL(/\/#\/create$/);
    await expect(page.getByText(COPY.createFailedRetryTitle, { exact: true })).toHaveCount(0);
    await expect(page.getByLabel(COPY.urlLabel)).toBeFocused();
  });

  test('recovers empty result and retired refine hashes onto create', async ({ page, stubSpaApi }) => {
    await stubSpaApi({ isCatalogEnabled: false });

    await page.goto('/#/result/missing-token');
    await expect(page).toHaveURL(/\/#\/create$/);
    await expect(page.getByLabel(COPY.urlLabel)).toBeVisible();
    await expect(page.getByText('Saved result unavailable')).toHaveCount(0);

    await page.goto('/#/refine');
    await expect(page).toHaveURL(/\/#\/create$/);
    await expect(page.getByLabel(COPY.urlLabel)).toBeVisible();
  });

  test('realigns a stale ready result hash without leaving the workspace', async ({
    page,
    stubSpaApi,
    stubStudioEndpoints,
    fulfillJson,
  }) => {
    await stubSpaApi();
    await stubStudioEndpoints();
    await fulfillJson(API_FEEDS, createdFeedBody(), 201);
    await fulfillJson(API_JSON_PREVIEW, jsonPreviewItems, 200, 'application/feed+json');

    await page.addInitScript(() => {
      localStorage.setItem('html2rss_access_token', 'token-123');
    });

    await page.goto('/');
    await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);

    const created = page.waitForRequest((request: Request) => {
      if (request.method() !== 'POST' || !isSameOriginApi(request.url(), API_FEEDS)) return false;
      return request.headers().authorization === 'Bearer token-123';
    });
    await page.getByRole('button', { name: COPY.createFeed }).click();
    await created;

    await expect(page.getByText(COPY.feedReady)).toBeVisible();
    await expect(page.locator('.result-shell')).toHaveAttribute('data-state', 'ready');
    await expect(page.getByRole('button', { name: COPY.copyFeedUrl })).toBeFocused();
    await expect(page.locator('.ui-item-list')).toHaveCount(1);

    await page.goto('/#/result/missing-token');
    await expect(page).toHaveURL(/\/#\/result\/generated-token$/);
    await expect(page.getByText(COPY.feedReady)).toBeVisible();
  });

  for (const viewport of VIEWPORTS) {
    test.describe(`compact result matrix @ ${viewport.name}`, () => {
      test.beforeEach(async ({ page }) => {
        await page.setViewportSize({ width: viewport.width, height: viewport.height });
      });

      test('candidate success keeps Copy-feed primary and one meadow', async ({
        page,
        stubSpaApi,
        stubStudioEndpoints,
        fulfillJson,
      }) => {
        await stubSpaApi({ isCatalogEnabled: false });
        await stubStudioEndpoints();
        await fulfillJson(API_FEEDS, createdFeedBody(), 201);
        await fulfillJson(API_JSON_PREVIEW, jsonPreviewItems, 200, 'application/feed+json');
        await page.addInitScript(() => {
          localStorage.setItem('html2rss_access_token', 'token-123');
        });
        await page.goto('/');
        await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);
        await page.getByRole('button', { name: COPY.createFeed }).click();

        await expect(page.getByRole('button', { name: COPY.copyFeedUrl })).toBeFocused();
        await expect(page.getByRole('button', { name: COPY.saveAndGenerate })).toHaveClass(/btn--ghost/);
        await expect(page.getByRole('button', { name: COPY.copyYaml })).toBeVisible();
        await expect(page.getByRole('link', { name: COPY.proposeDirectory })).toBeVisible();
        await expect(page.locator('.ui-item-list')).toHaveCount(1);
        await expect(
          page.getByRole('button', { name: COPY.addSelector('Sample headline') }).first()
        ).toBeVisible();
        await expect(page.getByLabel(COPY.fieldLink)).toHaveCount(0);
        await assertNoRefineChrome(page);
      });

      test('valid-empty suggestions stay neutral with manual activators', async ({
        page,
        stubSpaApi,
        stubStudioEndpoints,
        fulfillJson,
      }) => {
        await stubSpaApi({ isCatalogEnabled: false });
        await stubStudioEndpoints({ suggestBody: suggestSuccessBody() });
        await fulfillJson(API_FEEDS, createdFeedBody(), 201);
        await fulfillJson(API_JSON_PREVIEW, { items: [] }, 200, 'application/feed+json');
        await page.addInitScript(() => {
          localStorage.setItem('html2rss_access_token', 'token-123');
        });
        await page.goto('/');
        await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);
        await page.getByRole('button', { name: COPY.createFeed }).click();

        await expect(page.getByText(COPY.feedReady)).toBeVisible();
        await expect(page.getByText(COPY.selectorSuggestionsEmpty)).toBeVisible();
        await expect(
          page.getByRole('button', { name: COPY.addOptionalField(COPY.fieldTitle) })
        ).toBeVisible();
        await expect(page.getByLabel(COPY.fieldTitle)).toHaveCount(0);
        await assertNoRefineChrome(page);
      });

      test('suggestion failure stays retryable without faking candidates', async ({
        page,
        stubSpaApi,
        stubStudioEndpoints,
        fulfillJson,
      }) => {
        await stubSpaApi({ isCatalogEnabled: false });
        await stubStudioEndpoints();
        await page.route(API_SUGGEST, async (route) => {
          await route.fulfill({
            status: 403,
            contentType: 'application/json',
            body: JSON.stringify(
              buildStructuredErrorResponse({
                code: 'FORBIDDEN',
                message: 'Auto source feature is disabled',
                kind: 'auth',
                retryable: false,
                next_action: 'none',
                retry_action: 'none',
              })
            ),
          });
        });
        await fulfillJson(API_FEEDS, createdFeedBody(), 201);
        await fulfillJson(API_JSON_PREVIEW, { items: [] }, 200, 'application/feed+json');
        await page.addInitScript(() => {
          localStorage.setItem('html2rss_access_token', 'token-123');
        });
        await page.goto('/');
        await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);
        await page.getByRole('button', { name: COPY.createFeed }).click();

        await expect(page.getByText(COPY.feedReady)).toBeVisible();
        await expect(page.getByText('Auto source feature is disabled')).toBeVisible();
        await expect(page.getByRole('button', { name: COPY.retrySelectorSuggestions })).toBeVisible();
        await expect(page.getByRole('button', { name: COPY.addSelector('Sample headline') })).toHaveCount(0);
        await assertNoRefineChrome(page);
      });

      test('guest ready has no studio controls', async ({ page, stubSpaApi, fulfillJson }) => {
        await stubSpaApi({ isCatalogEnabled: false, isTokenRequired: false });
        await fulfillJson(API_FEEDS, createdFeedBody(), 201);
        await fulfillJson(API_JSON_PREVIEW, jsonPreviewItems, 200, 'application/feed+json');
        await page.goto('/');
        await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);
        await page.getByRole('button', { name: COPY.createFeed }).click();

        await expect(page.getByText(COPY.feedReady)).toBeVisible();
        await expect(page.getByRole('button', { name: COPY.copyFeedUrl })).toBeFocused();
        await expect(page.getByLabel(COPY.itemsSelector, { exact: true })).toHaveCount(0);
        await expect(page.getByRole('button', { name: COPY.saveAndGenerate })).toHaveCount(0);
        await assertNoRefineChrome(page);
      });

      test('authenticated ready promotes Save only after edit', async ({ page, createReadyResult }) => {
        await createReadyResult({ isCatalogEnabled: false });

        const save = page.getByRole('button', { name: COPY.saveAndGenerate });
        await expect(save).toHaveClass(/btn--ghost/);
        await expect(save).toBeDisabled();
        await page.getByLabel(COPY.itemsSelector, { exact: true }).fill('article.card');
        await expect(save).toHaveClass(/btn--primary/);
        await expect(page.getByRole('button', { name: COPY.copyFeedUrl })).toBeVisible();
        await assertNoRefineChrome(page);
      });

      test('unresolved mounts Save as the sole primary', async ({
        page,
        stubSpaApi,
        stubStudioEndpoints,
      }) => {
        await stubSpaApi({ isCatalogEnabled: false });
        await stubStudioEndpoints();
        await page.route(API_FEEDS, async (route) => {
          if (route.request().method() !== 'POST') {
            await route.fallback();
            return;
          }
          await route.fulfill({
            status: 422,
            contentType: 'application/json',
            body: JSON.stringify(
              buildStructuredErrorResponse({
                code: 'EXTRACTION_EMPTY',
                message: EMPTY_NOTICE,
                kind: 'input',
                retryable: false,
                next_action: 'correct_input',
                retry_action: 'none',
              })
            ),
          });
        });
        await page.addInitScript(() => {
          localStorage.setItem('html2rss_access_token', 'token-123');
        });
        await page.goto('/');
        await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);
        await page.getByRole('button', { name: COPY.createFeed }).click();

        await expect(page).toHaveURL(/\/#\/result$/);
        await expect(page.locator('.result-shell')).toHaveAttribute('data-state', 'unresolved');
        await expect(page.getByRole('button', { name: COPY.saveAndGenerate })).toHaveClass(/btn--primary/);
        await expect(page.getByRole('button', { name: COPY.copyFeedUrl })).toHaveCount(0);
        await expect(page.getByRole('link', { name: COPY.proposeDirectory })).toHaveCount(0);
        await expect(page.locator('.ui-item-list')).toHaveCount(0);
        await assertNoRefineChrome(page);
      });

      test('studio-off hides the editor on ready', async ({ page, createReadyResult }) => {
        await createReadyResult({ isCatalogEnabled: false, isStudioEnabled: false });

        await expect(page.getByText(COPY.feedReady)).toBeVisible();
        await expect(page.getByRole('button', { name: COPY.copyFeedUrl })).toBeFocused();
        await expect(page.getByLabel(COPY.itemsSelector, { exact: true })).toHaveCount(0);
        await expect(page.getByRole('button', { name: COPY.saveAndGenerate })).toHaveCount(0);
        await assertNoRefineChrome(page);
      });
    });
  }
});
