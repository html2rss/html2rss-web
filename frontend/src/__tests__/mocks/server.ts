import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import {
  emptyCatalog,
  JSON_FEED_PREVIEW_PATH,
  jsonPreviewItems,
  metadataBody,
  pageUrlFrom,
  selectorsFromValidateRequest,
  DEFAULT_SUGGEST_BUCKETS,
  studioPreviewSuccessBody,
  suggestSuccessBody,
  validateSuccessBody,
  validateYamlForSelectors,
  type CreatedFeedOverrides,
} from './apiFixtures';

export const server = setupServer(
  http.get(/\/api\/v1\/?$/, () => {
    return HttpResponse.json(metadataBody({ openapiUrl: 'https://example.test/openapi.yaml' }));
  }),
  http.get('/api/v1/configs', () => {
    return HttpResponse.json(emptyCatalog);
  }),
  http.get(JSON_FEED_PREVIEW_PATH, () =>
    HttpResponse.json(jsonPreviewItems, {
      headers: { 'content-type': 'application/feed+json' },
    })
  ),
  http.post('/api/v1/feeds/validate', async ({ request }) => {
    const body = await request.json();
    const selectors = selectorsFromValidateRequest(body);
    const yaml = validateYamlForSelectors(selectors, pageUrlFrom(body));
    return HttpResponse.json(validateSuccessBody(selectors, yaml));
  }),
  http.post('/api/v1/feeds/preview', () => {
    return HttpResponse.json(studioPreviewSuccessBody([]));
  }),
  http.post('/api/v1/feeds/suggest_selectors', () => {
    return HttpResponse.json(suggestSuccessBody(DEFAULT_SUGGEST_BUCKETS));
  })
);

export type FeedResponseOverrides = CreatedFeedOverrides;

export {
  buildFeedResponse,
  buildStructuredErrorResponse,
  type StructuredErrorOverrides,
} from './apiFixtures';
