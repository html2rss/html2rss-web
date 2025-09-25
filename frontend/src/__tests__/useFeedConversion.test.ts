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
    const mockResult = {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com',
      strategy: 'ssrf_filter',
      public_url: 'https://example.com/feed.xml',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    fetchMock.mockResolvedValueOnce({
      ok: true,
      json: () =>
        Promise.resolve({
          success: true,
          data: {
            feed: mockResult,
          },
        }),
    } as unknown as Response);

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com', 'ssrf_filter', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toEqual(mockResult);
    expect(result.current.error).toBeNull();
    expect(fetchMock).toHaveBeenCalledWith('/api/v1/feeds', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer testtoken',
      },
      body: JSON.stringify({
        url: 'https://example.com',
        strategy: 'ssrf_filter',
      }),
    });
  });

  it('should handle conversion error', async () => {
    fetchMock.mockResolvedValueOnce({
      ok: false,
      status: 400,
      json: () =>
        Promise.resolve({
          error: {
            message: 'Bad Request',
          },
        }),
    } as unknown as Response);

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com', 'ssrf_filter', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('Bad Request');
  });

  it('should handle network errors gracefully', async () => {
    fetchMock.mockRejectedValueOnce(new Error('Network error'));

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com', 'ssrf_filter', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('Network error');
  });
});
