import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import type { FeedCreationError } from '../api/contracts';
import { App } from '../components/App';
import { COPY } from '../journey/copy';

vi.mock('../session/accessToken', () => ({
  useAccessToken: vi.fn(),
  resetAccessTokenMemory: vi.fn(),
}));

vi.mock('../feed/useFeedCreation', () => ({
  useFeedCreation: vi.fn(),
}));

vi.mock('../hooks/useApiMetadata', () => ({
  useApiMetadata: vi.fn(),
}));

vi.mock('../catalog/useCatalogEntries', () => ({
  useCatalogEntries: vi.fn(() => []),
}));

import { useAccessToken } from '../session/accessToken';
import { useApiMetadata } from '../hooks/useApiMetadata';
import { useFeedCreation } from '../feed/useFeedCreation';
import { useCatalogEntries } from '../catalog/useCatalogEntries';

const mockUseAccessToken = useAccessToken as any;
const mockUseApiMetadata = useApiMetadata as any;
const mockUseFeedCreation = useFeedCreation as any;
const mockUseCatalogEntries = useCatalogEntries as any;
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
    status: 'created' as const,
    items: [],
    isLoading: true,
  },
  warnings: [],
};

async function expectCreateRemountedWithoutErrorChrome() {
  await waitFor(() => {
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
    expect(screen.queryByText(COPY.createFailedRetryTitle)).not.toBeInTheDocument();
  });
  expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'create');
  await waitFor(() => {
    expect(document.activeElement).toBe(screen.getByLabelText(COPY.urlLabel));
  });
}

