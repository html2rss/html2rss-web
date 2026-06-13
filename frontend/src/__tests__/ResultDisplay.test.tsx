import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { ResultDisplay } from '../components/ResultDisplay';

describe('ResultDisplay', () => {
  const mockOnCreateAnother = vi.fn();
  const mockOnRetryPreview = vi.fn();
  const mockResult = {
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
    workflowState: 'preview_ready' as const,
    warnings: [],
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders ready feed actions and preview cards', async () => {
    const resultWithMultiplePreviewItems = {
      ...mockResult,
      preview: {
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
        result={resultWithMultiplePreviewItems}
        workflowState="result"
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'result');
    expect(screen.getByText('Feed ready')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open feed' })).toHaveClass('btn--primary');
    expect(screen.getByRole('link', { name: 'Open JSON Feed' })).toHaveAttribute(
      'href',
      'https://example.com/feed.json'
    );
    await waitFor(() => {
      expect(screen.getByText('Item One')).toBeInTheDocument();
      expect(screen.getByText('Item Four')).toBeInTheDocument();
      expect(screen.getByText('Latest items from this feed')).toBeInTheDocument();
    });
    expect(screen.queryByRole('button', { name: /show all .* items/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Show fewer items' })).not.toBeInTheDocument();
  });

  it('renders preview loading as frontend-owned progress', () => {
    render(
      <ResultDisplay
        result={{
          ...mockResult,
          workflowState: 'preview_loading',
          preview: { items: [], isLoading: true },
        }}
        workflowState="result"
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    expect(screen.getByText('Checking preview')).toBeInTheDocument();
    expect(screen.getByText('Checking preview...')).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Open feed' })).not.toBeInTheDocument();
  });

  it('lets retryable preview failures retry preview only', () => {
    render(
      <ResultDisplay
        result={{
          ...mockResult,
          workflowState: 'preview_failed',
          preview: { items: [], isLoading: false },
          warnings: [
            {
              code: 'PREVIEW_HTTP_503',
              message: 'Preview content is partially degraded right now.',
              retryable: true,
              nextAction: 'retry',
            },
          ],
        }}
        workflowState="result"
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    expect(screen.getByText('Feed link created')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Check again' }));
    expect(mockOnRetryPreview).toHaveBeenCalled();
  });

  it('calls onCreateAnother and copies feed URL', async () => {
    render(
      <ResultDisplay
        result={mockResult}
        workflowState="result"
        onCreateAnother={mockOnCreateAnother}
        onRetryPreview={mockOnRetryPreview}
      />
    );

    fireEvent.click(screen.getByRole('button', { name: 'Create another feed' }));
    expect(mockOnCreateAnother).toHaveBeenCalled();

    fireEvent.click(screen.getByRole('button', { name: 'Copy feed URL' }));
    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('https://example.com/feed.xml');
    });
  });
});
