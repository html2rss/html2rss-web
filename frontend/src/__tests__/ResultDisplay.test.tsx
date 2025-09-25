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
});
