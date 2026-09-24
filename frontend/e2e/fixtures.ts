import { test as base, expect, type Page, type Request } from '@playwright/test';
import { COPY } from '../src/journey/copy';
import {
  createdFeedBody,
  emptyCatalog,
  metadataBody,
  pageUrlFrom,
  selectorsFromValidateRequest,
  studioPreviewSuccessBody,
  suggestSuccessBody,
  validateSuccessBody,
  validateYamlForSelectors,
  type MetadataOptions,
} from '../src/__tests__/mocks/apiFixtures';

export { expect } from '@playwright/test';

export const API_ROOT = /\/api\/v1\/?$/;
export const API_CONFIGS = /\/api\/v1\/configs\/?$/;
export const API_FEEDS = /\/api\/v1\/feeds\/?$/;
export const API_VALIDATE = /\/api\/v1\/feeds\/validate\/?$/;
export const API_SUGGEST = /\/api\/v1\/feeds\/suggest_selectors\/?$/;
export const API_STUDIO_PREVIEW = /\/api\/v1\/feeds\/preview\/?$/;
export const API_JSON_PREVIEW = /\/api\/v1\/feeds\/(?:generated-token|studio-saved-token)\.json$/;

export const EXAMPLE_URL = 'https://example.com/articles';

type SpaFixtures = {
  fulfillJson: (path: RegExp, body: unknown, status?: number, contentType?: string) => Promise<void>;
  stubSpaApi: (options?: MetadataOptions) => Promise<void>;
  stubStudioEndpoints: () => Promise<void>;
  createReadyResult: (
    options?: MetadataOptions & { stubFeedCreates?: (page: Page) => Promise<void> }
  ) => Promise<void>;
};

export const test = base.extend<SpaFixtures>({
  fulfillJson: async ({ page }, use) => {
    await use(async (path, body, status = 200, contentType = 'application/json') => {
      await page.route(path, async (route) => {
        await route.fulfill({
          status,
          contentType,
          body: JSON.stringify(body),
        });
      });
    });
  },

  stubSpaApi: async ({ fulfillJson }, use) => {
    await use(async (options: MetadataOptions = {}) => {
      const isCatalogEnabled = options.isCatalogEnabled ?? true;
      await fulfillJson(API_ROOT, metadataBody(options));
      if (isCatalogEnabled) await fulfillJson(API_CONFIGS, emptyCatalog);
    });
  },

  stubStudioEndpoints: async ({ page, fulfillJson }, use) => {
    await use(async (options: { suggestBody?: unknown } = {}) => {
      await page.route(API_VALIDATE, async (route) => {
        const posted = route.request().postDataJSON() as unknown;
        const selectors = selectorsFromValidateRequest(posted);
        const channelUrl = pageUrlFrom(posted);
        const body = validateSuccessBody(selectors, validateYamlForSelectors(selectors, channelUrl));
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(body),
        });
      });
      await fulfillJson(
        API_SUGGEST,
        options.suggestBody ??
          suggestSuccessBody({
            items: [{ selector: 'article', enhance: false, sample: 'Sample headline' }],
            title: [{ selector: 'h2', sample: 'Sample headline' }],
          })
      );
      await fulfillJson(API_STUDIO_PREVIEW, studioPreviewSuccessBody());
    });
  },

  createReadyResult: async ({ page, fulfillJson, stubSpaApi, stubStudioEndpoints }, use) => {
    await use(async (options = {}) => {
      const { stubFeedCreates, ...metadataOptions } = options;
      await stubSpaApi({ isCatalogEnabled: false, ...metadataOptions });
      if (metadataOptions.isStudioEnabled !== false) await stubStudioEndpoints();
      if (stubFeedCreates) {
        await stubFeedCreates(page);
      } else {
        await fulfillJson(API_FEEDS, createdFeedBody(), 201);
      }
      await fulfillJson(API_JSON_PREVIEW, { items: [] }, 200, 'application/feed+json');
      await page.addInitScript(() => {
        localStorage.setItem('html2rss_access_token', 'token-123');
      });
      await page.goto('/');
      await page.getByLabel(COPY.urlLabel).fill(EXAMPLE_URL);
      await page.getByRole('button', { name: COPY.createFeed }).click();
      await expect(page.getByText(COPY.feedReady)).toBeVisible();
    });
  },
});

export function isSameOriginApi(url: string, path: RegExp): boolean {
  const requested = new URL(url);
  return path.test(requested.pathname) && requested.host !== 'api.html2rss.dev';
}

export function collectPosts(page: Page, path: RegExp, bag: Request[]) {
  page.on('request', (request) => {
    if (request.method() === 'POST' && isSameOriginApi(request.url(), path)) {
      bag.push(request);
    }
  });
}
