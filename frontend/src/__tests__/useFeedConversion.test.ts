import { describe, it, expect, beforeEach, afterEach, vi, type SpyInstance } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
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

    await act(async () => {
      await result.current.convertFeed('https://example.com', 'faraday', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
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
      },
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

    await act(async () => {
      await result.current.convertFeed('https://example.com', 'faraday', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toEqual({
      feed: createdFeed,
      preview: {
        items: [],
        error: 'Preview unavailable right now.',
      },
    });
    expect(result.current.error).toBeNull();
  });
});
