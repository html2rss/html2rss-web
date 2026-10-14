import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { server, buildFeedResponse, buildStructuredErrorResponse } from './mocks/server';
import { JSON_FEED_PREVIEW_PATH, jsonPreviewItems } from './mocks/apiFixtures';
import { useFeedCreation } from '../feed';

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

function useCreateFeedHandler() {
  let createCount = 0;
  server.use(
    http.post('/api/v1/feeds', () => {
      createCount += 1;
      return HttpResponse.json(buildFeedResponse(mockFeed), { status: 201 });
    })
  );
  return () => createCount;
}

describe('useFeedCreation', () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('creates a feed from metadata and hydrates preview from json_public_url', async () => {
    useCreateFeedHandler();

    const { result } = renderHook(() => useFeedCreation());
    await act(async () => {
      await result.current.createFeed('https://example.com/articles', 'token-123');
    });

    await waitFor(() => {
      expect(result.current.result?.preview.status).toBe('preview_ready');
      expect(result.current.result?.preview.items[0]?.title).toBe(jsonPreviewItems.items[0]?.title);
    });
  });

  it('retries only preview fetches on transient preview failure', async () => {
    vi.useFakeTimers();
    const createCount = useCreateFeedHandler();
    let previewAttempts = 0;
    server.use(
      http.get(JSON_FEED_PREVIEW_PATH, () => {
        previewAttempts += 1;
        if (previewAttempts === 1) {
          return new HttpResponse('', { status: 503 });
        }
        return HttpResponse.json(jsonPreviewItems, {
          headers: { 'content-type': 'application/feed+json' },
        });
      })
    );

    const { result } = renderHook(() => useFeedCreation());
    await act(async () => {
      await result.current.createFeed('https://example.com/articles', 'token-123');
    });

    await act(async () => {
      await vi.advanceTimersByTimeAsync(260);
    });

    await waitFor(() => {
      expect(result.current.result?.preview.status).toBe('preview_ready');
    });
    expect(createCount()).toBe(1);
    expect(previewAttempts).toBe(2);
  });

  it('retries preview without recreating the feed', async () => {
    const createCount = useCreateFeedHandler();
    let previewAttempts = 0;
    server.use(
      http.get(JSON_FEED_PREVIEW_PATH, () => {
        previewAttempts += 1;
        if (previewAttempts === 1) {
          return new HttpResponse('', { status: 422 });
        }
        return HttpResponse.json(jsonPreviewItems, {
          headers: { 'content-type': 'application/feed+json' },
        });
      })
    );

    const { result } = renderHook(() => useFeedCreation());
    await act(async () => {
      await result.current.createFeed('https://example.com/articles', 'token-123');
    });
    await waitFor(() => expect(result.current.result?.preview.status).toBe('preview_failed'));

    act(() => result.current.retryPreviewFetch());

    await waitFor(() => expect(result.current.result?.preview.status).toBe('preview_ready'));
    expect(createCount()).toBe(1);
  });

  it('keeps the creation audience when preview is retried', async () => {
    useCreateFeedHandler();
    let previewAttempts = 0;
    const richPreview = {
      items: [
        { title: 'Shown', image: 'https://cdn.example/a.jpg' },
        ...Array.from({ length: 9 }, (_, index) => ({ title: `Extra ${index}` })),
      ],
    };
    server.use(
      http.get(JSON_FEED_PREVIEW_PATH, () => {
        previewAttempts += 1;
        if (previewAttempts === 1) {
          return new HttpResponse('', { status: 422 });
        }
        return HttpResponse.json(richPreview, {
          headers: { 'content-type': 'application/feed+json' },
        });
      })
    );

    const { result } = renderHook(() => useFeedCreation());
    await act(async () => {
      await result.current.createFeed('https://example.com/articles', ' '.repeat(3));
    });
    await waitFor(() => expect(result.current.result?.preview.status).toBe('preview_failed'));

    act(() => result.current.retryPreviewFetch());

    await waitFor(() => expect(result.current.result?.preview.status).toBe('preview_ready'));
    expect(result.current.result?.preview.items).toHaveLength(5);
    expect(result.current.result?.preview.items[0]).not.toHaveProperty('imageUrl');
  });

  it('rejects camelCase-only create payloads to enforce canonical snake_case', async () => {
    server.use(
      http.post('/api/v1/feeds', () =>
        HttpResponse.json(
          {
            success: true,
            data: {
              feed: {
                id: 'feed-1',
                name: 'Example Feed',
                url: 'https://example.com/articles',
                feedToken: 'generated-token',
                publicUrl: '/api/v1/feeds/generated-token',
                jsonPublicUrl: '/api/v1/feeds/generated-token.json',
              },
            },
          },
          { status: 201 }
        )
      )
    );

    const { result } = renderHook(() => useFeedCreation());

    await act(async () => {
      await expect(result.current.createFeed('https://example.com/articles', 'token')).rejects.toMatchObject({
        kind: 'server',
        code: 'INVALID_RESPONSE',
      });
    });
  });

  it('propagates structured auth failures without parsing the message text', async () => {
    server.use(
      http.post('/api/v1/feeds', () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            code: 'UNAUTHORIZED',
            message: 'Authentication required',
            kind: 'auth',
            retryable: false,
            next_action: 'enter_token',
            retry_action: 'none',
          }),
          { status: 401 }
        )
      )
    );

    const { result } = renderHook(() => useFeedCreation());

    await act(async () => {
      await expect(result.current.createFeed('https://example.com/articles', 'token')).rejects.toMatchObject({
        message: 'Authentication required',
      });
    });

    expect(result.current.error).toMatchObject({
      kind: 'auth',
      code: 'UNAUTHORIZED',
      nextAction: 'enter_token',
    });
  });
});
