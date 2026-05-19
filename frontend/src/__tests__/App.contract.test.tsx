import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { server, buildFeedResponse, buildStructuredErrorResponse } from './mocks/server';
import { App } from '../components/App';

describe('App contract', () => {
  const token = 'contract-token';

  beforeEach(() => {
    globalThis.history.replaceState({}, '', 'http://localhost:3000/#/create');
    globalThis.localStorage.clear();
    globalThis.sessionStorage.clear();
    globalThis.sessionStorage.setItem('html2rss_access_token', token);
  });

  it('shows feed result when the API returns structured create payload and preview feed', async () => {
    const nativeFetch = globalThis.fetch;
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation((input, init) => {
      if (String(input).endsWith('/api/v1/feeds/generated-token.json')) {
        expect((init?.headers as Record<string, string> | undefined)?.Accept).toBe('application/feed+json');
        return Promise.resolve(
          Response.json(
            {
              items: [
                {
                  title: 'Contract Item',
                  content_text: 'Contract preview excerpt.',
                  url: 'https://example.com/contract-item',
                  date_published: '2024-01-01T00:00:00Z',
                },
              ],
            },
            { status: 200, headers: { 'Content-Type': 'application/feed+json' } }
          )
        );
      }

      return nativeFetch(input, init);
    });

    server.use(
      http.post('/api/v1/feeds', async ({ request }) => {
        const body = (await request.json()) as { url: string };

        expect(body).toEqual({ url: 'https://example.com/articles' });
        expect(request.headers.get('authorization')).toBe(`Bearer ${token}`);

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
      http.get('http://localhost:3000/api/v1/feeds/generated-token.json', ({ request }) => {
        expect(request.headers.get('accept')).toBe('application/feed+json');

        return HttpResponse.json(
          {
            items: [
              {
                title: 'Contract Item',
                content_text: 'Contract preview excerpt.',
                url: 'https://example.com/contract-item',
                date_published: '2024-01-01T00:00:00Z',
              },
            ],
          },
          {
            headers: { 'content-type': 'application/feed+json' },
          }
        );
      }),
      http.get('/api/v1/feeds/generated-token.json', ({ request }) => {
        expect(request.headers.get('accept')).toBe('application/feed+json');

        return HttpResponse.json({
          items: [
            {
              title: 'Contract Item',
              content_text: 'Contract preview excerpt.',
              url: 'https://example.com/contract-item',
              date_published: '2024-01-01T00:00:00Z',
            },
          ],
        });
      })
    );

    render(<App />);

    await waitFor(() => {
      expect(screen.getByLabelText('Page URL')).toBeInTheDocument();
    });
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();

    const urlInput = screen.getByLabelText('Page URL') as HTMLInputElement;
    fireEvent.input(urlInput, { target: { value: 'https://example.com/articles' } });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await waitFor(() => {
      expect(screen.getByText('Feed ready')).toBeInTheDocument();
      expect(screen.getByText('Example Feed')).toBeInTheDocument();
      expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'result');
      expect(screen.getByLabelText('Feed URL')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Copy feed URL' })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Create another feed' })).toBeInTheDocument();
      expect(screen.getByText('Latest items from this feed')).toBeInTheDocument();
    });
    fetchSpy.mockRestore();
  });

  it('reopens token recovery when a saved token is rejected by structured auth metadata', async () => {
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

    render(<App />);

    await waitFor(() => {
      expect(screen.getByLabelText('Page URL')).toBeInTheDocument();
    });

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await screen.findByText('Access token was rejected. Paste a valid token to continue.');

    expect(screen.getByText('Enter access token')).toBeInTheDocument();
    expect(screen.queryByText("Couldn't create feed yet")).not.toBeInTheDocument();
    expect(globalThis.sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });
});
