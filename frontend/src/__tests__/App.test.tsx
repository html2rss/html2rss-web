import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
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

import { useAccessToken } from '../hooks/useAccessToken';
import { useApiMetadata } from '../hooks/useApiMetadata';
import { useFeedConversion } from '../hooks/useFeedConversion';

const mockUseAccessToken = useAccessToken as any;
const mockUseApiMetadata = useApiMetadata as any;
const mockUseFeedConversion = useFeedConversion as any;
const mockCreatedFeedResult = {
  feed: {
    id: 'feed-123',
    name: 'Example Feed',
    url: 'https://example.com/articles',
    feed_token: 'generated-token',
    public_url: '/api/v1/feeds/generated-token',
    json_public_url: '/api/v1/feeds/generated-token.json',
  },
  preview: {
    items: [],
    error: undefined,
    isLoading: true,
  },
  workflowState: 'created' as const,
  warnings: [],
  retry: undefined,
};

describe('App', () => {
  const mockSaveToken = vi.fn();
  const mockClearToken = vi.fn();
  const mockConvertFeed = vi.fn();
  const mockClearConversionError = vi.fn();
  const mockClearResult = vi.fn();
  const mockRetryPreviewFetch = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    globalThis.history.replaceState({}, '', 'http://localhost:3000/#/create');
    globalThis.localStorage.clear();
    mockConvertFeed.mockResolvedValue(mockCreatedFeedResult);

    mockUseAccessToken.mockReturnValue({
      token: undefined,
      hasToken: false,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
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
      error: undefined,
    });

    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: undefined,
      error: undefined,
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });
  });

  it('renders the radical-simple create flow', () => {
    render(<App />);

    expect(screen.getByLabelText('html2rss')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'html2rss' })).toHaveAttribute('href', '/#/create');
    expect(screen.getByLabelText('Page URL')).toBeInTheDocument();
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();
    expect(screen.getByLabelText('Utilities')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Bookmarklet' })).toBeInTheDocument();
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'create');
  });

  it('keeps the page url field permissive enough for hostname-only input', () => {
    render(<App />);

    const urlInput = screen.getByLabelText('Page URL');

    expect(urlInput).toHaveAttribute('type', 'text');
    expect(urlInput).toHaveAttribute('inputmode', 'url');
    expect(urlInput).toHaveAttribute('autocapitalize', 'off');
  });

  it('autofocuses the source url field', async () => {
    render(<App />);

    await waitFor(() => {
      expect(document.activeElement).toBe(screen.getByLabelText('Page URL'));
    });
  });

  it('submits create requests without exposing strategy selection', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await waitFor(() => {
      expect(mockConvertFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
    });
  });

  it('auto-submits a prefilled url without persisting strategy state', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });
    globalThis.history.replaceState(
      {},
      '',
      'http://localhost:3000/?url=https%3A%2F%2Fexample.com%2Farticles'
    );

    render(<App />);

    await waitFor(() => {
      expect(mockConvertFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
      expect(globalThis.location.hash).toBe('#/result/generated-token');
    });
  });

  it('shows the create flow when opening a stale result deep link', async () => {
    globalThis.history.replaceState({}, '', 'http://localhost:3000/#/result/generated-token');

    render(<App />);

    expect(screen.getByLabelText('Page URL')).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'Saved result unavailable' })).not.toBeInTheDocument();
  });

  it('shows inline token prompt when submitting without a token', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    expect(screen.getByText('Enter access token')).toBeInTheDocument();
    expect(globalThis.location.hash).toMatch(/^#\/token/);
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'token_prompt');
    expect(screen.getByLabelText('Page URL')).toBeDisabled();
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();
    expect(screen.getByLabelText('Utilities')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Set up your own instance with Docker.' })).toBeInTheDocument();
    expect(screen.getByText('Required by this instance.')).toBeInTheDocument();
    expect(screen.queryByText('Paste an access token to keep going.')).not.toBeInTheDocument();
    await waitFor(() => {
      expect(document.activeElement).toBe(document.querySelector('#access-token'));
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
      error: undefined,
    });

    render(<App />);

    expect(screen.getByText('Try a working included feed')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Azure product updates' })).toHaveAttribute(
      'href',
      '/microsoft.com/azure-products.rss'
    );
    expect(screen.getByText('Feed creation is disabled on this instance.')).toBeInTheDocument();
  });

  it('renders the result panel when a feed is available', async () => {
    globalThis.history.replaceState({}, '', 'http://localhost:3000/#/result/example-token');
    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: {
        feed: {
          id: 'feed-123',
          name: 'Example Feed',
          url: 'https://example.com/articles',
          feed_token: 'example-token',
          public_url: '/api/v1/feeds/example-token',
          json_public_url: '/api/v1/feeds/example-token.json',
        },
        preview: {
          items: [],
          isLoading: false,
        },
        workflowState: 'preview_failed' as const,
        warnings: [
          {
            code: 'preview_unavailable',
            message: 'Preview unavailable right now.',
            retryable: false,
            nextAction: 'none',
          },
        ],
        retry: undefined,
      },
      error: undefined,
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });

    render(<App />);

    expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'result');
    expect(screen.getByRole('button', { name: 'Create another feed' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open feed' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Bookmarklet' })).toBeInTheDocument();
    expect(screen.getByText('Example Feed')).toBeInTheDocument();
    expect(screen.getByText('Feed link created')).toBeInTheDocument();
    expect(screen.getByText('Preview unavailable right now.')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Create another feed' }));
    return waitFor(() => {
      expect(globalThis.location.hash).toMatch(/^#\/create/);
    });
  });

  it('surfaces conversion errors to the user', () => {
    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: undefined,
      error: {
        kind: 'auth',
        code: 'UNAUTHORIZED',
        retryable: false,
        nextAction: 'enter_token',
        retryAction: 'none',
        message: 'Access denied',
      },
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });

    render(<App />);

    expect(screen.getByText("Couldn't create feed yet")).toBeInTheDocument();
    expect(screen.getByText('Access denied')).toBeInTheDocument();
  });

  it('shows an explicit loading notice while feed creation is still resolving preview state', () => {
    mockUseFeedConversion.mockReturnValue({
      isConverting: true,
      result: undefined,
      error: undefined,
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });

    render(<App />);

    expect(screen.getByText('Creating feed link')).toBeInTheDocument();
  });

  it('clears stored token from instance info', () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: 'Logout' }));

    expect(mockClearToken).toHaveBeenCalled();
  });

  it('keeps the Docker Hub link before token clear when a token is saved', () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    const utilityItems = [
      ...screen
        .getByLabelText('Utilities')
        .querySelectorAll('.utility-strip__items > a, .utility-strip__items > button'),
    ].map((element) => element.textContent);

    expect(utilityItems).toEqual([
      'Try included feeds',
      'Bookmarklet',
      'Logout',
      'Install from Docker Hub',
      'OpenAPI spec',
      'Source code',
    ]);
  });

  it('saves access token and resumes feed creation from the inline prompt', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));
    const accessTokenInput = document.querySelector('#access-token') as HTMLInputElement;
    fireEvent.input(accessTokenInput, { target: { value: 'token-123' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save and continue' }));

    await waitFor(() => {
      expect(mockSaveToken).toHaveBeenCalledWith('token-123');
      expect(mockConvertFeed).toHaveBeenCalledWith('https://example.com/articles', 'token-123');
    });
  });

  it('reopens the token prompt when a saved token is rejected', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });
    mockConvertFeed.mockRejectedValueOnce(
      Object.assign(new Error('Unauthorized'), {
        code: 'UNAUTHORIZED',
        status: 401,
        kind: 'auth',
      })
    );

    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await waitFor(() => {
      expect(screen.getByText('Enter access token')).toBeInTheDocument();
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
      error: undefined,
    });
    mockConvertFeed.mockRejectedValueOnce(
      Object.assign(new Error('Unauthorized'), {
        code: 'UNAUTHORIZED',
        status: 401,
        kind: 'auth',
      })
    );

    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    await screen.findByText('Access token was rejected. Paste a valid token to continue.');
    fireEvent.click(screen.getByRole('button', { name: 'Back' }));

    await waitFor(() => {
      expect(globalThis.location.hash).toMatch(/^#\/create/);
    });
    expect(screen.queryByText("Couldn't create feed yet")).not.toBeInTheDocument();
    expect(screen.queryByText('Unauthorized')).not.toBeInTheDocument();
  });

  it('submits the token prompt with Enter', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    const accessTokenInput = document.querySelector('#access-token') as HTMLInputElement;
    fireEvent.input(accessTokenInput, { target: { value: 'token-123' } });
    fireEvent.keyDown(accessTokenInput, { key: 'Enter' });

    await waitFor(() => {
      expect(mockSaveToken).toHaveBeenCalledWith('token-123');
    });
  });

  it('builds a bookmarklet that returns to the root app entry', () => {
    globalThis.history.replaceState({}, '', 'http://localhost:3000/#/create');
    render(<App />);

    const bookmarklet = screen.getByRole('link', { name: 'Bookmarklet' });
    expect(bookmarklet.getAttribute('href')).toContain('/#/create?url=');
    expect(bookmarklet.getAttribute('href')).not.toContain('%27+encodeURIComponent');
  });

  it('opens token entry immediately for bookmarklet urls when no token is saved', async () => {
    globalThis.history.replaceState({}, '', 'http://localhost:3000/?url=example.com%2Farticles');

    render(<App />);

    await screen.findByText('Enter access token');
    expect(globalThis.location.hash).toMatch(/^#\/token/);
    expect(screen.getByLabelText('Page URL')).toHaveValue('https://example.com/articles');
    expect(mockConvertFeed).not.toHaveBeenCalled();
  });

  it('shows generic retry action for alternate retry metadata and reruns create', async () => {
    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: undefined,
      error: {
        kind: 'server',
        code: 'INTERNAL_SERVER_ERROR',
        retryable: true,
        nextAction: 'retry',
        retryAction: 'alternate',
        message: 'Browserless failed.',
      },
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Try again' }));

    expect(screen.queryByRole('button', { name: /Retry with .*/ })).not.toBeInTheDocument();

    await waitFor(() => {
      expect(mockConvertFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
    });
  });

  it('shows Try again for primary retry metadata and reruns the create flow', async () => {
    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: undefined,
      error: {
        kind: 'server',
        code: 'INTERNAL_SERVER_ERROR',
        retryable: true,
        nextAction: 'retry',
        retryAction: 'primary',
        message: 'Browserless failed.',
      },
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    fireEvent.input(screen.getByLabelText('Page URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Try again' }));

    await waitFor(() => {
      expect(mockConvertFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
    });
  });

  it('does not treat non-token forbidden failures as token rejection or strategy-recovery UX', async () => {
    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: undefined,
      error: {
        kind: 'server',
        code: 'FORBIDDEN',
        retryable: false,
        nextAction: 'none',
        retryAction: 'none',
        message: 'URL not allowed for this account',
      },
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    await screen.findByText('URL not allowed for this account');
    expect(mockClearToken).not.toHaveBeenCalled();
    expect(screen.queryByText('Enter access token')).not.toBeInTheDocument();
    expect(
      screen.queryByText('Access token was rejected. Paste a valid token to continue.')
    ).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Try again' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Retry with .*/ })).not.toBeInTheDocument();
  });

  it('keeps extraction-empty failures generic and input-corrective', async () => {
    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: undefined,
      error: {
        kind: 'input',
        code: 'NO_FEED_ITEMS_EXTRACTED',
        retryable: false,
        nextAction: 'correct_input',
        retryAction: 'none',
        message: 'Could not extract feed items. Try a more specific listing URL or explicit selectors.',
      },
      convertFeed: mockConvertFeed,
      clearError: mockClearConversionError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    await screen.findByText(
      'Could not extract feed items. Try a more specific listing URL or explicit selectors.'
    );
    expect(screen.queryByText('Enter access token')).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Try again' })).not.toBeInTheDocument();
    expect(mockClearToken).not.toHaveBeenCalled();
  });

  it('shows the utility links in a user-focused order', () => {
    globalThis.history.replaceState({}, '', 'http://localhost:3000/#/create');
    render(<App />);

    const utilityLinks = [
      ...screen.getByLabelText('Utilities').querySelectorAll('.utility-strip__items > a'),
    ].map((link) => link.textContent);
    expect(utilityLinks).toEqual([
      'Try included feeds',
      'Bookmarklet',
      'Install from Docker Hub',
      'OpenAPI spec',
      'Source code',
    ]);

    expect(screen.getByRole('link', { name: 'OpenAPI spec' })).toHaveAttribute(
      'href',
      'http://example.test/openapi.yaml'
    );
    expect(screen.getByRole('link', { name: 'Try included feeds' })).toHaveAttribute(
      'href',
      'https://html2rss.github.io/feed-directory/#!url=http%3A%2F%2Flocalhost%3A3000%2F'
    );
    expect(screen.getByRole('link', { name: 'Install from Docker Hub' })).toHaveAttribute(
      'href',
      'https://hub.docker.com/r/html2rss/web'
    );
  });

  it('keeps OpenAPI link on the frontend origin during local development', () => {
    mockUseApiMetadata.mockReturnValue({
      metadata: {
        api: {
          name: 'html2rss-web API',
          description: 'RESTful API for converting websites to RSS feeds',
          openapi_url: 'http://127.0.0.1:4000/openapi.yaml',
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
      error: undefined,
    });

    globalThis.history.replaceState({}, '', 'http://localhost:3000/#/create');
    render(<App />);

    expect(screen.getByRole('link', { name: 'OpenAPI spec' })).toHaveAttribute(
      'href',
      'http://localhost:3000/openapi.yaml'
    );
  });

  it('shows footer utilities on result routes', async () => {
    globalThis.history.replaceState({}, '', 'http://localhost:3000/#/result/generated-token');
    render(<App />);

    await waitFor(() => {
      expect(screen.getByLabelText('Utilities')).toBeInTheDocument();
    });
  });
});
