import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { h } from 'preact';
import { App } from '../components/App';

// Mock the hooks
vi.mock('../hooks/useAuth', () => ({
  useAuth: vi.fn(),
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

import { useAuth } from '../hooks/useAuth';
import { useApiMetadata } from '../hooks/useApiMetadata';
import { useFeedConversion } from '../hooks/useFeedConversion';
import { useStrategies } from '../hooks/useStrategies';

const mockUseAuth = useAuth as any;
const mockUseApiMetadata = useApiMetadata as any;
const mockUseFeedConversion = useFeedConversion as any;
const mockUseStrategies = useStrategies as any;

describe('App', () => {
  const mockLogin = vi.fn();
  const mockLogout = vi.fn();
  const mockConvertFeed = vi.fn();
  const mockClearResult = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();

    mockUseAuth.mockReturnValue({
      isAuthenticated: false,
      username: null,
      token: null,
      login: mockLogin,
      logout: mockLogout,
      isLoading: false,
      error: null,
    });

    mockUseApiMetadata.mockReturnValue({
      demo: {
        enabled: true,
        token: 'CHANGE_ME_DEMO_TOKEN',
        strategy: 'ssrf_filter',
        sources: [{ id: 'github-com-trending', url: 'https://github.com/trending' }],
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
      strategies: [],
      isLoading: false,
      error: null,
    });
  });

  it('should render demo section when not authenticated', () => {
    render(<App />);

    expect(screen.getByText('Run a demo source')).toBeInTheDocument();
    expect(screen.getByText('Run a known source. Sign in to submit your own URL.')).toBeInTheDocument();
    expect(screen.getByText('Run demo')).toBeInTheDocument();
  });

  it('should render main content when authenticated', () => {
    mockUseAuth.mockReturnValue({
      isAuthenticated: true,
      username: 'testuser',
      token: 'test-token',
      login: mockLogin,
      logout: mockLogout,
      isLoading: false,
      error: null,
    });

    mockUseStrategies.mockReturnValue({
      strategies: [
        { id: 'ssrf_filter', name: 'ssrf_filter', display_name: 'SSRF Filter' },
        { id: 'browserless', name: 'browserless', display_name: 'Browserless' },
      ],
      isLoading: false,
      error: null,
    });

    render(<App />);

    expect(screen.getByText('testuser')).toBeInTheDocument();
    expect(screen.getByLabelText('URL')).toBeInTheDocument();
    expect(screen.getByText('Advanced: bookmarklet')).toBeInTheDocument();
  });

  it('should call logout when logout button is clicked', () => {
    mockUseAuth.mockReturnValue({
      isAuthenticated: true,
      username: 'testuser',
      token: 'test-token',
      login: mockLogin,
      logout: mockLogout,
      isLoading: false,
      error: null,
    });

    mockUseStrategies.mockReturnValue({
      strategies: [{ id: 'ssrf_filter', name: 'ssrf_filter', display_name: 'SSRF Filter' }],
      isLoading: false,
      error: null,
    });

    render(<App />);

    const logoutButton = screen.getByText('Log out');
    fireEvent.click(logoutButton);

    expect(mockLogout).toHaveBeenCalled();
    expect(mockClearResult).toHaveBeenCalled();
  });

  it('should surface conversion errors to the user', () => {
    mockUseAuth.mockReturnValue({
      isAuthenticated: true,
      username: 'tester',
      token: 'test-token',
      login: mockLogin,
      logout: mockLogout,
      isLoading: false,
      error: null,
    });

    mockUseStrategies.mockReturnValue({
      strategies: [{ id: 'ssrf_filter', name: 'ssrf_filter', display_name: 'SSRF Filter' }],
      isLoading: false,
      error: null,
    });

    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: null,
      error: 'Access Denied',
      convertFeed: mockConvertFeed,
      clearResult: mockClearResult,
    });

    render(<App />);

    expect(screen.getByText('Conversion error')).toBeInTheDocument();
    expect(screen.getByText('Access Denied')).toBeInTheDocument();
  });

  it('should allow guests to trigger sign-in handoff from result screen', async () => {
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
        username: 'guest',
        strategy: 'ssrf_filter',
        feed_token: 'example-token',
        public_url: '/api/v1/feeds/example-token',
      },
      error: null,
      convertFeed: mockConvertFeed,
      clearResult: mockClearResult,
    });

    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));

    await waitFor(() => {
      expect(mockClearResult).toHaveBeenCalled();
    });
  });
});
