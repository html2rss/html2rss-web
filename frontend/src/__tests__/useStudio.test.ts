import { describe, it, expect, afterEach, vi } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { server } from './mocks/server';
import {
  buildStructuredErrorResponse,
  studioPreviewSuccessBody,
  suggestSuccessBody,
  validateSuccessBody,
  validateYamlForSelectors,
} from './mocks/apiFixtures';
import {
  STUDIO_PREVIEW_SETTLE_MS,
  STUDIO_VALIDATE_DELAY_MS,
  canSaveStudio,
  useStudio,
} from '../studio/useStudio';

const pageUrl = 'https://example.com/articles';
const token = 'studio-token';

function suggestItems(selector: string, sample = 'Sample headline') {
  return suggestSuccessBody({ items: [{ selector, sample }] });
}

async function advance(ms: number) {
  await act(async () => {
    await vi.advanceTimersByTimeAsync(ms);
  });
}

function useStudioHandlers() {
  let validateCount = 0;
  let previewCount = 0;
  let lastValidateAuth: string | undefined;
  let lastValidateSelectors: unknown;

  server.use(
    http.post('/api/v1/feeds/suggest_selectors', () => HttpResponse.json(suggestItems('article'))),
    http.post('/api/v1/feeds/validate', async ({ request }) => {
      validateCount += 1;
      lastValidateAuth = request.headers.get('authorization') ?? undefined;
      const body = (await request.json()) as { selectors?: unknown; url?: string };
      const selectors = body.selectors ?? { items: { selector: 'a[href]' } };
      lastValidateSelectors = selectors;
      return HttpResponse.json(validateSuccessBody(selectors, validateYamlForSelectors(selectors, body.url)));
    }),
    http.post('/api/v1/feeds/preview', () => {
      previewCount += 1;
      return HttpResponse.json(
        studioPreviewSuccessBody([
          { title: 'Sample', url: 'https://example.com/sample', published_at: '2024-01-02' },
        ])
      );
    })
  );

  return {
    validateCount: () => validateCount,
    previewCount: () => previewCount,
    lastValidateAuth: () => lastValidateAuth,
    lastValidateSelectors: () => lastValidateSelectors,
  };
}

