import { describe, it, expect, beforeEach, afterEach, vi, type SpyInstance } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/preact';
import { resetAccessTokenMemory, useSession } from '../session';
import { getPersistentStorage } from '../utils/persistentStorage';

const ACCESS_TOKEN_KEY = 'html2rss_access_token';

const mockMetadata = {
  instance: {
    feed_creation: { enabled: true, access_token_required: true },
    catalog: { enabled: true, url: '/api/v1/configs' },
  },
  api: { openapi_url: '/openapi.yaml' },
};

describe('useSession', () => {
  let fetchMock: SpyInstance;

  const emptyCatalogResponse = Response.json({
    success: true,
    data: { configs: [] },
    meta: { total: 0, catalog_version: 1 },
  });

  const mockFetchFor = (metadata: unknown, catalogResponse: Response = emptyCatalogResponse) => {
    fetchMock.mockImplementation(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('/configs')) return catalogResponse.clone();
      return Response.json({ success: true, data: metadata });
    });
  };

  beforeEach(() => {
    vi.clearAllMocks();
    getPersistentStorage().clear();
    localStorage.clear();
    sessionStorage.clear();
    resetAccessTokenMemory();
    fetchMock = vi.spyOn(globalThis, 'fetch');
  });

  afterEach(() => {
    resetAccessTokenMemory();
    getPersistentStorage().clear();
    fetchMock.mockRestore();
  });

  it('coordinates api metadata load and token loading', async () => {
    localStorage.setItem(ACCESS_TOKEN_KEY, 'session-token');
    mockFetchFor(mockMetadata);

    const { result } = renderHook(() => useSession());

    expect(result.current.isLoading).toBe(true);

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });

    expect(result.current.token).toBe('session-token');
    expect(result.current.hasToken).toBe(true);
    expect(result.current.featuredFeeds).toEqual([]);
    expect(result.current.catalogEntries).toEqual([]);
    expect(result.current.metadataError).toBeUndefined();
    expect(result.current.feedCreationEnabled).toBe(true);
  });

  it('selects starter feeds when feed creation is enabled', async () => {
    const azure = {
      id: 'microsoft.com/azure-products',
      path: '/microsoft.com/azure-products.rss',
      channel: { url: 'https://azure.example' },
      directory: { title: 'Azure product updates', summary: 'Updates' },
      parameters: { defaults: {} },
    };
    mockFetchFor(
      mockMetadata,
      Response.json({
        success: true,
        data: { configs: [azure] },
        meta: { total: 1, catalog_version: 1 },
      })
    );

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.feedCreationEnabled).toBe(true);
    expect(result.current.featuredFeeds.map((entry) => entry.id)).toEqual([
      'microsoft.com/azure-products',
    ]);
  });

  it('saves new tokens to persistent storage and does not write sessionStorage', async () => {
    mockFetchFor(mockMetadata);

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    await act(async () => {
      await result.current.saveToken('brand-new-token');
    });

    expect(result.current.token).toBe('brand-new-token');
    expect(result.current.hasToken).toBe(true);
    expect(getPersistentStorage().getItem(ACCESS_TOKEN_KEY)).toBe('brand-new-token');
    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBe('brand-new-token');
    expect(sessionStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull();
  });

  it('clears the canonical persistent token copy', async () => {
    localStorage.setItem(ACCESS_TOKEN_KEY, 'old-token');
    mockFetchFor(mockMetadata);

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    act(() => {
      result.current.clearToken();
    });

    expect(result.current.token).toBeUndefined();
    expect(result.current.hasToken).toBe(false);
    expect(getPersistentStorage().getItem(ACCESS_TOKEN_KEY)).toBeNull();
    expect(sessionStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull();
  });

  it('falls back to in-memory token when persistent storage write is unavailable', async () => {
    mockFetchFor(mockMetadata);
    localStorage.setItem.mockImplementationOnce(() => {
      throw new Error('blocked');
    });

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    await act(async () => {
      await result.current.saveToken('memory-token');
    });

    expect(result.current.token).toBe('memory-token');
    expect(result.current.hasToken).toBe(true);
    expect(sessionStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull();
  });

  it('loads from in-memory fallback when persistent storage read is unavailable', async () => {
    mockFetchFor(mockMetadata);
    localStorage.setItem.mockImplementationOnce(() => {
      throw new Error('blocked');
    });

    const seeded = renderHook(() => useSession());
    await waitFor(() => expect(seeded.result.current.isLoading).toBe(false));
    await act(async () => {
      await seeded.result.current.saveToken('memory-only');
    });
    seeded.unmount();

    localStorage.getItem.mockImplementationOnce(() => {
      throw new Error('blocked');
    });

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.token).toBe('memory-only');
    expect(result.current.hasToken).toBe(true);
    expect(sessionStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull();
  });

  it('mayCreate returns needToken when access token is required and missing', async () => {
    mockFetchFor(mockMetadata);

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.mayCreate()).toBe('needToken');
    expect(result.current.mayCreate('')).toBe('needToken');
    expect(result.current.mayCreate('provided-token')).toBe('proceed');
  });

  it('mayCreate returns disabled when feed creation is disabled', async () => {
    mockFetchFor({
      ...mockMetadata,
      instance: {
        ...mockMetadata.instance,
        feed_creation: { enabled: false, access_token_required: true },
      },
    });

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.feedCreationEnabled).toBe(false);
    expect(result.current.mayCreate('any-token')).toBe('disabled');
  });

  it('mayCreate returns proceed when token is not required', async () => {
    mockFetchFor({
      ...mockMetadata,
      instance: {
        ...mockMetadata.instance,
        feed_creation: { enabled: true, access_token_required: false },
      },
    });

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.mayCreate()).toBe('proceed');
  });

  it('defaults gate to token-required when metadata feed_creation is absent', async () => {
    mockFetchFor({
      api: mockMetadata.api,
      instance: {},
    });

    const { result } = renderHook(() => useSession());
    await waitFor(() => expect(result.current.isLoading).toBe(false));

    expect(result.current.feedCreationEnabled).toBe(true);
    expect(result.current.mayCreate()).toBe('needToken');
  });
});
