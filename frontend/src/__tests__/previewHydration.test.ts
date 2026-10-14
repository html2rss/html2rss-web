import { afterEach, beforeEach, describe, expect, it, vi, type SpyInstance } from 'vitest';
import { COPY } from '../journey/copy';
import {
  buildCreatedFeedResult,
  loadPreviewItems,
  loadPreviewItemsWithRetry,
  normalizePreviewItems,
  PREVIEW_ERROR_BODY_MAX_CHARS,
  PREVIEW_UNAVAILABLE_MESSAGE,
  resolvePreviewHttpWarningMessage,
} from '../feeds/feedsService';

const feed = {
  id: 'feed-1',
  name: 'Example Feed',
  url: 'https://example.com/articles',
  feed_token: 'feed-token-1',
  public_url: '/api/v1/feeds/feed-token-1',
  json_public_url: '/api/v1/feeds/feed-token-1.json',
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-01-01T00:00:00Z',
};

describe('previewHydration', () => {
  let fetchMock: SpyInstance;

  beforeEach(() => {
    fetchMock = vi.spyOn(globalThis, 'fetch');
  });

  afterEach(() => {
    fetchMock.mockRestore();
    vi.useRealTimers();
  });

  it('builds an initial created result with nested preview status', () => {
    expect(buildCreatedFeedResult(feed)).toMatchObject({
      feed,
      preview: { status: 'created', items: [], isLoading: false },
      warnings: [],
    });
  });

  it('normalizes json feed items and caps at five', () => {
    const items = normalizePreviewItems([
      {
        title: 'One',
        content_text: 'A',
        date_published: '2024-01-01',
        url: 'https://example.com/1',
        image: 'https://cdn.example/a.jpg',
      },
      { title: 'Two', description: 'B', publishedLabel: 'Jan 2' },
      { title: 'Three' },
      { title: 'Four' },
      { title: 'Five' },
      { title: 'Six' },
      { title: '' },
      undefined,
    ]);

    expect(items).toHaveLength(5);
    expect(items[0]).toMatchObject({
      title: 'One',
      excerpt: 'A',
      publishedLabel: '2024-01-01',
      url: 'https://example.com/1',
    });
    expect(items[0]).not.toHaveProperty('imageUrl');
  });

  it('keeps ten member items and only safe http(s) images', () => {
    const items = normalizePreviewItems(
      [
        { title: 'Safe', image: 'https://cdn.example/a.jpg' },
        // HTTP is an accepted image scheme; the assertion below must stay non-HTTPS.
        // eslint-disable-next-line unicorn/prefer-https
        { title: 'Plain http', image: 'http://cdn.example/b.jpg' },
        { title: 'Script', image: 'javascript:alert(1)' },
        { title: 'Data', image: 'data:image/png;base64,aaaa' },
        { title: 'Spaced', image: 'https://cdn.example/a b.jpg' },
        ...Array.from({ length: 7 }, (_, index) => ({ title: `Extra ${index}` })),
      ],
      'member'
    );

    expect(items).toHaveLength(10);
    expect(items[0]?.imageUrl).toBe('https://cdn.example/a.jpg');
    // eslint-disable-next-line unicorn/prefer-https -- same accepted HTTP image as the fixture
    expect(items[1]?.imageUrl).toBe('http://cdn.example/b.jpg');
    expect(items[2]).not.toHaveProperty('imageUrl');
    expect(items[3]).not.toHaveProperty('imageUrl');
    expect(items[4]).not.toHaveProperty('imageUrl');
  });

  it('marks non-transient preview HTTP failures as non-retryable', async () => {
    fetchMock.mockResolvedValueOnce(new Response('', { status: 422 }));

    await expect(loadPreviewItems('/api/v1/feeds/feed-token-1.json')).resolves.toMatchObject({
      status: 'preview_failed',
      warnings: [
        {
          code: 'PREVIEW_HTTP_422',
          message: PREVIEW_UNAVAILABLE_MESSAGE,
          retryable: false,
          nextAction: 'wait',
        },
      ],
    });
  });

  it('passes short text/plain HTTP error bodies through as warning.message', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response('This site blocked automated access. Try another URL or site.', {
        status: 422,
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
      })
    );

    await expect(loadPreviewItems('/api/v1/feeds/feed-token-1.json')).resolves.toMatchObject({
      status: 'preview_failed',
      warnings: [
        {
          code: 'PREVIEW_HTTP_422',
          message: 'This site blocked automated access. Try another URL or site.',
          retryable: false,
          nextAction: 'wait',
        },
      ],
    });
  });

  it('falls back to COPY when preview HTTP error bodies are HTML or huge', async () => {
    const htmlMessage = await resolvePreviewHttpWarningMessage(
      new Response('<!DOCTYPE html><html><body>error</body></html>', {
        status: 502,
        headers: { 'Content-Type': 'text/html' },
      })
    );
    expect(htmlMessage).toBe(COPY.previewUnavailable);

    const hugeMessage = await resolvePreviewHttpWarningMessage(
      new Response('x'.repeat(PREVIEW_ERROR_BODY_MAX_CHARS + 1), {
        status: 503,
        headers: { 'Content-Type': 'text/plain' },
      })
    );
    expect(hugeMessage).toBe(COPY.previewUnavailable);

    const jsonMessage = await resolvePreviewHttpWarningMessage(
      Response.json({ items: [] }, { status: 500, headers: { 'Content-Type': 'application/feed+json' } })
    );
    expect(jsonMessage).toBe(COPY.previewUnavailable);
  });

  it('retries only transient preview failures', async () => {
    vi.useFakeTimers();
    fetchMock
      .mockResolvedValueOnce(new Response('', { status: 503 }))
      .mockResolvedValueOnce(
        Response.json(
          { items: [{ title: 'Preview item', content_text: 'Excerpt', date_published: '2024-01-02' }] },
          { status: 200, headers: { 'Content-Type': 'application/feed+json' } }
        )
      );

    const pending = loadPreviewItemsWithRetry('/api/v1/feeds/feed-token-1.json');
    await vi.advanceTimersByTimeAsync(260);
    await expect(pending).resolves.toMatchObject({
      status: 'preview_ready',
      items: [{ title: 'Preview item' }],
    });
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });
});
