import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { ResultDisplay } from '../components/ResultDisplay';
import { COPY } from '../journey/copy';
import type { AppViewModel } from '../feed';

describe('ResultDisplay', () => {
  const mockOnCreateAnother = vi.fn();
  const mockOnRetryPreview = vi.fn();
  const mockViewModel: Extract<AppViewModel, { kind: 'result' }> = {
    kind: 'result',
    feed: {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com',
      feed_token: 'test-feed-token',
      public_url: 'https://example.com/feed.xml',
      json_public_url: 'https://example.com/feed.json',
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    },
    preview: {
      status: 'preview_ready',
      items: [
        {
          title: 'Item One',
          excerpt: 'First preview item with markup.',
          url: 'https://example.com/item-one',
          publishedLabel: 'Jan 1, 2024',
        },
      ],
      isLoading: false,
    },
    warnings: [],
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders ready feed with Copy as primary CTA and demoted open links', async () => {
    const viewModelWithMultiplePreviewItems = {
      ...mockViewModel,
      preview: {
        status: 'preview_ready' as const,
        items: [
          {
            title: 'Item One',
            excerpt: 'First preview item with markup.',
            url: 'https://example.com/item-one',
            publishedLabel: 'Jan 1, 2024',
          },
          {
            title: 'Item Two',
            excerpt: 'Second preview item with markup.',
            url: 'https://example.com/item-two',
            publishedLabel: 'Jan 2, 2024',
          },
          {
            title: 'Item Three',
            excerpt: 'Third preview item with markup.',
            url: 'https://example.com/item-three',
            publishedLabel: 'Jan 3, 2024',
          },
          {
            title: 'Item Four',
            excerpt: 'Fourth preview item with markup.',
            url: 'https://example.com/item-four',
            publishedLabel: 'Jan 4, 2024',
          },
        ],
        isLoading: false,
      },
    };

    render(
      <ResultDisplay
        viewModel={viewModelWithMultiplePreviewItems}
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'result');
    expect(screen.getByText(COPY.feedReady)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.copyFeedUrl })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: COPY.openFeed })).toHaveClass('btn--ghost');
    expect(screen.getByRole('link', { name: COPY.openJsonFeed })).toHaveAttribute(
      'href',
      'https://example.com/feed.json'
    );
    await waitFor(() => {
      expect(screen.getByText('Item One')).toBeInTheDocument();
      expect(screen.getByText('Item Four')).toBeInTheDocument();
      expect(screen.getByText(COPY.previewLatest)).toBeInTheDocument();
    });
    expect(screen.queryByRole('button', { name: /show all .* items/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Show fewer items' })).not.toBeInTheDocument();
  });

  it('keeps Copy and open actions available while preview loads', () => {
    render(
      <ResultDisplay
        viewModel={{
          ...mockViewModel,
          preview: { status: 'preview_loading', items: [], isLoading: true },
        }}
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    expect(screen.getByText(COPY.feedReady)).toBeInTheDocument();
    expect(screen.getByText(COPY.previewChecking)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.copyFeedUrl })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: COPY.openFeed })).toBeInTheDocument();
  });

  it('lets retryable preview failures retry preview only', () => {
    render(
      <ResultDisplay
        viewModel={{
          ...mockViewModel,
          preview: { status: 'preview_failed', items: [], isLoading: false },
          warnings: [
            {
              code: 'PREVIEW_HTTP_503',
              message: COPY.previewUnavailable,
              retryable: true,
              nextAction: 'retry',
            },
          ],
        }}
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    expect(screen.getByText(COPY.feedReady)).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: COPY.checkAgain }));
    expect(mockOnRetryPreview).toHaveBeenCalled();
  });

  it('calls onCreateAnother and copies feed URL', async () => {
    render(
      <ResultDisplay
        viewModel={mockViewModel}
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    fireEvent.click(screen.getByRole('button', { name: COPY.createAnother }));
    expect(mockOnCreateAnother).toHaveBeenCalled();

    fireEvent.click(screen.getByRole('button', { name: COPY.copyFeedUrl }));
    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('https://example.com/feed.xml');
    });
  });

  it('renders BLOCKED_SURFACE preview warnings from the wire message', () => {
    render(
      <ResultDisplay
        viewModel={{
          ...mockViewModel,
          preview: { status: 'preview_failed', items: [], isLoading: false },
          warnings: [
            {
              code: 'BLOCKED_SURFACE',
              message: 'This website blocked automated access.',
              retryable: false,
              nextAction: 'none',
            },
          ],
        }}
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    expect(screen.getByText('This website blocked automated access.')).toBeInTheDocument();
  });

  it('renders SCRAPER_UNAVAILABLE preview warnings from the wire message', () => {
    render(
      <ResultDisplay
        viewModel={{
          ...mockViewModel,
          preview: { status: 'preview_failed', items: [], isLoading: false },
          warnings: [
            {
              code: 'SCRAPER_UNAVAILABLE',
              message: 'Feed fetching is temporarily unavailable.',
              retryable: true,
              nextAction: 'retry',
            },
          ],
        }}
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    expect(screen.getByText('Feed fetching is temporarily unavailable.')).toBeInTheDocument();
  });
});
