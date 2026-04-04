import { describe, it, expect } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { server, buildFeedResponse } from './mocks/server';
import { App } from '../components/App';

describe('App contract', () => {
  const token = 'contract-token';

  const authenticate = () => {
    globalThis.localStorage.setItem('html2rss_access_token', token);
  };

  it('shows feed result when API responds with success', async () => {
    authenticate();

    server.use(
      http.post('/api/v1/feeds', async ({ request }) => {
        const body = (await request.json()) as { url: string; strategy: string };

        expect(body).toEqual({ url: 'https://example.com/articles', strategy: 'faraday' });
        expect(request.headers.get('authorization')).toBe(`Bearer ${token}`);

        return HttpResponse.json(
          buildFeedResponse({
            url: body.url,
            feed_token: 'generated-token',
            public_url: '/api/v1/feeds/generated-token',
            json_public_url: '/api/v1/feeds/generated-token.json',
          })
        );
      }),
      http.get('/api/v1/feeds/generated-token.json', ({ request }) => {
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
      })
    );

    render(<App />);

    await screen.findByLabelText('Page URL');
    await waitFor(() => {
      expect(screen.getByRole('combobox')).toHaveValue('faraday');
    });

    const urlInput = screen.getByLabelText('Page URL') as HTMLInputElement;
    fireEvent.input(urlInput, { target: { value: 'https://example.com/articles' } });

    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await waitFor(() => {
      expect(screen.getByText('Feed ready')).toBeInTheDocument();
      expect(screen.getByText('Example Feed')).toBeInTheDocument();
      expect(screen.getByLabelText('Feed URL')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Copy feed URL' })).toBeInTheDocument();
      expect(screen.getByRole('link', { name: 'Open feed' })).toBeInTheDocument();
      expect(screen.getByRole('link', { name: 'Open JSON Feed' })).toHaveAttribute(
        'href',
        'http://localhost:3000/api/v1/feeds/generated-token.json'
      );
      expect(screen.getByRole('button', { name: 'Create another feed' })).toBeInTheDocument();
      expect(screen.getByText('Preview')).toBeInTheDocument();
      expect(screen.getByText('Latest items from this feed')).toBeInTheDocument();
      expect(screen.getByText('Contract Item')).toBeInTheDocument();
    });
  });

  it('loads instance metadata from /api/v1 without trailing slash', async () => {
    let slashlessMetadataRequests = 0;
    let trailingSlashMetadataRequests = 0;

    server.use(
      http.get('/api/v1', () => {
        slashlessMetadataRequests += 1;

        return HttpResponse.json({
          success: true,
          data: {
            api: {
              name: 'html2rss-web API',
              description: 'RESTful API for converting websites to RSS feeds',
              openapi_url: 'http://example.test/openapi.yaml',
            },
            instance: {
              feed_creation: {
                enabled: true,
                access_token_required: true,
              },
              featured_feeds: [],
            },
          },
        });
      }),
      http.get('/api/v1/', () => {
        trailingSlashMetadataRequests += 1;

        return HttpResponse.text('', { status: 404 });
      })
    );

    render(<App />);

    await screen.findByLabelText('Page URL');

    expect(screen.getByRole('button', { name: 'Generate feed URL' })).toBeInTheDocument();
    expect(screen.queryByText('Instance metadata unavailable')).not.toBeInTheDocument();
    expect(slashlessMetadataRequests).toBeGreaterThanOrEqual(1);
    expect(trailingSlashMetadataRequests).toBe(0);
  });

  it('shows the metadata unavailable notice when /api/v1 responds with non-JSON content', async () => {
    server.use(
      http.get('/api/v1', () => HttpResponse.text('not-json', { status: 502 })),
      http.get('/api/v1/', () => HttpResponse.text('', { status: 404 }))
    );

    render(<App />);

    await screen.findByText('Instance metadata unavailable');

    expect(screen.getByText('Invalid response format from API metadata')).toBeInTheDocument();
  });

  it('reopens token recovery when a saved token is rejected by /api/v1/feeds', async () => {
    authenticate();

    server.use(
      http.post('/api/v1/feeds', async () =>
        HttpResponse.json({ success: false, error: { message: 'Unauthorized' } }, { status: 401 })
      )
    );

    render(<App />);

    await screen.findByLabelText('Page URL');
    await waitFor(() => {
      expect(screen.getByRole('combobox')).toHaveValue('faraday');
    });

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await screen.findByText('Access token was rejected. Paste a valid token to continue.');

    expect(screen.getByText('Enter access token')).toBeInTheDocument();
    expect(screen.queryByText('Could not create feed link')).not.toBeInTheDocument();
    expect(globalThis.localStorage.getItem('html2rss_access_token')).toBeNull();
  });
});
