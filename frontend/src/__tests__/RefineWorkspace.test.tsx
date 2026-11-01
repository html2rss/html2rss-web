import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import { COPY } from '../journey/copy';
import { RefineWorkspace } from '../refine';
import { server } from './mocks/server';

const URL_UNDER_REFINE = 'https://example.com/articles';
const SLOW = { timeout: 3000 };

const candidates = {
  items: [{ selector: 'article', enhance: true, sample: 'First' }],
  title: [{ selector: 'h2', sample: 'First' }],
  link: [{ selector: 'a', sample: '' }],
  published: [],
};

interface Stubs {
  issues?: object[];
  preview?: object;
  suggest?: object | 'fail';
}

function stub({ issues = [], preview, suggest = candidates }: Stubs = {}) {
  const previews: unknown[] = [];
  server.use(
    http.post('/api/v1/refine/suggest_selectors', () =>
      suggest === 'fail'
        ? HttpResponse.json({ success: false, error: { message: 'x' } }, { status: 500 })
        : HttpResponse.json({ success: true, data: { candidates: suggest, strategy: 'botasaurus' } })
    ),
    http.post('/api/v1/refine/validate', () =>
      HttpResponse.json({ success: true, data: { report: { success: issues.length === 0, issues } } })
    ),
    http.post('/api/v1/refine/preview', async ({ request }) => {
      previews.push(await request.json());
      return HttpResponse.json({
        success: true,
        data: preview ?? {
          item_count: 1,
          sample_items: [{ title: 'First post', url: 'https://example.com/1' }],
        },
      });
    })
  );
  return previews;
}

function renderWorkspace(overrides: Partial<Parameters<typeof RefineWorkspace>[0]> = {}) {
  const onSave = vi.fn();
  const onCancel = vi.fn();
  const onAuthFailure = vi.fn();
  render(
    <RefineWorkspace
      url={URL_UNDER_REFINE}
      token="tok"
      isSaving={false}
      onSave={onSave}
      onCancel={onCancel}
      onAuthFailure={onAuthFailure}
      {...overrides}
    />
  );
  return { onSave, onCancel, onAuthFailure };
}

