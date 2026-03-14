import { describe, it, expect } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
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
      http.get('/api/v1/feeds/generated-token', ({ request }) => {
        expect(request.headers.get('accept')).toBe('application/feed+json');

        return HttpResponse.json(
          {
            items: [{ title: 'Contract Item' }],
          },
          {
            headers: { 'content-type': 'application/feed+json' },
          }
        );
      })
    );

    render(<App />);

    await screen.findByLabelText('Page URL');

    const urlInput = screen.getByLabelText('Page URL') as HTMLInputElement;
    fireEvent.input(urlInput, { target: { value: 'https://example.com/articles' } });

    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await waitFor(() => {
      expect(screen.getByText('Example Feed')).toBeInTheDocument();
      expect(screen.getByLabelText('Feed URL')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Copy feed URL' })).toBeInTheDocument();
      expect(screen.getByRole('link', { name: 'Open feed' })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: 'Create another feed' })).toBeInTheDocument();
      expect(screen.getByText('Feed preview')).toBeInTheDocument();
      expect(screen.getByText('Contract Item')).toBeInTheDocument();
    });
  });
});
