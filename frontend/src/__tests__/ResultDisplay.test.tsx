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
    strategy: 'faraday',
    feed_token: 'test-feed-token',
    public_url: 'https://example.com/feed.xml',
    json_public_url: 'https://example.com/feed.json',
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(window, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({
        items: [
          {
            title: 'Item One',
            content_text: '<p>First preview item with <strong>markup</strong>.</p>',
            url: 'https://example.com/item-one',
            date_published: '2024-01-01T00:00:00Z',
          },
          {
            content_text: '56 points by canpan 1 hour ago | hide | 18&nbsp;comments',
            date_published: '2024-01-02T00:00:00Z',
          },
          {
            content_text: '2. Item Two ( example.com )',
            url: 'https://example.com/item-two',
            date_published: '2024-01-03T00:00:00Z',
          },
        ],
      }),
    } as Response);
  });

  it('renders the success state actions and richer preview cards', async () => {
    render(<ResultDisplay result={mockResult} onCreateAnother={mockOnCreateAnother} />);

    expect(screen.getByText('Your feed is ready')).toBeInTheDocument();
    expect(screen.getByText('Test Feed')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Copy feed URL' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open feed' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open JSON Feed' })).toHaveAttribute(
      'href',
      'https://example.com/feed.json'
    );
    await waitFor(() => {
      expect(screen.getByText('Item One')).toBeInTheDocument();
      expect(screen.getByText('First preview item with markup.')).toBeInTheDocument();
      expect(screen.getAllByText('Open original')).toHaveLength(2);
      expect(screen.getByText(/points by canpan/i)).toBeInTheDocument();
      expect(screen.getByText('Item Two')).toBeInTheDocument();
      expect(screen.getByText('Latest items from this feed')).toBeInTheDocument();
    });
    expect(window.fetch).toHaveBeenCalledWith('https://example.com/feed.xml', {
      headers: { Accept: 'application/feed+json' },
    });
  });

  it('surfaces preview fetch failures as a result-state message', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: false,
      json: async () => ({}),
    } as Response);

    render(<ResultDisplay result={mockResult} onCreateAnother={mockOnCreateAnother} />);

    await waitFor(() => {
      expect(screen.getByText('Preview unavailable right now.')).toBeInTheDocument();
      expect(screen.getByText('Latest items from this feed')).toBeInTheDocument();
    });
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
