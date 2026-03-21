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

        expect(body).toEqual({ url: 'https://example.com/articles', strategy: 'faraday' });

        return HttpResponse.json(
          buildFeedResponse({
            url: body.url,
            feed_token: 'generated-token',
            public_url: '/api/v1/feeds/generated-token',
            json_public_url: '/api/v1/feeds/generated-token.json',
          }),
          { status: 201 }
        );
      })
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await result.current.convertFeed('https://example.com/articles', 'faraday', 'test-token-123');
    });

    expect(receivedAuthorization).toBe('Bearer test-token-123');
    expect(result.current.error).toBeNull();
    expect(result.current.result?.feed_token).toBe('generated-token');
    expect(result.current.result?.public_url).toBe('/api/v1/feeds/generated-token');
    expect(result.current.result?.json_public_url).toBe('/api/v1/feeds/generated-token.json');
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
      await expect(
        result.current.convertFeed('https://example.com/articles', 'faraday', 'token')
      ).rejects.toThrow('URL parameter is required');
    });

    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('URL parameter is required');
  });

  it('normalizes malformed successful responses', async () => {
    server.use(
      http.post('/api/v1/feeds', async () =>
        HttpResponse.text('not-json', {
          status: 200,
          headers: { 'content-type': 'application/json' },
        })
      )
    );

    const { result } = renderHook(() => useFeedConversion());

    await act(async () => {
      await expect(
        result.current.convertFeed('https://example.com/articles', 'faraday', 'token')
      ).rejects.toThrow('Invalid response format from feed creation API');
    });

    expect(result.current.result).toBeNull();
    expect(result.current.error).toBe('Invalid response format from feed creation API');
  });
});
