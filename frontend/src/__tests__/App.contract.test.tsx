import { describe, it, expect } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { within } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { server, buildFeedResponse } from './mocks/server';
import { App } from '../components/App';

describe('App contract', () => {
  const token = 'contract-token';

  const authenticate = () => {
    window.sessionStorage.setItem('html2rss_access_token', token);
  };

  it('shows feed result when API responds with success', async () => {
    authenticate();

    server.use(
      http.post('/api/v1/feeds', async ({ request }) => {
        const body = (await request.json()) as { url: string; strategy: string };

        expect(body).toEqual({ url: 'https://example.com/articles', strategy: 'ssrf_filter' });
        expect(request.headers.get('authorization')).toBe(`Bearer ${token}`);

        return HttpResponse.json(
          buildFeedResponse({
            url: body.url,
            feed_token: 'generated-token',
            public_url: '/api/v1/feeds/generated-token',
          })
        );
      }),
      http.get('/api/v1/feeds/generated-token', () =>
        HttpResponse.text(
          `<?xml version="1.0"?><rss><channel><title>Contract Feed</title><item><title>Contract Item</title></item></channel></rss>`
        )
      )
    );

    render(<App />);

    await screen.findByText('Generate a feed from a web page');

    const urlInput = screen.getByLabelText('Source URL') as HTMLInputElement;
    fireEvent.input(urlInput, { target: { value: 'https://example.com/articles' } });

    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await waitFor(() => {
      const resultRegion = document.getElementById('feed-result');
      expect(resultRegion).not.toBeNull();
      const resultQueries = within(resultRegion!);

      expect(screen.getByText('Feed ready')).toBeInTheDocument();
      expect(screen.getByText('Example Feed')).toBeInTheDocument();
      expect(resultQueries.getByRole('button', { name: 'Copy feed URL' })).toBeInTheDocument();
      expect(resultQueries.getByRole('link', { name: 'Open feed' })).toBeInTheDocument();
    });
  });
});
