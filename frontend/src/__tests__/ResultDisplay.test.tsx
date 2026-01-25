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
    expect(screen.getByText('Your RSS feed is live!')).toBeInTheDocument();
    expect(
      screen.getByText('Drop it straight into your reader or explore the preview without leaving this page.')
    ).toBeInTheDocument();
  });

  it('should call onClose when convert-another button is clicked', () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const resetButton = screen.getByRole('button', { name: 'Convert another website' });
    fireEvent.click(resetButton);

    expect(mockOnClose).toHaveBeenCalled();
  });

  it('should copy feed URL to clipboard when copy button is clicked', async () => {
    render(<ResultDisplay result={mockResult} onClose={mockOnClose} />);

    const copyLinkButton = screen.getByRole('button', { name: 'Copy feed link' });
    fireEvent.click(copyLinkButton);

    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('feed:https://example.com/feed.xml');
    });
  });
});
