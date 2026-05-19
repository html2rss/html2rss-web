import { describe, it, expect, beforeEach, afterEach, vi, type SpyInstance } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/preact';
import { useFeedConversion } from '../hooks/useFeedConversion';

const mockFeed = {
  id: 'feed-1',
  name: 'Example Feed',
  url: 'https://example.com/articles',
  feed_token: 'feed-token-1',
  public_url: '/api/v1/feeds/feed-token-1',
  json_public_url: '/api/v1/feeds/feed-token-1.json',
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-01-01T00:00:00Z',
};

function createResponse(status = 201) {
  return Response.json(
    { success: true, data: { feed: mockFeed } },
    {
      status,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}

function previewResponse(status = 200) {
  return Response.json(
    {
      items: [{ title: 'Preview item', content_text: 'Preview excerpt', date_published: '2024-01-02' }],
    },
    { status, headers: { 'Content-Type': 'application/feed+json' } }
  );
}

describe('useFeedConversion', () => {
  let fetchMock: SpyInstance;

  beforeEach(() => {
    vi.clearAllMocks();
    globalThis.localStorage.clear();
    globalThis.sessionStorage.clear();
    fetchMock = vi.spyOn(globalThis, 'fetch');
  });

  afterEach(() => {
    fetchMock.mockRestore();
  });

  it('creates a feed from metadata and hydrates preview from json_public_url', async () => {
    fetchMock.mockResolvedValueOnce(createResponse()).mockResolvedValueOnce(previewResponse());

    const { result } = renderHook(() => useFeedConversion());
    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'token-123');
    });

    expect(fetchMock.mock.calls[0]?.[0]).toBe('/api/v1/feeds');
    expect(String(fetchMock.mock.calls[1]?.[0])).toMatch(/\/api\/v1\/feeds\/feed-token-1\.json$/);
    expect(fetchMock.mock.calls).toHaveLength(2);

    await waitFor(() => {
      expect(result.current.result?.workflowState).toBe('preview_ready');
      expect(result.current.result?.preview.items[0]?.title).toBe('Preview item');
    });
  });

  it('retries only preview fetches on transient preview failure', async () => {
    vi.useFakeTimers();
    fetchMock
      .mockResolvedValueOnce(createResponse())
      .mockResolvedValueOnce(new Response('', { status: 503 }))
      .mockResolvedValueOnce(previewResponse());

    const { result } = renderHook(() => useFeedConversion());
    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'token-123');
    });

    await act(async () => {
      await vi.advanceTimersByTimeAsync(260);
    });

    await waitFor(() => {
      expect(result.current.result?.workflowState).toBe('preview_ready');
    });
    expect(fetchMock.mock.calls.filter((call) => String(call[0]) === '/api/v1/feeds').length).toBe(1);
    expect(
      fetchMock.mock.calls.filter((call) => String(call[0]).endsWith('/api/v1/feeds/feed-token-1.json'))
        .length
    ).toBe(2);

    vi.useRealTimers();
  });

  it('marks preview failed for non-transient preview responses', async () => {
    fetchMock
      .mockResolvedValueOnce(createResponse())
      .mockResolvedValueOnce(new Response('', { status: 422 }));

    const { result } = renderHook(() => useFeedConversion());
    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'token-123');
    });

    await waitFor(() => {
      expect(result.current.result?.workflowState).toBe('preview_failed');
      expect(result.current.result?.warnings[0]).toMatchObject({
        code: 'PREVIEW_HTTP_422',
        retryable: false,
        nextAction: 'wait',
      });
    });
  });

  it('retries preview without recreating the feed', async () => {
    fetchMock
      .mockResolvedValueOnce(createResponse())
      .mockResolvedValueOnce(new Response('', { status: 422 }));

    const { result } = renderHook(() => useFeedConversion());
    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'token-123');
    });
    await waitFor(() => expect(result.current.result?.workflowState).toBe('preview_failed'));

    fetchMock.mockResolvedValueOnce(previewResponse());
    act(() => result.current.retryPreviewFetch());

    await waitFor(() => expect(result.current.result?.workflowState).toBe('preview_ready'));
    expect(fetchMock.mock.calls.filter((call) => String(call[0]) === '/api/v1/feeds').length).toBe(1);
  });
});
