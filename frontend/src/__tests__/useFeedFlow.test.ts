import { describe, it, expect, beforeEach, afterEach, vi, type SpyInstance } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/preact';
import { useFeedFlow, type FeedFlowDependencies } from '../feed';

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

async function stubFeedCreationFailure(message = 'Upstream failed') {
  const { server, buildStructuredErrorResponse } = await import('./mocks/server');
  const { http, HttpResponse } = await import('msw');
  server.use(
    http.post('/api/v1/feeds', () =>
      HttpResponse.json(
        buildStructuredErrorResponse({
          message,
          kind: 'server',
          retryable: true,
          next_action: 'retry',
          retry_action: 'primary',
        }),
        { status: 500 }
      )
    )
  );
}

describe('useFeedFlow', () => {
  let fetchMock: SpyInstance;
  const mockNavigate = vi.fn();
  const mockSaveToken = vi.fn();
  const mockClearToken = vi.fn();

  const feedFlowProperties = (overrides: Partial<FeedFlowDependencies> = {}): FeedFlowDependencies => ({
    token: undefined,
    isLoading: false,
    feedCreationEnabled: true,
    mayCreate: () => 'proceed',
    saveToken: mockSaveToken,
    clearToken: mockClearToken,
    route: { kind: 'create' },
    navigate: mockNavigate,
    createEntryKey: 0,
    ...overrides,
  });

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
    const { result } = renderHook(() => useFeedFlow(feedFlowProperties()));

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

    const { result } = renderHook(() => useFeedFlow(feedFlowProperties()));

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
      useFeedFlow(
        feedFlowProperties({
          mayCreate: () => 'needToken',
        })
      )
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

  it('navigates to token and projects token_prompt on auth conversion failure', async () => {
    const { server, buildStructuredErrorResponse } = await import('./mocks/server');
    const { http, HttpResponse } = await import('msw');
    server.use(
      http.post('/api/v1/feeds', () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            message: 'Access denied',
            kind: 'auth',
            code: 'UNAUTHORIZED',
            retryable: false,
            next_action: 'enter_token',
            retry_action: 'none',
          }),
          { status: 401 }
        )
      )
    );

    const { result, rerender } = renderHook(
      ({ route }) =>
        useFeedFlow(feedFlowProperties({ route, mayCreate: () => 'proceed', token: 'bad-token' })),
      { initialProps: { route: { kind: 'create' as const } } }
    );

    act(() => {
      result.current.onFeedFieldChange('url', 'https://example.com/private-articles');
    });

    await act(async () => {
      await result.current.onFeedSubmit({ preventDefault: vi.fn() } as any);
    });

    expect(mockNavigate).toHaveBeenCalledWith({
      kind: 'token',
      prefillUrl: 'https://example.com/private-articles',
    });
    expect(mockClearToken).toHaveBeenCalled();

    rerender({ route: { kind: 'token', prefillUrl: 'https://example.com/private-articles' } });

    expect(result.current.viewModel.kind).toBe('token_prompt');
    expect(result.current.tokenError).toBeTruthy();
  });

  it('returns non-auth conversion failures from token onto create', async () => {
    await stubFeedCreationFailure();

    const { result } = renderHook(() =>
      useFeedFlow(
        feedFlowProperties({
          mayCreate: () => 'proceed',
          route: { kind: 'token', prefillUrl: 'https://example.com/private-articles' },
        })
      )
    );

    act(() => {
      result.current.onFeedFieldChange('url', 'https://example.com/private-articles');
      result.current.setTokenDraft('token-123');
    });

    mockSaveToken.mockResolvedValueOnce(undefined);

    await act(async () => {
      await result.current.onSaveToken();
    });

    expect(mockNavigate).toHaveBeenCalledWith({
      kind: 'create',
      prefillUrl: 'https://example.com/private-articles',
    });
    expect(result.current.tokenError).toBe('');
    expect(result.current.feedFieldErrors.form).toBe('Upstream failed');
  });

  it('recovers unmatched result routes onto remounted create without prefillUrl', async () => {
    const { result, rerender } = renderHook(
      ({ route, createEntryKey }) => useFeedFlow(feedFlowProperties({ route, createEntryKey })),
      { initialProps: { route: { kind: 'result' as const, feedToken: 'missing-token' }, createEntryKey: 0 } }
    );

    await waitFor(() => {
      expect(mockNavigate).toHaveBeenCalledWith({ kind: 'create' }, { replace: true });
    });

    for (const [route] of mockNavigate.mock.calls) {
      if (route.kind !== 'create') continue;
      expect(route).toEqual({ kind: 'create' });
      expect(route).not.toHaveProperty('prefillUrl');
    }

    rerender({ route: { kind: 'create' }, createEntryKey: 0 });

    expect(result.current.focusCreateComposerKey).toBeGreaterThan(0);
    expect(result.current.conversionError).toBeUndefined();
  });

  it('remounts create on a later create-entry visit and clears conversion chrome', async () => {
    await stubFeedCreationFailure();

    const { result, rerender } = renderHook(
      ({ createEntryKey }) => useFeedFlow(feedFlowProperties({ createEntryKey })),
      { initialProps: { createEntryKey: 0 } }
    );

    act(() => {
      result.current.onFeedFieldChange('url', 'https://example.com/articles');
    });

    await act(async () => {
      await result.current.onFeedSubmit({ preventDefault: vi.fn() } as any);
    });

    expect(result.current.conversionError).toMatchObject({ message: 'Upstream failed' });
    expect(result.current.feedFieldErrors.form).toBe('Upstream failed');
    const previousFocusKey = result.current.focusCreateComposerKey;
    const fetchCallsAfterSubmit = fetchMock.mock.calls.length;

    rerender({ createEntryKey: 1 });

    expect(result.current.conversionError).toBeUndefined();
    expect(result.current.feedFieldErrors.form).toBe('');
    expect(result.current.tokenError).toBe('');
    expect(result.current.tokenDraft).toBe('');
    expect(result.current.focusCreateComposerKey).toBeGreaterThan(previousFocusKey);
    expect(fetchMock).toHaveBeenCalledTimes(fetchCallsAfterSubmit);
  });

  it('clears token draft on cancel and create remount', async () => {
    const { result, rerender } = renderHook(
      ({ createEntryKey, route }) => useFeedFlow(feedFlowProperties({ createEntryKey, route })),
      { initialProps: { createEntryKey: 0, route: { kind: 'token' as const, prefillUrl: 'https://example.com' } } }
    );

    act(() => {
      result.current.setTokenDraft('secret-draft');
    });
    expect(result.current.tokenDraft).toBe('secret-draft');

    act(() => {
      result.current.onCancelTokenPrompt();
    });
    expect(result.current.tokenDraft).toBe('');
    expect(mockNavigate).toHaveBeenCalledWith({ kind: 'create', prefillUrl: expect.any(String) });

    act(() => {
      result.current.setTokenDraft('another-secret');
    });
    rerender({ createEntryKey: 1, route: { kind: 'create' } });
    expect(result.current.tokenDraft).toBe('');
  });
});
