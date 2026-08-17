import { describe, it, expect, beforeEach, afterEach, vi, type SpyInstance } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/preact';
import { resetAccessTokenMemory } from '../hooks/useAccessToken';
import { useSession } from '../hooks/useSession';

const mockMetadata = {
  instance: {
    feed_creation: { enabled: true, access_token_required: true },
    featured_feeds: [{ name: 'Test Feed', url: 'https://example.com' }],
  },
  api: { openapi_url: '/openapi.yaml' },
};

describe('useSession', () => {
  let fetchMock: SpyInstance;

  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    sessionStorage.clear();
    resetAccessTokenMemory();
    fetchMock = vi.spyOn(globalThis, 'fetch');
  });

  afterEach(() => {
    resetAccessTokenMemory();
    fetchMock.mockRestore();
  });

  it('coordinates api metadata load and token loading', async () => {
    localStorage.setItem('html2rss_access_token', 'session-token');
    fetchMock.mockResolvedValueOnce(Response.json({ success: true, data: mockMetadata }));

    const { result } = renderHook(() => useSession());

    // Initially loading
    expect(result.current.isLoading).toBe(true);

    // Wait for metadata load
    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.token).toBe('session-token');
    expect(result.current.hasToken).toBe(true);
    expect(result.current.featuredFeeds).toEqual(mockMetadata.instance.featured_feeds);
    expect(result.current.metadataError).toBeUndefined();
  });

  it('saves new tokens', async () => {
    fetchMock.mockResolvedValueOnce(Response.json({ success: true, data: mockMetadata }));

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    await act(async () => {
      await result.current.saveToken('brand-new-token');
    });

    expect(result.current.token).toBe('brand-new-token');
    expect(result.current.hasToken).toBe(true);
    expect(localStorage.getItem('html2rss_access_token')).toBe('brand-new-token');
    expect(sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });

  it('clears token state', async () => {
    localStorage.setItem('html2rss_access_token', 'old-token');
    fetchMock.mockResolvedValueOnce(Response.json({ success: true, data: mockMetadata }));

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    act(() => {
      result.current.clearToken();
    });

    expect(result.current.token).toBeUndefined();
    expect(result.current.hasToken).toBe(false);
    expect(localStorage.getItem('html2rss_access_token')).toBeNull();
    expect(sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });
});
