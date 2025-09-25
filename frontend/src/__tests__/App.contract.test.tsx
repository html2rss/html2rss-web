import { describe, it, expect } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { server, buildFeedResponse } from './mocks/server';
import { App } from '../components/App';

describe('App contract', () => {
  const username = 'contract-user';
  const token = 'contract-token';

  const authenticate = () => {
    window.localStorage.setItem('html2rss_username', username);
    window.localStorage.setItem('html2rss_token', token);
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
            public_url: '/api/v1/feeds/generated-token',
          })
        );
      })
    );

    render(<App />);

    await screen.findByText(`Welcome, ${username}!`);

    const urlInput = screen.getByLabelText('Website URL') as HTMLInputElement;
    fireEvent.input(urlInput, { target: { value: 'https://example.com/articles' } });

    fireEvent.click(screen.getByRole('button', { name: 'Convert' }));

    await waitFor(() => {
      expect(screen.getByText('Feed Generated Successfully!')).toBeInTheDocument();
      expect(screen.getByText('Your RSS feed is ready to use')).toBeInTheDocument();
    });
  });
});
