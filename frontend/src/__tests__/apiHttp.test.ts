import { afterEach, describe, expect, it, vi } from 'vitest';
import { getApiMetadata } from '../api/generated/sdk.gen';
import { httpRequestUrl, jsonBaseUrl, unwrap } from '../api/http/client';
import { requestConfigCatalog } from '../api/http/catalog';
import { postCreateFeed, postPreviewFeed, postSuggestSelectors, postValidateFeed } from '../api/http/feeds';
import { requestApiMetadata } from '../api/http/metadata';
import { createdFeedBody, emptyCatalog, metadataBody } from './mocks/apiFixtures';

afterEach(() => {
  vi.restoreAllMocks();
});

function fetchRequest(fetchMock: ReturnType<typeof vi.spyOn>, callIndex = 0): Request {
  const input = fetchMock.mock.calls[callIndex]?.[0];
  if (!(input instanceof Request)) {
    throw new TypeError(`expected fetch call ${callIndex} to receive a Request`);
  }
  return input;
}

describe('unwrap / same-origin client', () => {
  it('pins requests to same-origin /api/v1 and never api.html2rss.dev', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue(Response.json(metadataBody()));

    const envelope = await unwrap(getApiMetadata({ baseUrl: jsonBaseUrl() }));
    const requested = httpRequestUrl(fetchRequest(fetchMock));

    expect(requested.host).not.toBe('api.html2rss.dev');
    expect(requested.pathname).toMatch(/^\/api\/v1\/?$/);
    expect(envelope).toMatchObject({ ok: true, status: 200, body: { success: true } });
  });

  it('unwraps HTTP errors into ok/status/body without throwing', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      Response.json({ error: 'catalog_disabled' }, { status: 404 })
    );

    const envelope = await unwrap(getApiMetadata({ baseUrl: jsonBaseUrl() }));
    expect(envelope).toMatchObject({
      ok: false,
      status: 404,
      body: { error: 'catalog_disabled' },
    });
  });
});

describe('requestApiMetadata', () => {
  it('loads GET /api/v1 through the generated client on the same origin', async () => {
    const body = metadataBody();
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue(Response.json(body));

    const payload = await requestApiMetadata();
    const requested = httpRequestUrl(fetchRequest(fetchMock));

    expect(requested.pathname).toMatch(/^\/api\/v1\/?$/);
    expect(payload?.data.instance.feed_creation.enabled).toBe(true);
  });

  it('returns undefined when instance is missing', async () => {
    const body = metadataBody();
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      Response.json({ success: true, data: { api: body.data.api } })
    );

    await expect(requestApiMetadata()).resolves.toBeUndefined();
  });
});

describe('requestConfigCatalog', () => {
  it('loads GET /configs through the generated client and ignores catalog.url', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue(Response.json(emptyCatalog));

    const payload = await requestConfigCatalog();
    const requested = httpRequestUrl(fetchRequest(fetchMock));

    expect(requested.host).not.toBe('api.html2rss.dev');
    expect(requested.pathname).toBe('/api/v1/configs');
    expect(payload).toMatchObject({ success: true, meta: { catalog_version: 2 } });
  });

  it('returns undefined when the catalog is disabled', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      Response.json({ error: 'catalog_disabled' }, { status: 404 })
    );

    await expect(requestConfigCatalog()).resolves.toBeUndefined();
  });
});

describe('postCreateFeed', () => {
  it('POSTs /feeds on the same origin and omits Authorization when the token is empty', async () => {
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(Response.json({ success: false, error: { code: 'UNAUTHORIZED' } }, { status: 401 }));

    const envelope = await postCreateFeed('https://example.com', '  ');
    const input = fetchRequest(fetchMock);
    const requested = httpRequestUrl(input);

    expect(requested.pathname).toBe('/api/v1/feeds');
    expect(input.method).toBe('POST');
    expect(input.headers.get('Authorization')).toBeNull();
    expect(JSON.parse(await input.clone().text())).toEqual({ url: 'https://example.com' });
    expect(envelope).toMatchObject({ ok: false, status: 401 });
  });

  it('sends Bearer auth and optional selectors through the generated client', async () => {
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(
        Response.json(
          createdFeedBody({ feed_token: 'tok', id: 'feed-1', name: 'Example', url: 'https://example.com' }),
          { status: 201 }
        )
      );
    const selectors = {
      items: { selector: 'article' },
      title: { selector: 'h2', extractor: 'text' as const },
    };

    const envelope = await postCreateFeed('https://example.com/articles', 'token-123', selectors);
    const input = fetchRequest(fetchMock);

    expect(input.headers.get('Authorization')).toBe('Bearer token-123');
    expect(JSON.parse(await input.clone().text())).toEqual({
      url: 'https://example.com/articles',
      selectors,
    });
    expect(envelope).toMatchObject({ ok: true, status: 201 });
  });
});

describe('studio JSON writes', () => {
  it('POSTs validate, preview, and suggest through the generated client', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue(Response.json({ success: true }));
    const selectors = { items: { selector: 'article' } };

    await postValidateFeed('token-123', 'https://example.com', selectors);
    await postPreviewFeed('token-123', 'https://example.com', selectors);
    await postSuggestSelectors('token-123', 'https://example.com');

    const paths = [0, 1, 2].map((index) => httpRequestUrl(fetchRequest(fetchMock, index)).pathname);

    expect(paths).toEqual([
      '/api/v1/feeds/validate',
      '/api/v1/feeds/preview',
      '/api/v1/feeds/suggest_selectors',
    ]);
  });
});
