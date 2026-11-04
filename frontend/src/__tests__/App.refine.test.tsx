import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import type { FeedCreationError } from '../api/contracts';
import { App } from '../components/App';
import { COPY } from '../journey/copy';
import { server } from './mocks/server';

vi.mock('../session/accessToken', () => ({
  useAccessToken: vi.fn(),
  resetAccessTokenMemory: vi.fn(),
}));
vi.mock('../feed/useFeedCreation', () => ({ useFeedCreation: vi.fn() }));
vi.mock('../hooks/useApiMetadata', () => ({ useApiMetadata: vi.fn() }));
vi.mock('../catalog/useCatalogEntries', () => ({
  useCatalogEntries: vi.fn(() => ({ entries: [], starters: [] })),
}));

import { useAccessToken } from '../session/accessToken';
import { useApiMetadata } from '../hooks/useApiMetadata';
import { useFeedCreation } from '../feed/useFeedCreation';

const mockUseAccessToken = useAccessToken as any;
const mockUseApiMetadata = useApiMetadata as any;
const mockUseFeedCreation = useFeedCreation as any;

const SLOW = { timeout: 3000 };
const PAGE = 'https://example.com/articles';

const createdFeed = (token: string) => ({
  feed: {
    id: 'feed-1',
    name: 'Example Feed',
    url: PAGE,
    feed_token: token,
    public_url: `/api/v1/feeds/${token}`,
    json_public_url: `/api/v1/feeds/${token}.json`,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  },
  preview: { status: 'created' as const, items: [], isLoading: false },
  warnings: [],
});

const emptyExtraction: FeedCreationError = {
  kind: 'input',
  code: 'EXTRACTION_EMPTY',
  retryable: false,
  nextAction: 'correct_input',
  retryAction: 'none',
  message: 'No items found',
};

function stubRefineApi(suggestedUrls: unknown[] = []) {
  server.use(
    http.post('/api/v1/refine/suggest_selectors', async ({ request }) => {
      suggestedUrls.push(((await request.json()) as { url?: unknown }).url);
      return HttpResponse.json({
        success: true,
        data: {
          candidates: {
            items: [{ selector: 'article', enhance: false, sample: 'A' }],
            title: [],
            link: [],
            published: [],
          },
        },
      });
    }),
    http.post('/api/v1/refine/validate', () =>
      HttpResponse.json({ success: true, data: { report: { success: true, issues: [] } } })
    ),
    http.post('/api/v1/refine/preview', () =>
      HttpResponse.json({
        success: true,
        data: { item_count: 1, sample_items: [{ title: 'First post', url: 'https://example.com/1' }] },
      })
    )
  );
}

