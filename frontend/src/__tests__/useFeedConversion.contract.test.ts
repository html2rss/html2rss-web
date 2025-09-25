import { describe, it, expect } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { server, buildFeedResponse } from './mocks/server';
import { useFeedConversion } from '../hooks/useFeedConversion';

describe('useFeedConversion contract', () => {
  it('sends feed creation request with bearer token', async () => {
    let receivedAuthorization: string | null = null;

    server.use(
      http.post('/api/v1/feeds', async ({ request }) => {
        const body = (await request.json()) as { url: string; strategy: string };
        receivedAuthorization = request.headers.get('authorization');

        expect(body).toEqual({ url: 'https://example.com/articles', strategy: 'ssrf_filter' });

        return HttpResponse.json(
          buildFeedResponse({
            url: body.url,
            public_url: '/api/v1/feeds/generated-token',
          })
        );
      })
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'ssrf_filter', 'test-token-123');
    });

    expect(receivedAuthorization).toBe('Bearer test-token-123');
    expect(result.current.error).toBeNull();
    expect(result.current.result?.public_url).toBe('/api/v1/feeds/generated-token');
  });

  it('propagates API validation errors', async () => {
    server.use(
      http.post('/api/v1/feeds', async () =>
        HttpResponse.json(
          { success: false, error: { message: 'URL parameter is required' } },
          { status: 400 }
        )
      )
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'ssrf_filter', 'token');
    });

    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('URL parameter is required');
  });
});
