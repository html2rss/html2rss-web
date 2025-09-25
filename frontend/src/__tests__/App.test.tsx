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

import { useAuth } from '../hooks/useAuth';
import { useFeedConversion } from '../hooks/useFeedConversion';

const mockUseAuth = useAuth as any;
const mockUseFeedConversion = useFeedConversion as any;

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
  });

  it('should render demo section when not authenticated', () => {
    render(<App />);

    expect(screen.getByText('🚀 Try It Out')).toBeInTheDocument();
    expect(
      screen.getByText(
        'Click any button below to instantly convert these websites to RSS feeds - no signup required!'
      )
    ).toBeInTheDocument();
    expect(screen.getByText('Sign in here')).toBeInTheDocument();
  });

  it('should render main content when authenticated', () => {
    mockUseAuth.mockReturnValue({
      isAuthenticated: true,
      username: 'testuser',
      login: mockLogin,
      logout: mockLogout,
    });

    render(<App />);

    expect(screen.getByText('Welcome, testuser!')).toBeInTheDocument();
    expect(screen.getByText('🌐 Convert Website')).toBeInTheDocument();
    expect(screen.getByText('Enter the URL of the website you want to convert to RSS')).toBeInTheDocument();
  });

  it('should call logout when logout button is clicked', () => {
    mockUseAuth.mockReturnValue({
      isAuthenticated: true,
      username: 'testuser',
      login: mockLogin,
      logout: mockLogout,
    });

    render(<App />);

    const logoutButton = screen.getByText('Logout');
    fireEvent.click(logoutButton);

    expect(mockLogout).toHaveBeenCalled();
    expect(mockClearResult).toHaveBeenCalled();
  });

  it('should surface conversion errors to the user', () => {
    mockUseAuth.mockReturnValue({
      isAuthenticated: true,
      username: 'tester',
      login: mockLogin,
      logout: mockLogout,
    });

    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: null,
      error: 'Access Denied',
      convertFeed: mockConvertFeed,
      clearResult: mockClearResult,
    });

    render(<App />);

    expect(screen.getByText('❌ Error')).toBeInTheDocument();
    expect(screen.getByText('Access Denied')).toBeInTheDocument();
  });

});