describe('App Refine entry points', () => {
  const mockCreateFeed = vi.fn();
  let hookResult: ReturnType<typeof createdFeed> | undefined;
  let hookError: FeedCreationError | undefined;

  function setup({
    token = 'tok' as string | false,
    refine = { enabled: true } as false | { enabled: boolean },
  } = {}) {
    mockUseAccessToken.mockReturnValue({
      token: token || undefined,
      hasToken: token !== false,
      saveToken: vi.fn(),
      clearToken: vi.fn(),
      isLoading: false,
      error: undefined,
    });
    mockUseApiMetadata.mockReturnValue({
      metadata: {
        api: { name: 'html2rss-web API', description: '', openapi_url: 'https://example.test/openapi.yaml' },
        instance: {
          feed_creation: { enabled: true, access_token_required: false },
          ...(refine && { refine }),
          catalog: { enabled: true, url: '/api/v1/configs' },
        },
      },
      isLoading: false,
      error: undefined,
    });
  }

  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    hookResult = undefined;
    hookError = undefined;
    mockCreateFeed.mockResolvedValue(createdFeed('refined-token'));
    mockUseFeedCreation.mockImplementation(() => ({
      isCreating: false,
      result: hookResult,
      error: hookError,
      createFeed: async (url: string, token: string, selectors?: unknown) => {
        try {
          return await mockCreateFeed(url, token, selectors);
        } catch (error) {
          hookError = error as FeedCreationError;
          throw error;
        }
      },
      clearError: vi.fn(() => {
        hookError = undefined;
      }),
      clearResult: vi.fn(),
      retryPreviewFetch: vi.fn(),
    }));
    stubRefineApi();
  });

  function openResult() {
    hookResult = createdFeed('generated-token');
    history.replaceState({}, '', 'http://localhost:3000/#/result/generated-token');
  }

  async function renderEmptyExtraction() {
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    mockCreateFeed.mockRejectedValue(emptyExtraction);
    render(<App />);
    fireEvent.input(screen.getByLabelText(COPY.urlLabel), { target: { value: PAGE } });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));
    await screen.findByText(COPY.createFailedTitle);
  }

  it('offers Refine on a ready result to a token holder and returns on back', async () => {
    setup();
    openResult();
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: COPY.refineEntry }));
    expect(await screen.findByRole('heading', { name: COPY.refineTitle })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: COPY.refineEntry })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: COPY.back }));
    expect(await screen.findByRole('button', { name: COPY.refineEntry })).toBeInTheDocument();
  });

  it.each([
    ['guests', { token: false }],
    ['instances without Refine', { refine: false }],
    ['instances with Refine disabled', { refine: { enabled: false } }],
  ])('shows no selector controls on a result for %s', (_label, options) => {
    setup(options);
    openResult();
    render(<App />);

    expect(screen.getByText(COPY.feedReady)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: COPY.refineEntry })).not.toBeInTheDocument();
  });

  it('offers Refine after an empty extraction and opens it for the typed URL', async () => {
    const suggestedUrls: unknown[] = [];
    setup();
    stubRefineApi(suggestedUrls);
    await renderEmptyExtraction();

    fireEvent.click(screen.getByRole('button', { name: COPY.refineEntryEmpty }));

    expect(await screen.findByRole('heading', { name: COPY.refineTitle })).toBeInTheDocument();
    await waitFor(() => expect(suggestedUrls).toEqual([PAGE]));
  });

  it('does not offer Refine after an empty extraction to guests', async () => {
    setup({ token: false });
    await renderEmptyExtraction();

    expect(screen.queryByRole('button', { name: COPY.refineEntryEmpty })).not.toBeInTheDocument();
  });

  it('does not offer Refine for other create failures', async () => {
    setup();
    history.replaceState({}, '', 'http://localhost:3000/#/create');
    mockCreateFeed.mockRejectedValue({ ...emptyExtraction, code: 'BLOCKED_SURFACE' });
    render(<App />);
    fireEvent.input(screen.getByLabelText(COPY.urlLabel), { target: { value: PAGE } });
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));
    await screen.findByText(COPY.createFailedTitle);

    expect(screen.queryByRole('button', { name: COPY.refineEntryEmpty })).not.toBeInTheDocument();
  });

  it('saves refined selectors as a new feed and lands on its result', async () => {
    setup();
    openResult();
    render(<App />);
    fireEvent.click(screen.getByRole('button', { name: COPY.refineEntry }));

    await screen.findByText('First post', undefined, SLOW);
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    await waitFor(() =>
      expect(mockCreateFeed).toHaveBeenCalledWith(PAGE, 'tok', {
        items: { selector: 'article', enhance: false },
      })
    );
    await waitFor(() => expect(location.hash).toBe('#/result/refined-token'));
  });

  it('keeps the workspace open and explains a save failure', async () => {
    setup();
    openResult();
    mockCreateFeed.mockRejectedValue({ ...emptyExtraction, kind: 'server', message: 'Disk full' });
    render(<App />);
    fireEvent.click(screen.getByRole('button', { name: COPY.refineEntry }));

    await screen.findByText('First post', undefined, SLOW);
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    expect(await screen.findByText('Disk full')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: COPY.refineTitle })).toBeInTheDocument();
  });
});
