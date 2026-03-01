import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { h } from 'preact';
import { ResultDisplay } from '../components/ResultDisplay';

describe('ResultDisplay', () => {
  const mockOnClose = vi.fn();
  const mockResult = {
    id: 'test-id',
    name: 'Test Feed',
    url: 'https://example.com',
    username: 'testuser',
    strategy: 'ssrf_filter',
    public_url: 'https://example.com/feed.xml',
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(window, 'fetch').mockResolvedValue({
      text: async () =>
        `<?xml version="1.0"?><rss><channel><title>Example Feed</title><item><title>Item One</title></item></channel></rss>`,
    } as Response);
  });

  it('should render success message and feed details', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    expect(screen.getByText('Feed created')).toBeInTheDocument();
    expect(screen.getByText('Test Feed')).toBeInTheDocument();
    expect(screen.queryByText('Copy the URL or open it in your RSS reader.')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Copy URL' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Subscribe in reader' })).toBeInTheDocument();
    expect(screen.getByText('Opens your default RSS reader if configured.')).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Open feed in new tab' })).not.toBeInTheDocument();
  });

  it('should call onClose when convert-another button is clicked', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const resetButton = screen.getByRole('button', { name: 'Convert another website' });
    fireEvent.click(resetButton);

    expect(mockOnClose).toHaveBeenCalled();
  });

  it('should copy feed URL to clipboard when copy button is clicked', async () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const copyLinkButton = screen.getByRole('button', { name: 'Copy URL' });
    fireEvent.click(copyLinkButton);

    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('https://example.com/feed.xml');
    });
  });

  it('shows sign-in cue for guests and triggers callback', () => {
    const onRequestSignIn = vi.fn();
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} onRequestSignIn={onRequestSignIn} />);

    expect(screen.getByText('Have credentials?')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(onRequestSignIn).toHaveBeenCalled();
  });
});
