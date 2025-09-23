import { describe, it, expect, beforeEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { useFeedConversion } from '../hooks/useFeedConversion';

describe('useFeedConversion', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (global.fetch as any).mockClear();
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
      username: 'testuser',
      strategy: 'ssrf_filter',
      public_url: 'https://example.com/feed.xml',
    };

    (global.fetch as any).mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(mockResult),
    });

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com', 'Test Feed', 'ssrf_filter', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toEqual(mockResult);
    expect(result.current.error).toBeNull();
    expect(global.fetch).toHaveBeenCalledWith('/auto_source/create', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: 'Bearer testtoken',
      },
      body: new URLSearchParams({
        url: 'https://example.com',
        name: 'Test Feed',
        strategy: 'ssrf_filter',
      }),
    });
  });

  it('should handle conversion error', async () => {
    (global.fetch as any).mockResolvedValueOnce({
      ok: false,
      status: 400,
      text: () => Promise.resolve('Bad Request'),
    });

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com', 'Test Feed', 'ssrf_filter', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('API call failed: 400 - Bad Request');
  });

  it('should handle network error', async () => {
    (global.fetch as any).mockRejectedValueOnce(new Error('Network error'));

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com', 'Test Feed', 'ssrf_filter', 'testtoken');
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('Network error');
  });

  it('should clear result', () => {
    const { result } = renderHook(() => useFeedConversion());

    // Set some state first
    act(() => {
      result.current.convertFeed('https://example.com', 'Test Feed', 'ssrf_filter', 'testtoken');
    });

    act(() => {
      result.current.clearResult();
    });

    expect(result.current.isConverting).toBe(false);
    expect(result.current.result).toBeNull();
    expect(result.current.error).toBeNull();
  });

  it('should set converting state during API call', () => {
    (global.fetch as any).mockImplementation(() => new Promise(() => {})); // Never resolves

    const { result } = renderHook(() => useFeedConversion());

    act(() => {
      result.current.convertFeed('https://example.com', 'Test Feed', 'ssrf_filter', 'testtoken');
    });

    expect(result.current.isConverting).toBe(true);
  });
});
