import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/preact';
import { ResultDisplay } from '../components/ResultDisplay';
import { COPY } from '../journey/copy';
import type { AppViewModel } from '../feed';

describe('ResultDisplay', () => {
  const onCreateAnother = vi.fn();
  const onRetryPreview = vi.fn();
  const ready: Extract<AppViewModel, { kind: 'result'; phase: 'ready' }> = {
    kind: 'result',
    phase: 'ready',
    feed: {
      id: 'test-id',
      name: 'Test Feed',
      url: 'https://example.com',
      feed_token: 'test-feed-token',
      public_url: 'https://example.com/feed.xml',
      json_public_url: 'https://example.com/feed.json',
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

  it('renders ready feed with Copy primary, demoted opens, and grid meadow', async () => {
    render(
      <ResultDisplay viewModel={ready} onCreateAnother={onCreateAnother} onRetryPreview={onRetryPreview} />
    );

    expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'ready');
    expect(screen.getByText(COPY.feedReady)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.copyFeedUrl })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: COPY.openFeed })).toHaveClass('btn--ghost');
    expect(screen.getByRole('link', { name: COPY.openJsonFeed })).toHaveAttribute(
      'href',
      'https://example.com/feed.json'
    );
    await waitFor(() => {
      expect(screen.getByText('Item One')).toBeInTheDocument();
      expect(screen.getByText(COPY.previewItemCount(1))).toBeInTheDocument();
      expect(document.querySelector('.ui-item-list--grid')).toBeTruthy();
    });
  });

  it('keeps Copy while preview loads and surfaces preview warnings', () => {
    const { rerender } = render(
      <ResultDisplay
        viewModel={{
          ...ready,
          preview: { status: 'preview_loading', items: [], isLoading: true },
        }}
        onCreateAnother={onCreateAnother}
        onRetryPreview={onRetryPreview}
      />
    );

    expect(screen.getByText(COPY.previewChecking)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.copyFeedUrl })).toBeInTheDocument();

    rerender(
      <ResultDisplay
        viewModel={{
          ...ready,
          preview: { status: 'preview_failed', items: [], isLoading: false },
          warnings: [
            {
              code: 'PREVIEW_HTTP_422',
              message: 'This site blocked automated access. Try another URL or site.',
              retryable: false,
              nextAction: 'wait',
            },
          ],
        }}
        onCreateAnother={onCreateAnother}
        onRetryPreview={onRetryPreview}
      />
    );
    expect(
      screen.getByText('This site blocked automated access. Try another URL or site.')
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: COPY.checkAgain })).not.toBeInTheDocument();

    rerender(
      <ResultDisplay
        viewModel={{
          ...ready,
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
        onCreateAnother={onCreateAnother}
        onRetryPreview={onRetryPreview}
      />
    );
    fireEvent.click(screen.getByRole('button', { name: COPY.checkAgain }));
    expect(onRetryPreview).toHaveBeenCalled();
  });

  it('copies from the action, ignores Enter on the feed URL, and surfaces clipboard failure', async () => {
    render(
      <ResultDisplay viewModel={ready} onCreateAnother={onCreateAnother} onRetryPreview={onRetryPreview} />
    );

    fireEvent.click(screen.getByRole('button', { name: COPY.createAnother }));
    expect(onCreateAnother).toHaveBeenCalled();

    fireEvent.keyDown(screen.getByLabelText(COPY.feedUrl), { key: 'Enter' });
    expect(navigator.clipboard.writeText).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole('button', { name: COPY.copyFeedUrl }));
    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith('https://example.com/feed.xml');
    });

    vi.mocked(navigator.clipboard.writeText).mockRejectedValueOnce(new Error('denied'));
    fireEvent.click(screen.getByRole('button', { name: COPY.copyFeedUrl }));
    await waitFor(() => {
      expect(document.querySelector('[data-clipboard="failed"]')).toBeTruthy();
    });
    expect(screen.getByLabelText(COPY.feedUrl)).toHaveValue('https://example.com/feed.xml');
  });

  it('mounts authenticated studio for ready results, focuses Copy, and hides controls without studio', async () => {
    const { rerender } = render(
      <ResultDisplay
        viewModel={ready}
        onCreateAnother={onCreateAnother}
        onRetryPreview={onRetryPreview}
        studio={{
          token: 'token-1',
          url: 'https://example.com',
          onGenerate: vi.fn(async () => {}),
        }}
      />
    );

    const copyFeedUrl = screen.getByRole('button', { name: COPY.copyFeedUrl });
    expect(document.querySelector('details')).toBeNull();
    expect(screen.getByLabelText(COPY.itemsSelector)).toBeInTheDocument();
    expect(document.querySelectorAll('.ui-item-list')).toHaveLength(1);
    expect(document.querySelector('.ui-item-list--grid')).toBeTruthy();
    expect(screen.getByRole('button', { name: COPY.saveAndGenerate })).toHaveClass('btn--ghost');
    expect(screen.getByRole('link', { name: COPY.proposeDirectory })).toBeInTheDocument();
    await waitFor(() => {
      expect(document.activeElement).toBe(copyFeedUrl);
    });

    rerender(
      <ResultDisplay viewModel={ready} onCreateAnother={onCreateAnother} onRetryPreview={onRetryPreview} />
    );
    expect(screen.queryByLabelText(COPY.itemsSelector)).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.createAnother })).toBeInTheDocument();
  });

  it('renders unresolved workspace with one Decision notice and open studio', () => {
    const notice = 'We could not extract feed items from this page yet.';
    render(
      <ResultDisplay
        viewModel={{
          kind: 'result',
          phase: 'unresolved',
          url: 'https://example.com/articles',
          notice,
        }}
        onCreateAnother={onCreateAnother}
        onRetryPreview={onRetryPreview}
        studio={{
          token: 'token-1',
          url: 'https://example.com/articles',
          onGenerate: vi.fn(async () => {}),
        }}
      />
    );

    expect(document.querySelector('.result-shell')).toHaveAttribute('data-state', 'unresolved');
    expect(screen.getByText('https://example.com/articles')).toBeInTheDocument();
    expect(screen.getAllByText(notice)).toHaveLength(1);
    expect(screen.queryByText(COPY.feedReady)).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: COPY.copyFeedUrl })).not.toBeInTheDocument();
    expect(screen.getByLabelText(COPY.itemsSelector)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.saveAndGenerate })).toHaveClass('btn--primary');
    expect(document.querySelector('.studio-suggestion-status')).toBeTruthy();
  });
});