describe('App', () => {
  const mockSaveToken = vi.fn();
  const mockClearToken = vi.fn();
  const mockCreateFeed = vi.fn();
  const mockClearCreationError = vi.fn();
  const mockClearResult = vi.fn();
  const mockRetryPreviewFetch = vi.fn();
  /** Mirrors useFeedCreation: reject sets error; clearError clears it (App mock was static). */
  let creationHookError: FeedCreationError | undefined;

  beforeEach(() => {
    vi.clearAllMocks();
    creationHookError = undefined;
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    localStorage.clear();
    mockCreateFeed.mockResolvedValue(mockCreatedFeedResult);
    mockClearCreationError.mockImplementation(() => {
      creationHookError = undefined;
    });
    mockUseCatalogEntries.mockReturnValue([]);

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
          openapi_url: 'https://example.test/openapi.yaml',
        },
        instance: {
          feed_creation: {
            enabled: true,
            access_token_required: true,
          },
          catalog: { enabled: true, url: '/api/v1/configs' },
        },
      },
      isLoading: false,
      error: undefined,
    });

    mockUseFeedCreation.mockImplementation(() => ({
      isCreating: false,
      result: undefined,
      error: creationHookError,
      createFeed: async (url: string, token: string) => {
        try {
          return await mockCreateFeed(url, token);
        } catch (error) {
          creationHookError = error as FeedCreationError;
          throw error;
        }
      },
      clearError: mockClearCreationError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    }));
  });

  const creationFailure = {
    kind: 'server' as const,
    code: 'INTERNAL_SERVER_ERROR' as const,
    retryable: true,
    nextAction: 'retry' as const,
    retryAction: 'primary' as const,
    message: 'Access denied',
  };

  async function renderCreateWithCreationError() {
    mockUseApiMetadata.mockReturnValue({
      metadata: {
        api: {
          name: 'html2rss-web API',
          description: 'RESTful API for converting websites to RSS feeds',
          openapi_url: 'https://example.test/openapi.yaml',
        },
        instance: {
          feed_creation: {
            enabled: true,
            access_token_required: false,
          },
          catalog: { enabled: true, url: '/api/v1/configs' },
        },
      },
      isLoading: false,
      error: undefined,
    });
    mockCreateFeed.mockRejectedValue(creationFailure);

    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    await waitFor(() => {
      expect(screen.getByText(COPY.createFailedRetryTitle)).toBeInTheDocument();
    });
  }

  it('renders the radical-simple create flow', () => {
    render(<App />);

    expect(screen.getByLabelText('html2rss')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'html2rss' }).getAttribute('href')).toMatch(/#\/create$/);
    expect(screen.getByLabelText(COPY.urlLabel)).toBeInTheDocument();
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();
    expect(screen.getByLabelText(COPY.utilities)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: COPY.bookmarkletTitle })).toBeInTheDocument();
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'create');
  });

  it('keeps the URL field permissive enough for hostname-only input', () => {
    render(<App />);

    const urlInput = screen.getByLabelText(COPY.urlLabel);

    expect(urlInput).toHaveAttribute('type', 'text');
    expect(urlInput).toHaveAttribute('inputmode', 'url');
    expect(urlInput).toHaveAttribute('autocapitalize', 'off');
  });

  it('autofocuses the URL field', async () => {
    render(<App />);

    await waitFor(() => {
      expect(document.activeElement).toBe(screen.getByLabelText(COPY.urlLabel));
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

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    await waitFor(() => {
      expect(mockCreateFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
    });
  });

  it('submits create requests when Enter is pressed on the URL field', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.keyDown(screen.getByLabelText(COPY.urlLabel), { key: 'Enter' });

    await waitFor(() => {
      expect(mockCreateFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
    });
  });

  it('does not submit extra create requests when Enter key-repeats', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    const urlField = screen.getByLabelText(COPY.urlLabel);
    fireEvent.keyDown(urlField, { key: 'Enter' });
    fireEvent.keyDown(urlField, { key: 'Enter', repeat: true });
    fireEvent.keyDown(urlField, { key: 'Enter', repeat: true });

    await waitFor(() => {
      expect(mockCreateFeed).toHaveBeenCalledTimes(1);
    });
    expect(mockCreateFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
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
    history.replaceState({}, '', 'http://localhost:3000/?url=https%3A%2F%2Fexample.com%2Farticles');

    render(<App />);

    await waitFor(() => {
      expect(mockCreateFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
      expect(location.hash).toBe('#/result/generated-token');
    });
  });

  it('recovers unmatched result deep links onto remounted create without url prefill', async () => {
    history.replaceState({}, '', 'http://localhost:3000/#/result/generated-token');

    render(<App />);

    await waitFor(() => {
      expect(location.hash).toBe('#/create');
    });
    expect(location.hash).not.toContain('url=');
    expect(screen.getByLabelText(COPY.urlLabel)).toBeInTheDocument();
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'create');
    expect(screen.queryByRole('heading', { name: 'Saved result unavailable' })).not.toBeInTheDocument();
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
  });

  it('remounts create from BrandLockup and clears creation chrome', async () => {
    await renderCreateWithCreationError();
    const createCalls = mockCreateFeed.mock.calls.length;

    fireEvent.click(screen.getByRole('link', { name: 'html2rss' }));

    await expectCreateRemountedWithoutErrorChrome();
    expect(mockCreateFeed).toHaveBeenCalledTimes(createCalls);
  });

  it('remounts create from a #/create visit and clears creation chrome', async () => {
    await renderCreateWithCreationError();
    const createCalls = mockCreateFeed.mock.calls.length;

    dispatchEvent(new HashChangeEvent('hashchange'));

    await expectCreateRemountedWithoutErrorChrome();
    expect(location.hash).toBe('#/create');
    expect(mockCreateFeed).toHaveBeenCalledTimes(createCalls);
  });

  it('remounts create from a hashbang entry and clears creation chrome', async () => {
    await renderCreateWithCreationError();
    const createCalls = mockCreateFeed.mock.calls.length;

    location.hash = '#!/create';

    await waitFor(() => {
      expect(location.hash).toBe('#/create');
    });
    await expectCreateRemountedWithoutErrorChrome();
    expect(mockCreateFeed).toHaveBeenCalledTimes(createCalls);
  });

  it('shows inline token prompt when submitting without a token', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    expect(screen.getByRole('heading', { name: COPY.tokenTitle })).toBeInTheDocument();
    expect(location.hash).toMatch(/^#\/token/);
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'token_prompt');
    expect(document.querySelector('dialog')).toHaveAttribute('open');
    expect(screen.getByLabelText(COPY.urlLabel)).toBeInTheDocument();
    expect(screen.getByLabelText(COPY.urlLabel).closest('[inert]')).not.toBeNull();
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();
    expect(screen.getByLabelText(COPY.utilities)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: COPY.dockerSetup })).toBeInTheDocument();
    expect(screen.getByText(COPY.tokenHint)).toBeInTheDocument();
    expect(screen.queryByText('Paste an access token to keep going.')).not.toBeInTheDocument();
    await waitFor(() => {
      expect(document.activeElement).toBe(document.querySelector('#access-token'));
    });
    expect(mockCreateFeed).not.toHaveBeenCalled();
  });

  const azureStarter = {
    id: 'microsoft.com/azure-products',
    path: '/microsoft.com/azure-products.rss',
    title: 'Azure product updates',
    description: 'Follow Microsoft Azure product announcements from your own instance.',
    channelUrl: 'https://azure.microsoft.com/updates',
    parameterDefaults: {},
  };

  it('shows lean included-feed starters on empty create when creation is enabled', async () => {
    mockUseCatalogEntries.mockReturnValue([azureStarter]);
    mockUseAccessToken.mockReturnValue({
      token: 'session-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByRole('link', { name: 'Azure product updates' })).toHaveAttribute(
        'href',
        '/microsoft.com/azure-products.rss'
      );
    });
    expect(screen.getByText(COPY.includedFeedsHint)).toBeInTheDocument();
    expect(screen.queryByText(COPY.includedFeedsIntro)).not.toBeInTheDocument();
    expect(screen.queryByText(COPY.includedFeedsLearnMore)).not.toBeInTheDocument();
    expect(document.querySelector('.notice')).toBeNull();
    expect(screen.getByRole('list', { name: COPY.includedFeedsTitle })).toBeInTheDocument();
    await waitFor(() => {
      expect(document.activeElement).toBe(screen.getByLabelText(COPY.urlLabel));
    });
  });

  it('hides included-feed starters when the URL field is non-empty', async () => {
    mockUseCatalogEntries.mockReturnValue([azureStarter]);
    mockUseAccessToken.mockReturnValue({
      token: 'session-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByRole('link', { name: 'Azure product updates' })).toBeInTheDocument();
    });

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'example.com/articles' },
    });

    expect(screen.queryByRole('link', { name: 'Azure product updates' })).not.toBeInTheDocument();
    expect(screen.queryByText(COPY.includedFeedsHint)).not.toBeInTheDocument();
  });

  it('hides included-feed starters when catalog find has hits', async () => {
    mockUseCatalogEntries.mockReturnValue([
      azureStarter,
      {
        id: 'anthropic.com/news',
        path: '/anthropic.com/news.rss',
        title: 'Anthropic — News',
        description: 'Product and research announcements from Anthropic.',
        channelUrl: 'https://www.anthropic.com/news',
        parameterDefaults: {},
      },
    ]);
    mockUseAccessToken.mockReturnValue({
      token: 'session-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByRole('link', { name: 'Azure product updates' })).toBeInTheDocument();
    });

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'www.anthropic.com/news' },
    });

    await waitFor(() => {
      expect(screen.getByRole('option', { name: 'Anthropic — News' })).toBeInTheDocument();
    });
    expect(screen.queryByRole('link', { name: 'Azure product updates' })).not.toBeInTheDocument();
    expect(screen.queryByText(COPY.includedFeedsHint)).not.toBeInTheDocument();
  });

  it('promotes included feeds when feed creation is disabled', async () => {
    mockUseCatalogEntries.mockReturnValue([azureStarter]);

    mockUseApiMetadata.mockReturnValue({
      metadata: {
        api: {
          name: 'html2rss-web API',
          description: 'RESTful API for converting websites to RSS feeds',
          openapi_url: 'https://example.test/openapi.yaml',
        },
        instance: {
          feed_creation: {
            enabled: false,
            access_token_required: false,
          },
          catalog: { enabled: true, url: '/api/v1/configs' },
        },
      },
      isLoading: false,
      error: undefined,
    });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByText(COPY.includedFeedsTitle)).toBeInTheDocument();
    });
    expect(screen.getByRole('link', { name: 'Azure product updates' })).toHaveAttribute(
      'href',
      '/microsoft.com/azure-products.rss'
    );
    expect(screen.getByText(COPY.creationDisabled)).toBeInTheDocument();
    expect(screen.getByText(COPY.includedFeedsIntro)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: COPY.includedFeedsLearnMore })).toBeInTheDocument();
    expect(document.querySelector('.notice')).not.toBeNull();
  });

  it('suggests included feeds when the URL matches the catalog', async () => {
    mockUseCatalogEntries.mockReturnValue([
      {
        id: 'anthropic.com/news',
        path: '/anthropic.com/news.rss',
        title: 'Anthropic — News',
        description: 'Product and research announcements from Anthropic.',
        channelUrl: 'https://www.anthropic.com/news',
        parameterDefaults: {},
      },
    ]);

    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'www.anthropic.com/news' },
    });

    await waitFor(() => {
      expect(screen.getByRole('option', { name: 'Anthropic — News' })).toHaveAttribute(
        'href',
        '/anthropic.com/news.rss'
      );
    });
    expect(screen.getByRole('status')).toHaveTextContent(COPY.catalogFindHint);
  });

  it('lists multiple catalog find hits for a text query including defaults href', async () => {
    mockUseCatalogEntries.mockReturnValue([
      {
        id: 'bbc.com/mundo',
        path: '/bbc.com/mundo.rss',
        title: 'BBC — Mundo',
        description: 'Spanish-language news from BBC Mundo.',
        channelUrl: 'https://www.bbc.com/mundo',
        parameterDefaults: {},
      },
      {
        id: 'bbc.co.uk/available_episodes',
        path: '/bbc.co.uk/available_episodes.rss',
        title: 'BBC Sounds — Programme episodes',
        description: 'Available episodes for a BBC programme on Sounds.',
        channelUrl: 'https://www.bbc.co.uk/programmes/%<id>s/episodes/player',
        parameterDefaults: { id: 'b006wkfp' },
      },
    ]);

    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'bbc' },
    });

    await waitFor(() => {
      expect(screen.getByRole('option', { name: 'BBC — Mundo' })).toHaveAttribute(
        'href',
        '/bbc.com/mundo.rss'
      );
      expect(screen.getByRole('option', { name: 'BBC Sounds — Programme episodes' })).toHaveAttribute(
        'href',
        '/bbc.co.uk/available_episodes.rss?id=b006wkfp'
      );
    });

    expect(screen.getByRole('option', { name: 'BBC — Mundo' })).toHaveClass('catalog-hit');
    expect(screen.getByRole('option', { name: 'BBC — Mundo' })).not.toHaveClass('ui-card');
    expect(screen.getByRole('listbox', { name: COPY.catalogFindHitsLabel })).toBeInTheDocument();
  });

  it('opens the active catalog hit with ArrowDown then Enter without submitting Create', async () => {
    const assignSpy = vi.fn();
    vi.stubGlobal('location', { ...location, assign: assignSpy });

    mockUseCatalogEntries.mockReturnValue([
      {
        id: 'bbc.com/mundo',
        path: '/bbc.com/mundo.rss',
        title: 'BBC — Mundo',
        description: 'Spanish-language news from BBC Mundo.',
        channelUrl: 'https://www.bbc.com/mundo',
        parameterDefaults: {},
      },
      {
        id: 'bbc.co.uk/available_episodes',
        path: '/bbc.co.uk/available_episodes.rss',
        title: 'BBC Sounds — Programme episodes',
        description: 'Available episodes for a BBC programme on Sounds.',
        channelUrl: 'https://www.bbc.co.uk/programmes/%<id>s/episodes/player',
        parameterDefaults: { id: 'b006wkfp' },
      },
    ]);

    render(<App />);

    const urlField = screen.getByLabelText(COPY.urlLabel);
    fireEvent.input(urlField, { target: { value: 'bbc' } });

    await waitFor(() => {
      expect(screen.getByRole('listbox', { name: COPY.catalogFindHitsLabel })).toBeInTheDocument();
    });

    fireEvent.keyDown(urlField, { key: 'ArrowDown' });
    await waitFor(() => {
      expect(urlField).toHaveAttribute('aria-activedescendant', 'catalog-find-hits-option-0');
    });

    fireEvent.keyDown(urlField, { key: 'Enter' });

    expect(assignSpy).toHaveBeenCalledWith('/bbc.co.uk/available_episodes.rss?id=b006wkfp');
    expect(mockCreateFeed).not.toHaveBeenCalled();

    vi.unstubAllGlobals();
  });

  it('submits Create with Enter when no catalog hit is active', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });

    mockUseCatalogEntries.mockReturnValue([
      {
        id: 'bbc.com/mundo',
        path: '/bbc.com/mundo.rss',
        title: 'BBC — Mundo',
        description: 'Spanish-language news from BBC Mundo.',
        channelUrl: 'https://www.bbc.com/mundo',
        parameterDefaults: {},
      },
    ]);

    render(<App />);

    const urlField = screen.getByLabelText(COPY.urlLabel);
    fireEvent.input(urlField, { target: { value: 'https://www.bbc.com/mundo' } });

    await waitFor(() => {
      expect(screen.getByRole('listbox', { name: COPY.catalogFindHitsLabel })).toBeInTheDocument();
    });

    fireEvent.keyDown(urlField, { key: 'Enter' });

    await waitFor(() => {
      expect(mockCreateFeed).toHaveBeenCalledWith('https://www.bbc.com/mundo', 'saved-token');
    });
  });

  it('renders the result panel when a feed is available', async () => {
    history.replaceState({}, '', 'http://localhost:3000/#/result/example-token');
    mockUseFeedCreation.mockReturnValue({
      isCreating: false,
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
          status: 'preview_failed' as const,
          items: [],
          isLoading: false,
        },
        warnings: [
          {
            code: 'preview_unavailable',
            message: 'Preview unavailable right now.',
            retryable: false,
            nextAction: 'none',
          },
        ],
      },
      error: undefined,
      createFeed: mockCreateFeed,
      clearError: mockClearCreationError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });

    render(<App />);

    expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'result');
    expect(screen.getByRole('button', { name: COPY.createAnother })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: COPY.openFeed })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: COPY.bookmarkletTitle })).toBeInTheDocument();
    expect(screen.getByText('Example Feed')).toBeInTheDocument();
    expect(screen.getByText(COPY.feedReady)).toBeInTheDocument();
    expect(screen.getByText(COPY.previewUnavailable)).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: COPY.createAnother }));
    return waitFor(() => {
      expect(location.hash).toMatch(/^#\/create/);
    });
  });

  it('surfaces creation errors to the user', () => {
    mockUseFeedCreation.mockReturnValue({
      isCreating: false,
      result: undefined,
      error: {
        kind: 'server',
        code: 'INTERNAL_SERVER_ERROR',
        retryable: true,
        nextAction: 'retry',
        retryAction: 'primary',
        message: 'Access denied',
      },
      createFeed: mockCreateFeed,
      clearError: mockClearCreationError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });

    render(<App />);

    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'error');
    expect(screen.getByText(COPY.createFailedRetryTitle)).toBeInTheDocument();
    expect(screen.getByText('Access denied')).toBeInTheDocument();
  });

  it('presents classified create errors with the wire sentence', () => {
    mockUseFeedCreation.mockReturnValue({
      isCreating: false,
      result: undefined,
      error: {
        kind: 'input',
        code: 'BLOCKED_SURFACE',
        retryable: false,
        nextAction: 'correct_input',
        retryAction: 'none',
        message: 'This site blocked automated access. Try another URL or site.',
      },
      createFeed: mockCreateFeed,
      clearError: mockClearCreationError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });

    render(<App />);

    expect(screen.getByText(COPY.createFailedTitle)).toBeInTheDocument();
    expect(
      screen.getByText('This site blocked automated access. Try another URL or site.')
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: COPY.tryAgain })).not.toBeInTheDocument();
  });

  it('shows instance metadata failure as a banner without create-error chrome', () => {
    mockUseApiMetadata.mockReturnValue({
      metadata: undefined,
      isLoading: false,
      error: 'Instance unavailable.',
    });

    render(<App />);

    expect(screen.getByText(COPY.instanceMetadataUnavailable)).toBeInTheDocument();
    expect(screen.getByText(COPY.instanceUnavailable)).toBeInTheDocument();
    expect(screen.queryByText(COPY.accessTokenUnavailable)).not.toBeInTheDocument();
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
    expect(document.querySelector('.form-shell')).toHaveAttribute('data-state', 'create');
  });

  it('shows access token load failure with a token title, not metadata heading', () => {
    mockUseAccessToken.mockReturnValue({
      token: undefined,
      hasToken: false,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: COPY.unableToLoadToken,
    });

    render(<App />);

    expect(screen.getByText(COPY.accessTokenUnavailable)).toBeInTheDocument();
    expect(screen.getByText(COPY.unableToLoadToken)).toBeInTheDocument();
    expect(screen.queryByText(COPY.instanceMetadataUnavailable)).not.toBeInTheDocument();
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
  });

  it('shows title-only creating notice without preview copy', () => {
    mockUseFeedCreation.mockReturnValue({
      isCreating: true,
      result: undefined,
      error: undefined,
      createFeed: mockCreateFeed,
      clearError: mockClearCreationError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });

    render(<App />);

    expect(screen.getByText(COPY.creating)).toBeInTheDocument();
    expect(screen.queryByText(COPY.previewChecking)).not.toBeInTheDocument();
  });

  it('keeps the token dialog open while creating', () => {
    mockUseFeedCreation.mockReturnValue({
      isCreating: true,
      result: undefined,
      error: undefined,
      createFeed: mockCreateFeed,
      clearError: mockClearCreationError,
      clearResult: mockClearResult,
      retryPreviewFetch: mockRetryPreviewFetch,
    });
    history.replaceState({}, '', 'http://localhost:3000/#/token?url=https%3A%2F%2Fexample.com%2Farticles');

    render(<App />);

    expect(document.querySelector('dialog')).toHaveAttribute('open');
    expect(screen.getByRole('button', { name: COPY.creating })).toBeInTheDocument();
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
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

    fireEvent.click(screen.getByRole('button', { name: COPY.logout }));

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
        .getByLabelText(COPY.utilities)
        .querySelectorAll(':scope .utility-strip__items > a, :scope .utility-strip__items > button'),
    ].map((element) => element.textContent);

    expect(utilityItems).toEqual([
      COPY.tryIncludedFeeds,
      COPY.bookmarkletTitle,
      COPY.logout,
      COPY.dockerInstall,
      COPY.openapiSpec,
      COPY.sourceCode,
    ]);
  });

  it('saves access token and resumes feed creation from the inline prompt', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));
    const accessTokenInput = document.querySelector('#access-token') as HTMLInputElement;
    fireEvent.input(accessTokenInput, { target: { value: 'token-123' } });
    fireEvent.click(screen.getByRole('button', { name: COPY.saveAndContinue }));

    await waitFor(() => {
      expect(mockSaveToken).toHaveBeenCalledWith('token-123');
      expect(mockCreateFeed).toHaveBeenCalledWith('https://example.com/articles', 'token-123');
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
    mockCreateFeed.mockRejectedValueOnce(
      Object.assign(new Error('Unauthorized'), {
        code: 'UNAUTHORIZED',
        status: 401,
        kind: 'auth',
      })
    );

    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    await waitFor(() => {
      expect(screen.getByRole('heading', { name: COPY.tokenTitle })).toBeInTheDocument();
      expect(screen.getByText(COPY.tokenRejected)).toBeInTheDocument();
      expect(mockClearToken).toHaveBeenCalled();
      expect(mockClearCreationError).toHaveBeenCalled();
    });
  });

  it('clears stale creation error when backing out of the token gate', async () => {
    mockUseAccessToken.mockReturnValue({
      token: 'saved-token',
      hasToken: true,
      saveToken: mockSaveToken,
      clearToken: mockClearToken,
      isLoading: false,
      error: undefined,
    });
    mockCreateFeed.mockRejectedValueOnce(
      Object.assign(new Error('Unauthorized'), {
        code: 'UNAUTHORIZED',
        status: 401,
        kind: 'auth',
      })
    );

    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    await screen.findByText(COPY.tokenRejected);
    fireEvent.click(screen.getByRole('button', { name: COPY.back }));

    await waitFor(() => {
      expect(location.hash).toMatch(/^#\/create/);
    });
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();
    expect(screen.queryByText('Unauthorized')).not.toBeInTheDocument();
  });

  it('submits the token prompt with Enter', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    const accessTokenInput = document.querySelector('#access-token') as HTMLInputElement;
    fireEvent.input(accessTokenInput, { target: { value: 'token-123' } });
    fireEvent.keyDown(accessTokenInput, { key: 'Enter' });

    await waitFor(() => {
      expect(mockSaveToken).toHaveBeenCalledWith('token-123');
    });
  });

  it('builds a bookmarklet that returns to the root app entry', () => {
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    render(<App />);

    const bookmarklet = screen.getByRole('link', { name: COPY.bookmarkletTitle });
    expect(bookmarklet.getAttribute('href')).toContain('/#/create?url=');
    expect(bookmarklet.getAttribute('href')).not.toContain('%27+encodeURIComponent');
  });

  it('opens token entry immediately for bookmarklet urls when no token is saved', async () => {
    history.replaceState({}, '', 'http://localhost:3000/?url=example.com%2Farticles');

    render(<App />);

    await screen.findByRole('heading', { name: COPY.tokenTitle });
    expect(location.hash).toMatch(/^#\/token/);
    expect(document.querySelector('dialog')).toHaveAttribute('open');
    expect(screen.getByLabelText(COPY.urlLabel)).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.getByLabelText(COPY.urlLabel)).toHaveValue('https://example.com/articles');
    });
    expect(mockCreateFeed).not.toHaveBeenCalled();
  });

  it('prefills the URL field when landing with a bookmarklet hash route', async () => {
    history.replaceState({}, '', 'http://localhost:3000/#/create?url=https%3A%2F%2Fexample.com%2Farticles');

    render(<App />);

    await waitFor(() => {
      expect(screen.getByLabelText(COPY.urlLabel)).toHaveValue('https://example.com/articles');
    });
  });

  it('prefers bookmarklet route prefill over a saved draft url', async () => {
    localStorage.setItem(
      'html2rss_feed_draft_state',
      JSON.stringify({ url: 'https://old.example.com/page' })
    );
    history.replaceState({}, '', 'http://localhost:3000/#/create?url=https%3A%2F%2Fexample.com%2Farticles');

    render(<App />);

    await waitFor(() => {
      expect(screen.getByLabelText(COPY.urlLabel)).toHaveValue('https://example.com/articles');
    });
  });

  it('shows generic retry action for alternate retry metadata and reruns create', async () => {
    mockUseFeedCreation.mockReturnValue({
      isCreating: false,
      result: undefined,
      error: {
        kind: 'server',
        code: 'INTERNAL_SERVER_ERROR',
        retryable: true,
        nextAction: 'retry',
        retryAction: 'alternate',
        message: 'Browserless failed.',
      },
      createFeed: mockCreateFeed,
      clearError: mockClearCreationError,
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

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.tryAgain }));

    expect(screen.queryByRole('button', { name: /Retry with .*/ })).not.toBeInTheDocument();

    await waitFor(() => {
      expect(mockCreateFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
    });
  });

  it('shows Try again for primary retry metadata and reruns the create flow', async () => {
    mockUseFeedCreation.mockReturnValue({
      isCreating: false,
      result: undefined,
      error: {
        kind: 'server',
        code: 'INTERNAL_SERVER_ERROR',
        retryable: true,
        nextAction: 'retry',
        retryAction: 'primary',
        message: 'Browserless failed.',
      },
      createFeed: mockCreateFeed,
      clearError: mockClearCreationError,
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

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.tryAgain }));

    await waitFor(() => {
      expect(mockCreateFeed).toHaveBeenCalledWith('https://example.com/articles', 'saved-token');
    });
  });

  it('does not treat non-token forbidden failures as token rejection', async () => {
    mockUseFeedCreation.mockReturnValue({
      isCreating: false,
      result: undefined,
      error: {
        kind: 'server',
        code: 'FORBIDDEN',
        retryable: false,
        nextAction: 'none',
        retryAction: 'none',
        message: 'URL not allowed for this account',
      },
      createFeed: mockCreateFeed,
      clearError: mockClearCreationError,
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
    expect(screen.queryByRole('heading', { name: COPY.tokenTitle })).not.toBeInTheDocument();
    expect(screen.queryByText(COPY.tokenRejected)).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: COPY.tryAgain })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Retry with .*/ })).not.toBeInTheDocument();
  });

  it('keeps extraction-empty failures generic and input-corrective', async () => {
    mockUseFeedCreation.mockReturnValue({
      isCreating: false,
      result: undefined,
      error: {
        kind: 'input',
        code: 'NO_FEED_ITEMS_EXTRACTED',
        retryable: false,
        nextAction: 'correct_input',
        retryAction: 'none',
        message: 'Could not extract feed items. Try a more specific listing URL or explicit selectors.',
      },
      createFeed: mockCreateFeed,
      clearError: mockClearCreationError,
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
    expect(screen.getByText(COPY.createFailedTitle)).toBeInTheDocument();
    expect(screen.queryByText(COPY.createFailedRetryTitle)).not.toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: COPY.tokenTitle })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: COPY.tryAgain })).not.toBeInTheDocument();
    expect(mockClearToken).not.toHaveBeenCalled();
  });

  it('returns non-auth token save failures onto create with notice', async () => {
    mockCreateFeed.mockRejectedValueOnce({
      kind: 'server',
      code: 'INTERNAL_SERVER_ERROR',
      retryable: true,
      nextAction: 'retry',
      retryAction: 'primary',
      message: 'Upstream failed',
    });

    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    const accessTokenInput = document.querySelector('#access-token') as HTMLInputElement;
    fireEvent.input(accessTokenInput, { target: { value: 'token-123' } });
    fireEvent.click(screen.getByRole('button', { name: COPY.saveAndContinue }));

    await waitFor(() => {
      expect(location.hash).toMatch(/^#\/create/);
    });
    expect(document.querySelector('dialog')).toBeNull();
    expect(screen.getByText(COPY.createFailedRetryTitle)).toBeInTheDocument();
    expect(screen.getByText('Upstream failed')).toBeInTheDocument();
  });

  it('cancels the token dialog with Back, Escape, and backdrop', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText(COPY.urlLabel), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    expect(document.querySelector('dialog')).toHaveAttribute('open');
    const accessTokenInput = document.querySelector('#access-token') as HTMLInputElement;
    fireEvent.input(accessTokenInput, { target: { value: 'secret-draft' } });
    fireEvent.click(screen.getByRole('button', { name: COPY.back }));

    await waitFor(() => {
      expect(location.hash).toMatch(/^#\/create/);
    });
    expect(document.querySelector('dialog')).toBeNull();

    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));
    const dialog = document.querySelector('dialog');
    expect(dialog).toHaveAttribute('open');
    expect((document.querySelector('#access-token') as HTMLInputElement).value).toBe('');
    fireEvent(dialog as HTMLDialogElement, new Event('cancel', { bubbles: true }));

    await waitFor(() => {
      expect(location.hash).toMatch(/^#\/create/);
    });

    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));
    const openDialog = document.querySelector('dialog') as HTMLDialogElement;
    expect(openDialog).toHaveAttribute('open');
    fireEvent.click(openDialog);

    await waitFor(() => {
      expect(location.hash).toMatch(/^#\/create/);
    });
    expect(document.querySelector('dialog')).toBeNull();
  });

  it('shows the utility links in a user-focused order', () => {
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    render(<App />);

    const utilityLinks = [
      ...screen.getByLabelText(COPY.utilities).querySelectorAll(':scope .utility-strip__items > a'),
    ].map((link) => link.textContent);
    expect(utilityLinks).toEqual([
      COPY.tryIncludedFeeds,
      COPY.bookmarkletTitle,
      COPY.dockerInstall,
      COPY.openapiSpec,
      COPY.sourceCode,
    ]);

    expect(screen.getByRole('link', { name: COPY.openapiSpec })).toHaveAttribute(
      'href',
      'https://example.test/openapi.yaml'
    );
    expect(screen.getByRole('link', { name: COPY.tryIncludedFeeds })).toHaveAttribute(
      'href',
      'https://html2rss.github.io/feed-directory/#!url=http%3A%2F%2Flocalhost%3A3000%2F'
    );
    expect(screen.getByRole('link', { name: COPY.dockerInstall })).toHaveAttribute(
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
          catalog: { enabled: true, url: '/api/v1/configs' },
        },
      },
      isLoading: false,
      error: undefined,
    });

    history.replaceState({}, '', 'http://localhost:3000/#/create');
    render(<App />);

    expect(screen.getByRole('link', { name: COPY.openapiSpec })).toHaveAttribute(
      'href',
      'http://localhost:3000/openapi.yaml'
    );
  });

  it('shows footer utilities on result routes', async () => {
    history.replaceState({}, '', 'http://localhost:3000/#/result/generated-token');
    render(<App />);

    await waitFor(() => {
      expect(screen.getByLabelText(COPY.utilities)).toBeInTheDocument();
    });
  });
});
