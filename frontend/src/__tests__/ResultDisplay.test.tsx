import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { h } from 'preact';
import { ResultDisplay } from '../components/ResultDisplay';

describe('ResultDisplay', () => {
  const mockOnCreateAnother = vi.fn();
  const mockResult = {
    id: 'test-id',
    name: 'Test Feed',
    url: 'https://example.com',
    strategy: 'ssrf_filter',
    feed_token: 'test-feed-token',
    public_url: 'https://example.com/feed.xml',
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders the simplified result actions', () => {
    render(<ResultDisplay result={mockResult} onCreateAnother={mockOnCreateAnother} />);

    expect(screen.getByText('Feed URL ready')).toBeInTheDocument();
    expect(screen.getByText('Test Feed')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Copy feed URL' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open feed' })).toBeInTheDocument();
  });

  it('calls onCreateAnother when the reset button is clicked', () => {
    render(<ResultDisplay result={mockResult} onCreateAnother={mockOnCreateAnother} />);

    fireEvent.click(screen.getByRole('button', { name: 'Create another feed' }));

    expect(mockOnCreateAnother).toHaveBeenCalled();
  });

  it('copies feed URL to clipboard when copy button is clicked', async () => {
    render(<ResultDisplay result={mockResult} onCreateAnother={mockOnCreateAnother} />);

    fireEvent.click(screen.getByRole('button', { name: 'Copy feed URL' }));

    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('https://example.com/feed.xml');
    });
  });
});
