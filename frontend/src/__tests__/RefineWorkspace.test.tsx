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
        : HttpResponse.json({ success: true, data: { candidates: suggest } })
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

    expect(await screen.findByRole('radio', { name: /article/ }, SLOW)).toBeChecked();
    expect(screen.getByRole('radio', { name: /h2/ })).toBeChecked();
    expect(screen.getByRole('radio', { name: /^a\b/ })).toBeChecked();
    expect(screen.getByRole('radio', { name: COPY.refineNone })).toBeChecked();

    expect(await screen.findByText('First post', undefined, SLOW)).toBeInTheDocument();
    expect(previews).toHaveLength(1);

    fireEvent.click(screen.getByRole('button', { name: COPY.refineSave }));
    expect(onSave).toHaveBeenCalledWith({
      items: { selector: 'article', enhance: true },
      title: { selector: 'h2', extractor: 'text' },
      url: { selector: 'a', extractor: 'href' },
    });
  });

  it('shows a clear loading panel instead of an empty form while reading the page', async () => {
    stub();
    renderWorkspace();

    expect(screen.getByText(COPY.refineSuggesting)).toBeInTheDocument();
    expect(screen.queryByRole('radio')).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: COPY.refineSave })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.back })).toBeInTheDocument();

    expect(await screen.findByRole('radio', { name: /article/ }, SLOW)).toBeInTheDocument();
    expect(screen.queryByText(COPY.refineSuggesting)).not.toBeInTheDocument();
  });

  it('moves focus to the chosen item once suggestions arrive', async () => {
    stub();
    renderWorkspace();

    const choice = await screen.findByRole('radio', { name: /article/ }, SLOW);
    await waitFor(() => expect(choice).toHaveFocus());
  });

  it('shows a plain-language next step instead of schema codes when nothing matches', async () => {
    stub({ preview: { item_count: 0, sample_items: [], failure_kind: 'min_items' } });
    renderWorkspace();

    expect(await screen.findByText(COPY.refineFailureTitleMinItems, undefined, SLOW)).toBeInTheDocument();
    expect(screen.getByText(COPY.refineFailureMinItems)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: COPY.refineSave })).toBeDisabled();
  });

  it('places validation issues under their field and does not preview', async () => {
    const previews = stub({
      issues: [{ path: ['selectors', 'title', 'selector'], code: 'invalid_value', message: 'is blank' }],
    });
    renderWorkspace();

    expect(
      await screen.findByText(`${COPY.refineTitleLabel}: is blank`, undefined, SLOW)
    ).toBeInTheDocument();
    expect(document.querySelector('#refine-title-problems')).toHaveTextContent('is blank');
    expect(previews).toHaveLength(0);
    expect(screen.getByRole('button', { name: COPY.refineSave })).toBeDisabled();
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

    fireEvent.click(await screen.findByRole('radio', { name: /li\.post/ }, SLOW));

    expect(screen.getByRole('radio', { name: /li\.post/ })).toBeChecked();
    expect(screen.getByText(COPY.refineSuggested)).toBeInTheDocument();
  });

  it('keeps manual editing available when suggestions fail', async () => {
    stub({ suggest: 'fail' });
    renderWorkspace();

    expect(await screen.findByText(COPY.refineSuggestionsFailed, undefined, SLOW)).toBeInTheDocument();
    expect(screen.getByLabelText(COPY.refineCustomSelector(COPY.refineItemsLabel))).toBeEnabled();
    expect(screen.getByRole('button', { name: COPY.refineSave })).toBeDisabled();
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

    expect(await screen.findByRole('button', { name: COPY.refineSaving }, SLOW)).toBeDisabled();
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
    fireEvent.click(screen.getByRole('button', { name: COPY.refineRecheck }));

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

    fireEvent.click(screen.getByRole('radio', { name: /li\.post/ }));

    expect(screen.getByRole('button', { name: COPY.refineSave })).toBeDisabled();
    fireEvent.submit(screen.getByRole('button', { name: COPY.refineSave }).closest('form')!);
    expect(onSave).not.toHaveBeenCalled();
    await waitFor(() => expect(screen.getByRole('button', { name: COPY.refineSave })).toBeEnabled(), SLOW);
  });

  it('explains why Save is unavailable while the item selector is blank', async () => {
    stub({ suggest: 'fail' });
    renderWorkspace();

    const hint = await screen.findByText(COPY.refineItemsHint, undefined, SLOW);
    expect(screen.getByRole('button', { name: COPY.refineSave })).toHaveAttribute(
      'aria-describedby',
      hint.id
    );
  });

  it('offers None for the optional date and keeps a custom selector available', async () => {
    stub();
    renderWorkspace();

    expect(await screen.findByRole('radio', { name: COPY.refineNone }, SLOW)).toBeChecked();
    fireEvent.click(screen.getAllByRole('radio', { name: COPY.refineCustom })[2]);

    expect(screen.getByLabelText(COPY.refineCustomSelector(COPY.refinePublishedLabel))).toBeEnabled();
  });
});
