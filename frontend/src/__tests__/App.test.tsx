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
    expect(screen.getByText('🔐 Full Access')).toBeInTheDocument();
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

  it('should render result when available', () => {
    const mockResult = {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com',
      username: 'testuser',
      strategy: 'ssrf_filter',
      public_url: 'https://example.com/feed.xml',
    };

    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: mockResult,
      error: null,
      convertFeed: mockConvertFeed,
      clearResult: mockClearResult,
    });

    render(<App />);

    expect(screen.getByText('🎉')).toBeInTheDocument();
    expect(screen.getByText('Feed Generated Successfully!')).toBeInTheDocument();
    expect(screen.getByText('Your RSS feed is ready to use')).toBeInTheDocument();
  });

  it('should render error when available', () => {
    mockUseFeedConversion.mockReturnValue({
      isConverting: false,
      result: null,
      error: 'Test error message',
      convertFeed: mockConvertFeed,
      clearResult: mockClearResult,
    });

    render(<App />);

    expect(screen.getByText('❌ Error')).toBeInTheDocument();
    expect(screen.getByText('Test error message')).toBeInTheDocument();
  });

  it('should handle demo conversion', async () => {
    render(<App />);

    // Find a demo button and click it
    const demoButtons = screen.getAllByRole('button');
    const demoButton = demoButtons.find(
      (button) =>
        button.textContent?.includes('Chip Testberichte') ||
        button.textContent?.includes('Hacker News') ||
        button.textContent?.includes('GitHub Trending')
    );

    if (demoButton) {
      fireEvent.click(demoButton);

      await waitFor(() => {
        expect(mockConvertFeed).toHaveBeenCalledWith(
          expect.any(String),
          expect.any(String),
          'ssrf_filter',
          'self-host-for-full-access'
        );
      });
    }
  });
});
