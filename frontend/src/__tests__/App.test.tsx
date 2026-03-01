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

vi.mock('../hooks/useStrategies', () => ({
  useStrategies: vi.fn(),
}));

import { useAuth } from '../hooks/useAuth';
import { useFeedConversion } from '../hooks/useFeedConversion';
import { useStrategies } from '../hooks/useStrategies';

const mockUseAuth = useAuth as any;
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
      login: mockLogin,
      logout: mockLogout,
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

    expect(screen.getByText('Convert website to RSS')).toBeInTheDocument();
    expect(screen.getByText('Try a demo source instantly. Sign in to convert your own URLs.')).toBeInTheDocument();
    expect(screen.getByText('Run demo')).toBeInTheDocument();
  });

  it('should render main content when authenticated', () => {
    mockUseAuth.mockReturnValue({
      isAuthenticated: true,
      username: 'testuser',
      token: 'test-token',
      login: mockLogin,
      logout: mockLogout,
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
    expect(screen.getByRole('heading', { name: 'Convert' })).toBeInTheDocument();
    expect(screen.getByLabelText('URL')).toBeInTheDocument();
  });

  it('should call logout when logout button is clicked', () => {
    mockUseAuth.mockReturnValue({
      isAuthenticated: true,
      username: 'testuser',
      token: 'test-token',
      login: mockLogin,
      logout: mockLogout,
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
});
