import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { h } from 'preact';
import { App } from '../components/App';

vi.mock('../hooks/useAccessToken', () => ({
  useAccessToken: vi.fn(),
}));

vi.mock('../hooks/useFeedConversion', () => ({
  useFeedConversion: vi.fn(),
}));

vi.mock('../hooks/useApiMetadata', () => ({
  useApiMetadata: vi.fn(),
}));

vi.mock('../hooks/useStrategies', () => ({
  useStrategies: vi.fn(),
}));

import { useAccessToken } from '../hooks/useAccessToken';
import { useApiMetadata } from '../hooks/useApiMetadata';
import { useFeedConversion } from '../hooks/useFeedConversion';
import { useStrategies } from '../hooks/useStrategies';

const mockUseAccessToken = useAccessToken as any;
const mockUseApiMetadata = useApiMetadata as any;
const mockUseFeedConversion = useFeedConversion as any;
const mockUseStrategies = useStrategies as any;

describe('App', () => {
  const mockSaveToken = vi.fn();
  const mockClearToken = vi.fn();
  const mockConvertFeed = vi.fn();
  const mockClearConversionError = vi.fn();
  const mockClearResult = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    window.history.replaceState({}, '', 'http://localhost:3000/');

    mockUseAccessToken.mockReturnValue({
      token: null,
      hasToken: false,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: null,
    });

    mockUseApiMetadata.mockReturnValue({
      metadata: {
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
      isLoading: false,
      error: null,
    });

    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: null,
      error: null,
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
    });

    mockUseStrategies.mockReturnValue({
      strategies: [
        { id: 'faraday', name: 'faraday', display_name: 'Default' },
        { id: 'browserless', name: 'browserless', display_name: 'JavaScript pages (recommended)' },
      ],
      isLoading: false,
      error: null,
    });
  });

  it('renders the radical-simple create flow', () => {
    render(<App />);

    expect(screen.getByLabelText('html2rss')).toBeInTheDocument();
    expect(screen.getByLabelText('Page URL')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'More' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Bookmarklet' })).not.toBeInTheDocument();
  });

  it('autofocuses the source url field', async () => {
    render(<App />);

    await waitFor(() => {
      expect(document.activeElement).toBe(screen.getByLabelText('Page URL'));
    });
  });

  it('prefers browserless as the default strategy when available', () => {
    render(<App />);

    return waitFor(() => {
      expect(screen.getByRole('combobox')).toHaveValue('browserless');
    });
  });

  it('falls back to the first available strategy when browserless is unavailable', () => {
    mockUseStrategies.mockReturnValue({
      strategies: [{ id: 'faraday', name: 'faraday', display_name: 'Default' }],
      isLoading: false,
      error: null,
    });

    render(<App />);

    return waitFor(() => {
      expect(screen.getByRole('combobox')).toHaveValue('faraday');
    });
  });

  it('auto-submits a prefilled url using the resolved default strategy', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: null,
    });
    window.history.replaceState({}, '', 'http://localhost:3000/?url=https%3A%2F%2Fexample.com%2Farticles');

    render(<App />);

    await waitFor(() => {
      expect(mockConvertFeed).toHaveBeenCalledWith(
        'https://example.com/articles',
        'browserless',
        'saved-token'
      );
    });
  });

  it('shows inline token prompt when submitting without a token', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    expect(screen.getByText('Add access token')).toBeInTheDocument();
    expect(screen.getByLabelText('Page URL')).toBeDisabled();
    expect(screen.getByRole('combobox')).toBeDisabled();
    expect(screen.queryByRole('button', { name: 'More' })).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Set up your own instance with Docker.' })).toBeInTheDocument();
    expect(screen.getByText('This instance needs an access token.')).toBeInTheDocument();
    expect(screen.queryByText('Paste an access token to keep going.')).not.toBeInTheDocument();
    await waitFor(() => {
      expect(document.activeElement).toBe(document.getElementById('access-token'));
    });
    expect(mockConvertFeed).not.toHaveBeenCalled();
  });

  it('promotes included feeds when feed creation is disabled', () => {
    mockUseApiMetadata.mockReturnValue({
      metadata: {
        api: {
          name: 'html2rss-web API',
          description: 'RESTful API for converting websites to RSS feeds',
          openapi_url: 'http://example.test/openapi.yaml',
        },
        instance: {
          feed_creation: {
            enabled: false,
            access_token_required: false,
          },
          featured_feeds: [
            {
              path: '/microsoft.com/azure-products.rss',
              title: 'Azure product updates',
              description: 'Follow Microsoft Azure product announcements from your own instance.',
            },
          ],
        },
      },
      isLoading: false,
      error: null,
    });

    render(<App />);

    expect(screen.getByText('Try a working included feed')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Azure product updates' })).toHaveAttribute(
      'href',
      '/microsoft.com/azure-products.rss'
    );
    expect(screen.getByText('Custom feed generation is disabled for this instance.')).toBeInTheDocument();
  });

  it('renders the result panel when a feed is available', async () => {
    vi.spyOn(window, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({ items: [] }),
    } as Response);

    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: {
        id: 'feed-123',
        name: 'Example Feed',
        url: 'https://example.com/articles',
        strategy: 'faraday',
        feed_token: 'example-token',
        public_url: '/api/v1/feeds/example-token',
        json_public_url: '/api/v1/feeds/example-token.json',
      },
      error: null,
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
    });

    render(<App />);

    expect(screen.getByRole('button', { name: 'Create another feed' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Bookmarklet' })).not.toBeInTheDocument();
    expect(screen.getByText('Example Feed')).toBeInTheDocument();
  });

  it('surfaces conversion errors to the user', () => {
    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: null,
      error: 'Access denied',
      convertFeed: mockConvertFeed,
      clearResult: mockClearResult,
    });

    render(<App />);

    expect(screen.getByText('Feed generation failed')).toBeInTheDocument();
    expect(screen.getByText('Access denied')).toBeInTheDocument();
  });

  it('clears stored token from instance info', () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: null,
    });

    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: 'More' }));
    fireEvent.click(screen.getByRole('button', { name: 'Clear saved token' }));

    expect(mockClearToken).toHaveBeenCalled();
  });

  it('keeps the Docker Hub link before token clear when a token is saved', () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: null,
    });

    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: 'More' }));

    const utilityItems = Array.from(
      screen
        .getByLabelText('Utilities')
        .querySelectorAll('.utility-strip__items > a, .utility-strip__items > button')
    ).map((element) => element.textContent);

    expect(utilityItems).toEqual([
      'Try included feeds',
      'Bookmarklet',
      'OpenAPI spec',
      'Source code',
      'Install from Docker Hub',
      'Clear saved token',
    ]);
  });

  it('saves access token and resumes feed creation from the inline prompt', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));
    const accessTokenInput = document.getElementById('access-token') as HTMLInputElement;
    fireEvent.input(accessTokenInput, { target: { value: 'token-123' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save and continue' }));

    await waitFor(() => {
      expect(mockSaveToken).toHaveBeenCalledWith('token-123');
      expect(mockConvertFeed).toHaveBeenCalledWith(
        'https://example.com/articles',
        'browserless',
        'token-123'
      );
    });
  });

  it('reopens the token prompt when a saved token is rejected', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: null,
    });
    mockConvertFeed.mockRejectedValueOnce(new Error('Unauthorized'));

    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await waitFor(() => {
      expect(screen.getByText('Add access token')).toBeInTheDocument();
      expect(
        screen.getByText('Access token was rejected. Paste a valid token to continue.')
      ).toBeInTheDocument();
      expect(mockClearToken).toHaveBeenCalled();
      expect(mockClearConversionError).toHaveBeenCalled();
    });
  });

  it('clears stale conversion error when backing out of token recovery', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: null,
    });
    mockConvertFeed.mockRejectedValueOnce(new Error('Unauthorized'));

    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await screen.findByText('Access token was rejected. Paste a valid token to continue.');
    fireEvent.click(screen.getByRole('button', { name: 'Back' }));

    expect(screen.queryByText('Feed generation failed')).not.toBeInTheDocument();
    expect(screen.queryByText('Unauthorized')).not.toBeInTheDocument();
  });

  it('submits the token prompt with Enter', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    const accessTokenInput = document.getElementById('access-token') as HTMLInputElement;
    fireEvent.input(accessTokenInput, { target: { value: 'token-123' } });
    fireEvent.keyDown(accessTokenInput, { key: 'Enter' });

    await waitFor(() => {
      expect(mockSaveToken).toHaveBeenCalledWith('token-123');
    });
  });

  it('builds a bookmarklet that returns to the root app entry', () => {
    window.history.replaceState({}, '', 'http://localhost:3000/');
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: 'More' }));
    const bookmarklet = screen.getByRole('link', { name: 'Bookmarklet' });
    expect(bookmarklet.getAttribute('href')).toContain('/?url=');
    expect(bookmarklet.getAttribute('href')).not.toContain('%27+encodeURIComponent');
  });

  it('shows the utility links in a user-focused order', () => {
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: 'More' }));

    const utilityLinks = screen.getAllByRole('link').map((link) => link.textContent);
    expect(utilityLinks).toEqual([
      'Try included feeds',
      'Bookmarklet',
      'OpenAPI spec',
      'Source code',
      'Install from Docker Hub',
    ]);

    expect(screen.getByRole('link', { name: 'OpenAPI spec' })).toHaveAttribute(
      'href',
      'http://example.test/openapi.yaml'
    );
    expect(screen.getByRole('link', { name: 'Try included feeds' })).toHaveAttribute(
      'href',
      'https://html2rss.github.io/web-application/how-to/use-included-configs/'
    );
    expect(screen.getByRole('link', { name: 'Install from Docker Hub' })).toHaveAttribute(
      'href',
      'https://hub.docker.com/r/html2rss/web'
    );
  });
});