describe('useStudio', () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it('waits for validate delay, sends bearer token, and unwraps a valid report', async () => {
    vi.useFakeTimers();
    const handlers = useStudioHandlers();
    const { result } = renderHook(() => useStudio({ url: pageUrl, token }));

    expect(handlers.validateCount()).toBe(0);
    await act(async () => {
      await vi.advanceTimersByTimeAsync(0);
      await Promise.resolve();
    });
    expect(handlers.validateCount()).toBe(0);

    await advance(STUDIO_VALIDATE_DELAY_MS - 1);
    expect(handlers.validateCount()).toBe(0);
    await advance(1);
    expect(handlers.validateCount()).toBe(1);
    expect(handlers.lastValidateAuth()).toBe(`Bearer ${token}`);
    expect(result.current.state).toMatchObject({ phase: 'editing', validated: true });
  });

  it('previews after settle, sends enhance boolean, and clears hold on enhance flip', async () => {
    vi.useFakeTimers();
    const handlers = useStudioHandlers();
    const { result } = renderHook(() =>
      useStudio({ url: pageUrl, token, validateDelayMs: STUDIO_VALIDATE_DELAY_MS })
    );

    await advance(STUDIO_VALIDATE_DELAY_MS);
    expect(handlers.lastValidateSelectors()).toEqual({
      items: { selector: 'a[href]', enhance: false },
    });
    expect(handlers.previewCount()).toBe(0);

    act(() => {
      result.current.setItemsSelector('article');
    });
    await advance(STUDIO_VALIDATE_DELAY_MS);
    await advance(STUDIO_PREVIEW_SETTLE_MS - 1);
    expect(handlers.previewCount()).toBe(0);
    await advance(1);
    expect(handlers.previewCount()).toBe(1);
    expect(result.current.state.live).toMatchObject({
      status: 'ready',
      sample: { items: [{ title: 'Sample' }] },
    });

    act(() => {
      result.current.setEnhance(true);
    });
    expect(result.current.state.draft.enhance).toBe(true);
    expect(result.current.state.live.status).toBe('idle');
    await advance(STUDIO_VALIDATE_DELAY_MS);
    expect(handlers.lastValidateSelectors()).toEqual({
      items: { selector: 'article', enhance: true },
    });
  });

  it('ignores a stale save after a newer save starts', async () => {
    vi.useFakeTimers();
    useStudioHandlers();
    const { result } = renderHook(() => useStudio({ url: pageUrl, token, validateDelayMs: 0 }));
    await advance(0);

    const stale = Promise.withResolvers<void>();
    const current = Promise.withResolvers<void>();
    act(() => {
      void result.current.save(() => stale.promise);
    });
    act(() => {
      void result.current.save(() => current.promise);
    });
    expect(result.current.state.phase).toBe('saving');

    await act(async () => {
      stale.resolve();
      await stale.promise;
    });
    expect(result.current.state.phase).toBe('saving');

    await act(async () => {
      current.resolve();
      await current.promise;
    });
    expect(result.current.state).toMatchObject({ phase: 'editing', validated: true });
    expect(canSaveStudio(result.current.state)).toBe(true);
  });

  it('fails closed when validate is unauthorized', async () => {
    server.use(
      http.post('/api/v1/feeds/suggest_selectors', () => HttpResponse.json(suggestItems('article'))),
      http.post('/api/v1/feeds/validate', () =>
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

    const { result } = renderHook(() => useStudio({ url: pageUrl, token, validateDelayMs: 0 }));
    await waitFor(() =>
      expect(result.current.state).toMatchObject({
        phase: 'failed',
        message: 'Authentication required',
      })
    );
  });

  it('distinguishes loading, empty, and ready suggestion outcomes', async () => {
    const pending = Promise.withResolvers<Response>();
    useStudioHandlers();
    server.use(http.post('/api/v1/feeds/suggest_selectors', () => pending.promise));

    const { result } = renderHook(() => useStudio({ url: pageUrl, token }));
    expect(result.current.suggestion).toEqual({ status: 'loading' });

    pending.resolve(HttpResponse.json(suggestItems('article')));
    await waitFor(() => expect(result.current.suggestion.status).toBe('ready'));

    server.use(http.post('/api/v1/feeds/suggest_selectors', () => HttpResponse.json(suggestSuccessBody({}))));
    act(() => result.current.retrySuggestion());
    await waitFor(() => expect(result.current.suggestion).toEqual({ status: 'empty' }));
  });

  it('retries suggestion decisions and aborts stale in-flight suggests', async () => {
    useStudioHandlers();
    let attempts = 0;
    let firstSignal: AbortSignal | undefined;
    const stale = Promise.withResolvers<Response>();
    server.use(
      http.post('/api/v1/feeds/suggest_selectors', ({ request }) => {
        attempts += 1;
        if (attempts === 1) {
          return HttpResponse.json(
            buildStructuredErrorResponse({
              code: 'RATE_LIMITED',
              message: 'Wait before trying selector choices again',
              kind: 'server',
              retryable: true,
              next_action: 'wait',
              retry_action: 'primary',
            }),
            { status: 429 }
          );
        }
        if (attempts === 2) {
          firstSignal = request.signal;
          return stale.promise;
        }
        return HttpResponse.json(suggestItems('section.current'));
      })
    );

    const { result } = renderHook(() => useStudio({ url: pageUrl, token }));
    await waitFor(() =>
      expect(result.current.suggestion).toEqual({
        status: 'failed',
        message: 'Wait before trying selector choices again',
      })
    );

    act(() => result.current.retrySuggestion());
    expect(result.current.suggestion).toEqual({ status: 'loading' });
    await waitFor(() => expect(attempts).toBe(2));

    act(() => result.current.retrySuggestion());
    await waitFor(() => expect(firstSignal?.aborted).toBe(true));
    await waitFor(() => expect(result.current.suggestion.status).toBe('ready'));

    stale.resolve(HttpResponse.json(suggestItems('article.stale')));
    await act(async () => {
      await Promise.resolve();
    });
    expect(result.current.suggestion).toMatchObject({
      status: 'ready',
      candidates: { items: [{ selector: 'section.current' }] },
    });
    expect(attempts).toBe(3);
  });
});
