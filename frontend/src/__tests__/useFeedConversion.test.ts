import { describe, it, expect, beforeEach, afterEach, vi, type SpyInstance } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/preact';
import { useFeedConversion } from '../hooks/useFeedConversion';

describe('useFeedConversion', () => {
  let fetchMock: SpyInstance;

  beforeEach(() => {
    vi.clearAllMocks();
    fetchMock = vi.spyOn(global, 'fetch');
  });

  afterEach(() => {
    fetchMock.mockRestore();
  });

  it('should initialize with default state', () => {
    const { result } = renderHook(() => useFeedConversion());

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBeNull();
  });

  it('should handle successful conversion', async () => {
    const mockFeed = {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com',
      strategy: 'faraday',
      feed_token: 'test-token',
      public_url: 'https://example.com/feed',
      json_public_url: 'https://example.com/feed.json',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          success: true,
          data: { feed: mockFeed },
        }),
        {
          status: 201,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    );
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          items: [
            {
              title: 'Preview item',
              content_text: 'Preview excerpt',
              url: 'https://example.com/item',
              date_published: '2024-01-02T00:00:00Z',
            },
          ],
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/feed+json' },
        }
      )
    );

    const { result } = renderHook(() => useFeedConversion());
    let conversionResult: Awaited<ReturnType<typeof result.current.convertFeed>> | undefined;

    await act(async () => {
      conversionResult = await result.current.convertFeed('https://example.com', 'faraday', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
    expect(conversionResult).toEqual({
      feed: mockFeed,
      preview: {
        items: [],
        error: null,
        isLoading: true,
      },
      retry: null,
    });
    await waitFor(() => {
      expect(result.current.result).toEqual({
        feed: mockFeed,
        preview: {
          items: [
            {
              title: 'Preview item',
              excerpt: 'Preview excerpt',
              publishedLabel: 'Jan 2, 2024',
              url: 'https://example.com/item',
            },
          ],
          error: null,
          isLoading: false,
        },
        retry: null,
      });
    });
    expect(result.current.error).toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('should handle conversion error', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          success: false,
          error: { message: 'Bad Request' },
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await expect(result.current.convertFeed('https://example.com', 'faraday', 'testtoken')).rejects.toThrow(
        'Bad Request'
      );
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toContain('Bad Request');
  });

  it('should handle network errors gracefully', async () => {
    fetchMock.mockRejectedValueOnce(new Error('Network error'));

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await expect(result.current.convertFeed('https://example.com', 'faraday', 'testtoken')).rejects.toThrow(
        'Network error'
      );
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('Network error');
  });

  it('preserves the created feed when preview loading fails after feed creation', async () => {
    const createdFeed = {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com',
      strategy: 'faraday',
      feed_token: 'test-token',
      public_url: 'https://example.com/feed',
      json_public_url: 'https://example.com/feed.json',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          success: true,
          data: {
            feed: createdFeed,
          },
        }),
        {
          status: 201,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    );
    fetchMock.mockResolvedValueOnce(new Response('nope', { status: 502 }));

    const { result } = renderHook(() => useFeedConversion());
    let conversionResult: Awaited<ReturnType<typeof result.current.convertFeed>> | undefined;

    await act(async () => {
      conversionResult = await result.current.convertFeed('https://example.com', 'faraday', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
    expect(conversionResult).toEqual({
      feed: createdFeed,
      preview: {
        items: [],
        error: null,
        isLoading: true,
      },
      retry: null,
    });
    await waitFor(() => {
      expect(result.current.result).toEqual({
        feed: createdFeed,
        preview: {
          items: [],
          error: 'Preview unavailable right now.',
          isLoading: false,
        },
        retry: null,
      });
    });
    expect(result.current.error).toBeNull();
  });

  it('publishes the result before preview loading finishes', async () => {
    const createdFeed = {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com',
      strategy: 'faraday',
      feed_token: 'test-token',
      public_url: 'https://example.com/feed',
      json_public_url: 'https://example.com/feed.json',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    let resolvePreviewResponse: ((value: Response) => void) | null = null;
    const previewResponse = new Promise<Response>((resolve) => {
      resolvePreviewResponse = resolve;
    });

    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          success: true,
          data: { feed: createdFeed },
        }),
        {
          status: 201,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    );
    fetchMock.mockReturnValueOnce(previewResponse as Promise<Response>);

    const { result } = renderHook(() => useFeedConversion());

    let conversionResult: Awaited<ReturnType<typeof result.current.convertFeed>> | undefined;
    await act(async () => {
      conversionResult = await result.current.convertFeed('https://example.com', 'faraday', 'testtoken');
    });

    expect(conversionResult).toEqual({
      feed: createdFeed,
      preview: {
        items: [],
        error: null,
        isLoading: true,
      },
      retry: null,
    });
    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toEqual(conversionResult);

    resolvePreviewResponse?.(
      new Response(
        JSON.stringify({
          items: [
            {
              title: 'Preview item',
              content_text: 'Preview excerpt',
              url: 'https://example.com/item',
              date_published: '2024-01-02T00:00:00Z',
            },
          ],
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/feed+json' },
        }
      )
    );

    await waitFor(() => {
      expect(result.current.result?.preview).toEqual({
        items: [
          {
            title: 'Preview item',
            excerpt: 'Preview excerpt',
            publishedLabel: 'Jan 2, 2024',
            url: 'https://example.com/item',
          },
        ],
        error: null,
        isLoading: false,
      });
    });
  });

  it('normalizes hostname-only input before creating a feed', async () => {
    const createdFeed = {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com/articles',
      strategy: 'faraday',
      feed_token: 'test-token',
      public_url: 'https://example.com/feed',
      json_public_url: 'https://example.com/feed.json',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          success: true,
          data: {
            feed: createdFeed,
          },
        }),
        {
          status: 201,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    );
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ items: [] }), {
        status: 200,
        headers: { 'Content-Type': 'application/feed+json' },
      })
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('example.com/articles', 'faraday', 'testtoken');
    });

    const firstRequest = fetchMock.mock.calls[0]?.[0] as Request;
    expect(firstRequest instanceof Request ? firstRequest.url : String(firstRequest)).toContain(
      '/api/v1/feeds'
    );
    expect(await firstRequest.clone().json()).toEqual({
      url: 'https://example.com/articles',
      strategy: 'faraday',
    });
  });

  it('automatically retries browserless after a faraday failure', async () => {
    const createdFeed = {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com/articles',
      strategy: 'browserless',
      feed_token: 'test-token',
      public_url: 'https://example.com/feed',
      json_public_url: 'https://example.com/feed.json',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    fetchMock
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: false,
            error: { message: 'Upstream timeout' },
          }),
          {
            status: 502,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: {
              feed: createdFeed,
            },
          }),
          {
            status: 201,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ items: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/feed+json' },
        })
      );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'faraday', 'testtoken');
    });

    const retryRequest = fetchMock.mock.calls[1]?.[0] as Request;
    expect(await retryRequest.clone().json()).toEqual({
      url: 'https://example.com/articles',
      strategy: 'browserless',
    });
    expect(result.current.result?.retry).toEqual({
      automatic: true,
      from: 'faraday',
      to: 'browserless',
    });
    await waitFor(() => {
      expect(result.current.result?.preview.isLoading).toBe(false);
    });
  });

  it('does not auto-retry browserless for unauthorized faraday failures', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          success: false,
          error: { message: 'Unauthorized' },
        }),
        {
          status: 401,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await expect(
        result.current.convertFeed('https://example.com/articles', 'faraday', 'testtoken')
      ).rejects.toThrow('Unauthorized');
    });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('Unauthorized');
  });

  it('does not auto-retry when API returns a non-retryable BAD_REQUEST code', async () => {
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          success: false,
          error: { code: 'BAD_REQUEST', message: 'Input rejected' },
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await expect(
        result.current.convertFeed('https://example.com/articles', 'faraday', 'testtoken')
      ).rejects.toThrow('Input rejected');
    });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('Input rejected');
  });

  it('still auto-retries when API returns INTERNAL_SERVER_ERROR even if message contains a url', async () => {
    const createdFeed = {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com/articles',
      strategy: 'browserless',
      feed_token: 'test-token',
      public_url: 'https://example.com/feed',
      json_public_url: 'https://example.com/feed.json',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    fetchMock
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: false,
            error: {
              code: 'INTERNAL_SERVER_ERROR',
              message: 'Failed to fetch https://example.com/articles',
            },
          }),
          {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: {
              feed: createdFeed,
            },
          }),
          {
            status: 201,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ items: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/feed+json' },
        })
      );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'faraday', 'testtoken');
    });

    const retryRequest = fetchMock.mock.calls[1]?.[0] as Request;
    expect(await retryRequest.clone().json()).toEqual({
      url: 'https://example.com/articles',
      strategy: 'browserless',
    });
    expect(result.current.result?.retry).toEqual({
      automatic: true,
      from: 'faraday',
      to: 'browserless',
    });
  });

  it('does not offer a duplicate manual retry after automatic fallback also fails', async () => {
    fetchMock
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: false,
            error: { message: 'Upstream timeout' },
          }),
          {
            status: 502,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: false,
            error: { message: 'Browserless also failed' },
          }),
          {
            status: 502,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

    const { result } = renderHook(() => useFeedConversion());

    let thrownError: (Error & { manualRetryStrategy?: string }) | undefined;
    await act(async () => {
      try {
        await result.current.convertFeed('https://example.com/articles', 'faraday', 'testtoken');
      } catch (error) {
        thrownError = error as Error & { manualRetryStrategy?: string };
      }
    });

    expect(thrownError?.message).toBe(
      'Tried faraday first, then browserless. First attempt failed with: Upstream timeout. Second attempt failed with: Browserless also failed'
    );
    expect(thrownError?.manualRetryStrategy).toBeUndefined();
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe(
      'Tried faraday first, then browserless. First attempt failed with: Upstream timeout. Second attempt failed with: Browserless also failed'
    );
  });

  it('ignores stale preview updates from an earlier conversion request', async () => {
    const feedA = {
      id: 'feed-a-id',
      name: 'Feed A',
      url: 'https://example.com/a',
      strategy: 'faraday',
      feed_token: 'feed-a-token',
      public_url: 'https://example.com/feed-a',
      json_public_url: 'https://example.com/feed-a.json',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };
    const feedB = {
      id: 'feed-b-id',
      name: 'Feed B',
      url: 'https://example.com/b',
      strategy: 'faraday',
      feed_token: 'feed-b-token',
      public_url: 'https://example.com/feed-b',
      json_public_url: 'https://example.com/feed-b.json',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    let resolvePreviewA: ((value: Response) => void) | null = null;
    const previewAPromise = new Promise<Response>((resolve) => {
      resolvePreviewA = resolve;
    });
    let resolvePreviewB: ((value: Response) => void) | null = null;
    const previewBPromise = new Promise<Response>((resolve) => {
      resolvePreviewB = resolve;
    });

    fetchMock
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: { feed: feedA },
          }),
          {
            status: 201,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      )
      .mockReturnValueOnce(previewAPromise as Promise<Response>)
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            data: { feed: feedB },
          }),
          {
            status: 201,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      )
      .mockReturnValueOnce(previewBPromise as Promise<Response>);

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com/a', 'faraday', 'testtoken');
    });
    await act(async () => {
      await result.current.convertFeed('https://example.com/b', 'faraday', 'testtoken');
    });

    expect(result.current.result?.feed.feed_token).toBe('feed-b-token');

    resolvePreviewB?.(
      new Response(
        JSON.stringify({
          items: [
            {
              title: 'Preview B',
              content_text: 'Current preview item',
              url: 'https://example.com/b/item',
              date_published: '2024-01-02T00:00:00Z',
            },
          ],
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/feed+json' },
        }
      )
    );

    await waitFor(() => {
      expect(result.current.result?.feed.feed_token).toBe('feed-b-token');
      expect(result.current.result?.preview.items[0]?.title).toBe('Preview B');
    });

    resolvePreviewA?.(
      new Response(
        JSON.stringify({
          items: [
            {
              title: 'Preview A',
              content_text: 'Stale preview item',
              url: 'https://example.com/a/item',
              date_published: '2024-01-03T00:00:00Z',
            },
          ],
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/feed+json' },
        }
      )
    );

    await waitFor(() => {
      expect(result.current.result?.feed.feed_token).toBe('feed-b-token');
      expect(result.current.result?.preview.items[0]?.title).toBe('Preview B');
    });
  });
});
