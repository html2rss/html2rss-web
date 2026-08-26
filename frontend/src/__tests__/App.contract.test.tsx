import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { server, buildFeedResponse, buildStructuredErrorResponse } from './mocks/server';
import { App } from '../components/App';
import { COPY } from '../journey/copy';

describe('App contract', () => {
  const token = 'contract-token';

  beforeEach(() => {
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    localStorage.clear();
    sessionStorage.clear();
    localStorage.setItem('html2rss_access_token', token);
  });

  it('shows feed result when the API returns structured create payload and preview feed', async () => {
    const nativeFetch = fetch;
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
      expect(screen.getByLabelText(COPY.urlLabel)).toBeInTheDocument();
    });
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();

    const urlInput = screen.getByLabelText(COPY.urlLabel) as HTMLInputElement;
    fireEvent.input(urlInput, { target: { value: 'https://example.com/articles' } });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    await waitFor(() => {
      expect(screen.getByText(COPY.feedReady)).toBeInTheDocument();
      expect(screen.getByText('Example Feed')).toBeInTheDocument();
      expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'result');
      expect(screen.getByLabelText(COPY.feedUrl)).toBeInTheDocument();
      expect(screen.getByRole('button', { name: COPY.copyFeedUrl })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: COPY.createAnother })).toBeInTheDocument();
      expect(screen.getByText(COPY.previewItemCount(1))).toBeInTheDocument();
    });
    fetchSpy.mockRestore();
  });

  it('reopens the token gate when a saved token is rejected by structured auth metadata', async () => {
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
      expect(screen.getByLabelText(COPY.urlLabel)).toBeInTheDocument();
    });

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    await screen.findByText(COPY.tokenRejected);

    expect(screen.getByRole('heading', { name: COPY.tokenTitle })).toBeInTheDocument();
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
    expect(localStorage.getItem('html2rss_access_token')).toBeNull();
    expect(sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });
});
