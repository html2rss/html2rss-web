import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { h } from 'preact';
import { ResultDisplay } from '../components/ResultDisplay';

describe('ResultDisplay', () => {
  const mockOnCreateAnother = vi.fn();
  const mockResult = {
    feed: {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com',
      strategy: 'faraday',
      feed_token: 'test-feed-token',
      public_url: 'https://example.com/feed.xml',
      json_public_url: 'https://example.com/feed.json',
    },
    preview: {
      items: [
        {
          title: 'Item One',
          excerpt: 'First preview item with markup.',
          url: 'https://example.com/item-one',
          publishedLabel: 'Jan 1, 2024',
        },
        {
          title: '56 points by canpan 1 hour ago | hide | 18 comments',
          excerpt: '',
          publishedLabel: 'Jan 2, 2024',
        },
        {
          title: 'Item Two',
          excerpt: '',
          url: 'https://example.com/item-two',
          publishedLabel: 'Jan 3, 2024',
        },
      ],
      error: null,
      isLoading: false,
    },
    retry: null,
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders the success state actions and richer preview cards', async () => {
    render(<ResultDisplay result={mockResult} onCreateAnother={mockOnCreateAnother} />);

    expect(screen.getByText('Your feed is ready')).toBeInTheDocument();
    expect(screen.getByText('Test Feed')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Copy feed URL' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Subscribe in reader' })).toHaveAttribute(
      'href',
      'feed:https://example.com/feed.xml'
    );
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
  });

  it('surfaces preview failures as a result-state message', async () => {
    render(
      <ResultDisplay
        result={{
          ...mockResult,
          preview: { items: [], error: 'Preview unavailable right now.', isLoading: false },
        }}
        onCreateAnother={mockOnCreateAnother}
      />
    );

    await waitFor(() => {
      expect(screen.getByText('Preview unavailable right now.')).toBeInTheDocument();
      expect(screen.getByText('Latest items from this feed')).toBeInTheDocument();
    });
  });

  it('keeps the result state visible while preview is still loading', async () => {
    render(
      <ResultDisplay
        result={{ ...mockResult, preview: { items: [], error: null, isLoading: true } }}
        onCreateAnother={mockOnCreateAnother}
      />
    );

    await waitFor(() => {
      expect(screen.getByText('Your feed is ready')).toBeInTheDocument();
      expect(screen.getByRole('link', { name: 'Open feed' })).toBeInTheDocument();
      expect(screen.getByText('Loading preview…')).toBeInTheDocument();
    });
  });

  it('shows an automatic retry notice when fallback strategy succeeded', async () => {
    render(
      <ResultDisplay
        result={{
          ...mockResult,
          retry: { automatic: true, from: 'faraday', to: 'browserless' },
        }}
        onCreateAnother={mockOnCreateAnother}
      />
    );

    await waitFor(() => {
      expect(
        screen.getByText('Retried automatically with browserless after faraday could not finish the page.')
      ).toBeInTheDocument();
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
