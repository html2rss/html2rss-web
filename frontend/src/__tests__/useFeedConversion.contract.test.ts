import { describe, it, expect, vi } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { server, buildFeedResponse, buildStructuredErrorResponse } from './mocks/server';
import { useFeedConversion } from '../hooks/useFeedConversion';

describe('useFeedConversion contract', () => {
  it('sends feed creation requests with bearer auth and hydrates preview from json_public_url', async () => {
    let receivedAuthorization: string | undefined;
    const nativeFetch = globalThis.fetch;
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation((input, init) => {
      if (String(input).endsWith('/api/v1/feeds/generated-token.json')) {
        return Promise.resolve(
          new Response(JSON.stringify({ items: [{ title: 'Preview', content_text: 'Text' }] }), {
            status: 200,
            headers: { 'Content-Type': 'application/feed+json' },
          })
        );
      }

      return nativeFetch(input, init);
    });

    server.use(
      http.post('/api/v1/feeds', async ({ request }) => {
        const body = (await request.json()) as { url: string };
        receivedAuthorization = request.headers.get('authorization');

        expect(body).toEqual({ url: 'https://example.com/articles' });

        return HttpResponse.json(
          buildFeedResponse({
            url: body.url,
            feed_token: 'generated-token',
            public_url: '/api/v1/feeds/generated-token',
            json_public_url: '/api/v1/feeds/generated-token.json',
          }),
          { status: 201 }
        );
      }),
      http.get('http://localhost:3000/api/v1/feeds/generated-token.json', () =>
        HttpResponse.json({ items: [{ title: 'Preview', content_text: 'Text' }] })
      ),
      http.get('http://localhost/api/v1/feeds/generated-token.json', () =>
        HttpResponse.json({ items: [{ title: 'Preview', content_text: 'Text' }] })
      ),
      http.get('/api/v1/feeds/generated-token.json', () =>
        HttpResponse.json({ items: [{ title: 'Preview', content_text: 'Text' }] })
      )
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'test-token-123');
    });

    expect(receivedAuthorization).toBe('Bearer test-token-123');
    expect(result.current.error).toBeUndefined();
    expect(result.current.result?.feed.feed_token).toBe('generated-token');
    await waitFor(() => expect(result.current.result?.workflowState).toBe('preview_ready'));
    fetchSpy.mockRestore();
  });

  it('propagates structured auth failures without parsing the message text', async () => {
    server.use(
      http.post('/api/v1/feeds', async () =>
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

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await expect(result.current.convertFeed('https://example.com/articles', 'token')).rejects.toMatchObject(
        {
          message: 'Authentication required',
        }
      );
    });

    expect(result.current.result).toBeUndefined();
    expect(result.current.error).toMatchObject({
      kind: 'auth',
      code: 'UNAUTHORIZED',
      nextAction: 'enter_token',
      retryAction: 'none',
      retryable: false,
      message: 'Authentication required',
    });
  });

  it('treats extraction-empty failures as corrective input errors without strategy metadata', async () => {
    server.use(
      http.post('/api/v1/feeds', async () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            code: 'NO_FEED_ITEMS_EXTRACTED',
            message: 'Could not extract feed items. Try a more specific listing URL or explicit selectors.',
            kind: 'input',
            retryable: false,
            next_action: 'correct_input',
            retry_action: 'none',
          }),
          { status: 422 }
        )
      )
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await expect(result.current.convertFeed('https://example.com/articles', 'token')).rejects.toMatchObject(
        {
          kind: 'input',
          code: 'NO_FEED_ITEMS_EXTRACTED',
          nextAction: 'correct_input',
          retryAction: 'none',
          retryable: false,
          message: 'Could not extract feed items. Try a more specific listing URL or explicit selectors.',
        }
      );
    });
  });

  it('marks preview failure from the feed json response without status polling', async () => {
    const nativeFetch = globalThis.fetch;
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation((input, init) => {
      if (String(input).endsWith('/api/v1/feeds/generated-token.json')) {
        return Promise.resolve(new Response('No feed items', { status: 422 }));
      }

      return nativeFetch(input, init);
    });

    server.use(
      http.post('/api/v1/feeds', async ({ request }) => {
        const body = (await request.json()) as { url: string };

        return HttpResponse.json(
          buildFeedResponse({
            url: body.url,
            feed_token: 'generated-token',
            public_url: '/api/v1/feeds/generated-token',
            json_public_url: '/api/v1/feeds/generated-token.json',
          }),
          { status: 201 }
        );
      }),
      http.get('http://localhost:3000/api/v1/feeds/generated-token.json', () =>
        HttpResponse.text('No feed items', { status: 422 })
      ),
      http.get('http://localhost/api/v1/feeds/generated-token.json', () =>
        HttpResponse.text('No feed items', { status: 422 })
      ),
      http.get('/api/v1/feeds/generated-token.json', () =>
        HttpResponse.text('No feed items', { status: 422 })
      )
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'token');
    });

    await waitFor(() => {
      expect(result.current.result?.workflowState).toBe('preview_failed');
      expect(result.current.result?.warnings[0]?.code).toBe('PREVIEW_HTTP_422');
    });
    fetchSpy.mockRestore();
  });

  it('rejects camelCase-only create payloads to enforce canonical snake_case contract', async () => {
    server.use(
      http.post('/api/v1/feeds', async () =>
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

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await expect(result.current.convertFeed('https://example.com/articles', 'token')).rejects.toMatchObject(
        {
          kind: 'server',
          code: 'INVALID_RESPONSE',
        }
      );
    });
  });
});
