import { afterEach, beforeEach, describe, expect, it, vi, type SpyInstance } from 'vitest';
import {
  buildCreatedFeedResult,
  loadPreviewItems,
  loadPreviewItemsWithRetry,
  normalizePreviewItems,
} from '../feeds/previewHydration';

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
      { title: 'One', content_text: 'A', date_published: '2024-01-01', url: 'https://example.com/1' },
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
  });

  it('marks non-transient preview HTTP failures as non-retryable', async () => {
    fetchMock.mockResolvedValueOnce(new Response('', { status: 422 }));

    await expect(loadPreviewItems('/api/v1/feeds/feed-token-1.json')).resolves.toMatchObject({
      status: 'preview_failed',
      warnings: [{ code: 'PREVIEW_HTTP_422', retryable: false, nextAction: 'wait' }],
    });
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
