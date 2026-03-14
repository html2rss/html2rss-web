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
  const mockClearResult = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();

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
          openapi_url: 'http://example.test/api/v1/openapi.yaml',
        },
        instance: {
          feed_creation: {
            enabled: true,
            access_token_required: true,
          },
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
      clearResult: mockClearResult,
    });

    mockUseStrategies.mockReturnValue({
      strategies: [
        { id: 'ssrf_filter', name: 'ssrf_filter', display_name: 'Standard (recommended)' },
        { id: 'browserless', name: 'browserless', display_name: 'JavaScript pages' },
      ],
      isLoading: false,
      error: null,
    });
  });

  it('renders the streamlined hero and create section', () => {
    render(<App />);

    expect(screen.getByText('Turn web pages into stable feeds.')).toBeInTheDocument();
    expect(screen.getByText('Create a feed')).toBeInTheDocument();
    expect(screen.getByText('Run your own instance')).toBeInTheDocument();
  });

  it('shows inline token prompt when submitting without a token', () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText('Source URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));

    expect(screen.getByText('Unlock custom feed creation')).toBeInTheDocument();
    expect(mockConvertFeed).not.toHaveBeenCalled();
  });

  it('renders the result panel when a feed is available', async () => {
    vi.spyOn(window, 'fetch').mockResolvedValue({
      text: async () =>
        `<?xml version="1.0"?><rss><channel><title>Example Feed</title><item><title>Item One</title></item></channel></rss>`,
    } as Response);

    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: {
        id: 'feed-123',
        name: 'Example Feed',
        url: 'https://example.com/articles',
        strategy: 'ssrf_filter',
        feed_token: 'example-token',
        public_url: '/api/v1/feeds/example-token',
      },
      error: null,
      convertFeed: mockConvertFeed,
      clearResult: mockClearResult,
    });

    render(<App />);

    expect(screen.getByText('Ready')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Create another feed' })).toBeInTheDocument();
    expect(screen.queryByText('Run your own instance')).not.toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText('Example Feed')).toBeInTheDocument();
    });
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

    fireEvent.click(screen.getByRole('button', { name: 'Clear token' }));

    expect(mockClearToken).toHaveBeenCalled();
  });

  it('saves access token from the inline prompt', async () => {
    render(<App />);

    fireEvent.input(screen.getByLabelText('Source URL'), {
      target: { value: 'https://example.com/articles' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Generate feed URL' }));
    const accessTokenInput = document.getElementById('access-token') as HTMLInputElement;
    fireEvent.input(accessTokenInput, { target: { value: 'token-123' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save token' }));

    await waitFor(() => {
      expect(mockSaveToken).toHaveBeenCalledWith('token-123');
    });
  });
});