describe('RefineWorkspace', () => {
  it('seeds from the best suggestions, previews, and saves the signed selector shape', async () => {
    const previews = stub();
    const { onSave } = renderWorkspace();

    expect(await screen.findByLabelText(COPY.refineItemsLabel, undefined, SLOW)).toHaveValue('article');
    expect(screen.getByLabelText(COPY.refineTitleLabel)).toHaveValue('h2');
    expect(screen.getByLabelText(COPY.refineLinkLabel)).toHaveValue('a');
    expect(screen.getByLabelText(COPY.refinePublishedLabel)).toHaveValue('');

    expect(await screen.findByText('First post', undefined, SLOW)).toBeInTheDocument();
    expect(previews).toHaveLength(1);
    expect(previews[0]).toMatchObject({ strategy: 'botasaurus' });

    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));
    expect(onSave).toHaveBeenCalledWith({
      items: { selector: 'article', enhance: true },
      title: { selector: 'h2', extractor: 'text' },
      url: { selector: 'a', extractor: 'href' },
    });
  });

  it('lets the person switch automatic details off and previews again', async () => {
    const previews = stub();
    const { onSave } = renderWorkspace();

    const toggle = await screen.findByLabelText(COPY.refineEnhanceLabel, { exact: false }, SLOW);
    expect(toggle).toBeChecked();
    await screen.findByText('First post', undefined, SLOW);

    fireEvent.click(toggle);
    await waitFor(() => expect(previews).toHaveLength(2), SLOW);
    await waitFor(() => expect(screen.getByRole('button', { name: COPY.createFeed })).toBeEnabled(), SLOW);
    fireEvent.click(screen.getByRole('button', { name: COPY.createFeed }));

    expect(onSave).toHaveBeenCalledWith(
      expect.objectContaining({ items: { selector: 'article', enhance: false } })
    );
  });

  it('lists ten items compactly and expands on request', async () => {
    const items = Array.from({ length: 12 }, (_, index) => ({
      title: `Post ${index + 1}`,
      url: `https://example.com/posts/${index + 1}?utm=x`,
      published_at: '2024-01-05T00:00:00Z',
    }));
    stub({ preview: { item_count: 12, sample_items: items } });
    renderWorkspace();

    expect(await screen.findByText('Post 10', undefined, SLOW)).toBeInTheDocument();
    expect(screen.queryByText('Post 11')).not.toBeInTheDocument();
    expect(screen.getAllByText('example.com/posts/1')).toHaveLength(1);

    fireEvent.click(screen.getByRole('button', { name: COPY.refineShowAll(12) }));
    expect(screen.getByText('Post 12')).toBeInTheDocument();
  });

  it('shows a clear loading panel instead of an empty form while reading the page', async () => {
    stub();
    renderWorkspace();

    expect(screen.getByText(COPY.refineSuggesting)).toBeInTheDocument();
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: COPY.createFeed })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.back })).toBeInTheDocument();

    expect(await screen.findByLabelText(COPY.refineItemsLabel, undefined, SLOW)).toBeInTheDocument();
    expect(screen.queryByText(COPY.refineSuggesting)).not.toBeInTheDocument();
  });

  it('moves focus to the chosen item once suggestions arrive', async () => {
    stub();
    renderWorkspace();

    const choice = await screen.findByLabelText(COPY.refineItemsLabel, undefined, SLOW);
    await waitFor(() => expect(choice).toHaveFocus());
  });

  it('shows a plain-language next step instead of schema codes when nothing matches', async () => {
    stub({ preview: { item_count: 0, sample_items: [], failure_kind: 'min_items' } });
    renderWorkspace();

    expect(await screen.findByText(COPY.refineFailureMinItems, undefined, SLOW)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.createFeed })).toBeDisabled();
  });

  it('places validation issues under their field and does not preview', async () => {
    const previews = stub({
      issues: [{ path: ['selectors', 'title', 'selector'], code: 'invalid_value', message: 'is blank' }],
    });
    renderWorkspace();

    expect(await screen.findByText('is blank', undefined, SLOW)).toBeInTheDocument();
    expect(document.querySelector('#refine-title-problems')).toHaveTextContent('is blank');
    expect(previews).toHaveLength(0);
    expect(screen.getByRole('button', { name: COPY.createFeed })).toBeDisabled();
  });

  it('lets a person pick another suggestion', async () => {
    stub({
      suggest: {
        ...candidates,
        items: [
          { selector: 'article', enhance: true, sample: 'First' },
          { selector: 'li.post', enhance: false, sample: 'Other' },
        ],
      },
    });
    renderWorkspace();

    const select = await screen.findByLabelText(COPY.refineItemsLabel, undefined, SLOW);
    fireEvent.change(select, { target: { value: 'li.post' } });

    expect(select).toHaveValue('li.post');
  });

  it('keeps manual editing available when suggestions fail', async () => {
    stub({ suggest: 'fail' });
    renderWorkspace();

    expect(await screen.findByText(COPY.refineSuggestionsFailed, undefined, SLOW)).toBeInTheDocument();
    expect(screen.getByLabelText(COPY.refineItemsLabel)).toBeEnabled();
    expect(screen.getByRole('button', { name: COPY.createFeed })).toBeDisabled();
  });

  it('shows plain copy for a server preview error', async () => {
    stub();
    server.use(
      http.post('/api/v1/refine/preview', () =>
        HttpResponse.json(
          { success: false, error: { code: 'X', message: 'Upstream exploded', kind: 'server' } },
          { status: 500 }
        )
      )
    );
    renderWorkspace();

    expect(await screen.findByText(COPY.refineUnavailable, undefined, SLOW)).toBeInTheDocument();
  });

  it('surfaces a save failure and disables actions while saving', async () => {
    stub();
    renderWorkspace({ saveError: 'Could not save' });
    expect(await screen.findByText('Could not save', undefined, SLOW)).toBeInTheDocument();
  });

  it('disables save and back while saving', async () => {
    stub();
    renderWorkspace({ isSaving: true });

    expect(await screen.findByRole('button', { name: COPY.creating }, SLOW)).toBeDisabled();
    expect(screen.getByRole('button', { name: COPY.back })).toBeDisabled();
  });

  it('goes back', async () => {
    stub();
    const { onCancel } = renderWorkspace();

    fireEvent.click(await screen.findByRole('button', { name: COPY.back }, SLOW));
    expect(onCancel).toHaveBeenCalled();
  });

  it('hands a rejected token during preview to the caller instead of dead-ending', async () => {
    stub();
    server.use(
      http.post('/api/v1/refine/preview', () =>
        HttpResponse.json(
          {
            success: false,
            error: { code: 'UNAUTHORIZED', message: 'nope', kind: 'auth', next_action: 'enter_token' },
          },
          { status: 401 }
        )
      )
    );
    const { onAuthFailure } = renderWorkspace();

    await waitFor(() => expect(onAuthFailure).toHaveBeenCalled(), SLOW);
  });

  it('never shows raw network text and offers to check again', async () => {
    stub();
    server.use(http.post('/api/v1/refine/preview', () => HttpResponse.error()));
    renderWorkspace();

    expect(await screen.findByText(COPY.refineOffline, undefined, SLOW)).toBeInTheDocument();
    expect(screen.queryByText(/failed to fetch/i)).not.toBeInTheDocument();

    server.use(
      http.post('/api/v1/refine/preview', () =>
        HttpResponse.json({
          success: true,
          data: { item_count: 1, sample_items: [{ title: 'Back again', url: 'https://example.com/1' }] },
        })
      )
    );
    fireEvent.click(screen.getByRole('button', { name: COPY.tryAgain }));

    expect(await screen.findByText('Back again', undefined, SLOW)).toBeInTheDocument();
  });

  it('does not let a newer, unchecked draft be saved', async () => {
    stub({
      suggest: {
        ...candidates,
        items: [
          { selector: 'article', enhance: true, sample: 'First' },
          { selector: 'li.post', enhance: false, sample: 'Other' },
        ],
      },
    });
    const { onSave } = renderWorkspace();
    await screen.findByText('First post', undefined, SLOW);

    fireEvent.change(screen.getByLabelText(COPY.refineItemsLabel), { target: { value: 'li.post' } });

    expect(screen.getByRole('button', { name: COPY.createFeed })).toBeDisabled();
    fireEvent.submit(screen.getByRole('button', { name: COPY.createFeed }).closest('form')!);
    expect(onSave).not.toHaveBeenCalled();
    await waitFor(() => expect(screen.getByRole('button', { name: COPY.createFeed })).toBeEnabled(), SLOW);
  });

  it('explains why there is no result yet when suggestions fail', async () => {
    stub({ suggest: 'fail' });
    renderWorkspace();

    expect(await screen.findByRole('button', { name: COPY.createFeed }, SLOW)).toBeDisabled();
    expect(screen.getByText(COPY.refineResultIdle)).toBeVisible();
  });

  it('offers None for the optional date and keeps a custom selector available', async () => {
    stub();
    renderWorkspace();

    const date = await screen.findByLabelText(COPY.refinePublishedLabel, undefined, SLOW);
    expect(date).toHaveValue('');
    fireEvent.change(date, { target: { value: '__custom__' } });

    expect(screen.getByLabelText(COPY.refineCustomSelector(COPY.refinePublishedLabel))).toBeEnabled();
  });
});
