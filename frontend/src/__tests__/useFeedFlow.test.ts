import { describe, it, expect, beforeEach, afterEach, vi, type SpyInstance } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { useFeedFlow } from '../hooks/useFeedFlow';

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

describe('useFeedFlow', () => {
  let fetchMock: SpyInstance;
  const mockNavigate = vi.fn();
  const mockSaveToken = vi.fn();
  const mockClearToken = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    sessionStorage.clear();
    fetchMock = vi.spyOn(globalThis, 'fetch');
  });

  afterEach(() => {
    fetchMock.mockRestore();
  });

  it('manages form input field changes and draft state', async () => {
    const { result } = renderHook(() =>
      useFeedFlow({
        token: undefined,
        metadata: { instance: { feed_creation: { enabled: true, access_token_required: false } } },
        isLoading: false,
        saveToken: mockSaveToken,
        clearToken: mockClearToken,
        route: { kind: 'create' },
        navigate: mockNavigate,
      })
    );

    act(() => {
      result.current.onFeedFieldChange('url', 'https://example.com/new-articles');
    });

    expect(result.current.feedFormData.url).toBe('https://example.com/new-articles');
    expect(JSON.parse(localStorage.getItem('html2rss_feed_draft_state') || '{}').url).toBe(
      'https://example.com/new-articles'
    );
  });

  it('performs validation and converts feed on submit when no token is required', async () => {
    fetchMock
      .mockResolvedValueOnce(Response.json({ success: true, data: { feed: mockFeed } }))
      .mockResolvedValueOnce(Response.json({ items: [] }));

    const { result } = renderHook(() =>
      useFeedFlow({
        token: undefined,
        metadata: { instance: { feed_creation: { enabled: true, access_token_required: false } } },
        isLoading: false,
        saveToken: mockSaveToken,
        clearToken: mockClearToken,
        route: { kind: 'create' },
        navigate: mockNavigate,
      })
    );

    act(() => {
      result.current.onFeedFieldChange('url', 'https://example.com/new-articles');
    });

    const event = { preventDefault: vi.fn() } as any;
    await act(async () => {
      await result.current.onFeedSubmit(event);
    });

    expect(fetchMock).toHaveBeenCalled();
    expect(mockNavigate).toHaveBeenCalledWith({ kind: 'result', feedToken: 'feed-token-1' });
  });

  it('redirects to token route when token is required but missing', async () => {
    const { result } = renderHook(() =>
      useFeedFlow({
        token: undefined,
        metadata: { instance: { feed_creation: { enabled: true, access_token_required: true } } },
        isLoading: false,
        saveToken: mockSaveToken,
        clearToken: mockClearToken,
        route: { kind: 'create' },
        navigate: mockNavigate,
      })
    );

    act(() => {
      result.current.onFeedFieldChange('url', 'https://example.com/private-articles');
    });

    const event = { preventDefault: vi.fn() } as any;
    await act(async () => {
      await result.current.onFeedSubmit(event);
    });

    expect(fetchMock).not.toHaveBeenCalled();
    expect(mockNavigate).toHaveBeenCalledWith({
      kind: 'token',
      prefillUrl: 'https://example.com/private-articles',
    });
  });
});
