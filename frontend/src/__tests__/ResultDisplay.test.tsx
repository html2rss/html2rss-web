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
  });

  it('should render success message and feed details', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    expect(screen.getByText('🎉')).toBeInTheDocument();
    expect(screen.getByText('Feed Generated Successfully!')).toBeInTheDocument();
    expect(screen.getByText('Your RSS feed is ready to use')).toBeInTheDocument();
  });

  it('should call onClose when close button is clicked', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const closeButton = screen.getByText('Close');
    fireEvent.click(closeButton);

    expect(mockOnClose).toHaveBeenCalled();
  });

  it('should copy feed URL to clipboard when copy button is clicked', async () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const copyButton = screen.getByText('📋');
    fireEvent.click(copyButton);

    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('feed:https://example.com/feed.xml');
    });
  });

  it('should copy feed protocol URL when copy feed button is clicked', async () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const copyFeedButton = screen.getByText('📋');
    fireEvent.click(copyFeedButton);

    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('feed:https://example.com/feed.xml');
    });
  });

  it('should render RSS readers list', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    expect(screen.getByText('Works with:')).toBeInTheDocument();
    expect(screen.getByText('Feedly')).toBeInTheDocument();
    expect(screen.getByText('Inoreader')).toBeInTheDocument();
    expect(screen.getByText('Thunderbird')).toBeInTheDocument();
    expect(screen.getByText('Apple News')).toBeInTheDocument();
  });

  it('should render XML preview section', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    expect(screen.getByText('📄 RSS Feed Preview')).toBeInTheDocument();
    expect(screen.getByText('Show Raw XML')).toBeInTheDocument();
  });

  it('should toggle XML view when toggle button is clicked', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const toggleButton = screen.getByText('Show Raw XML');
    fireEvent.click(toggleButton);

    expect(screen.getByText('Show Styled Preview')).toBeInTheDocument();
  });

  it('should render subscribe button with correct link', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const subscribeButton = screen.getByText('📰');
    expect(subscribeButton.closest('a')).toHaveAttribute('href', 'feed:https://example.com/feed.xml');
    expect(subscribeButton.closest('a')).toHaveAttribute('target', '_blank');
    expect(subscribeButton.closest('a')).toHaveAttribute('rel', 'noopener');
  });

  it('should render open feed button with correct link', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const openButton = screen.getByText('🔗 Open in New Tab');
    expect(openButton.closest('a')).toHaveAttribute('href', 'https://example.com/feed.xml');
    expect(openButton.closest('a')).toHaveAttribute('target', '_blank');
    expect(openButton.closest('a')).toHaveAttribute('rel', 'noopener');
  });

  it('should handle clipboard error gracefully', async () => {
    (navigator.clipboard.writeText as any).mockRejectedValueOnce(new Error('Clipboard error'));

    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const copyButton = screen.getByText('📋');
    fireEvent.click(copyButton);

    // Should not throw error
    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalled();
    });
  });
});
