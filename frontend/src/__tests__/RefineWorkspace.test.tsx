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

    await waitFor(() => expect(screen.getByLabelText(COPY.refineItemsLabel)).toHaveValue('article'), SLOW);
    expect(screen.getByLabelText(COPY.refineTitleLabel)).toHaveValue('h2');
    expect(screen.getByLabelText(COPY.refineLinkLabel)).toHaveValue('a');
    expect(screen.getByLabelText(COPY.refinePublishedLabel)).toHaveValue('');

    expect(await screen.findByText('First post', undefined, SLOW)).toBeInTheDocument();
    expect(previews).toHaveLength(1);

    fireEvent.click(screen.getByRole('button', { name: COPY.refineSave }));
    expect(onSave).toHaveBeenCalledWith({
      items: { selector: 'article', enhance: true },
      title: { selector: 'h2', extractor: 'text' },
      url: { selector: 'a', extractor: 'href' },
    });
  });

  it('focuses the items selector on open', async () => {
    stub();
    renderWorkspace();

    await waitFor(() => expect(screen.getByLabelText(COPY.refineItemsLabel)).toHaveFocus());
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
    expect(screen.getByLabelText(COPY.refineTitleLabel)).toHaveAttribute('aria-invalid', 'true');
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

    fireEvent.click(await screen.findByRole('button', { name: /li\.post/ }, SLOW));

    await waitFor(() => expect(screen.getByLabelText(COPY.refineItemsLabel)).toHaveValue('li.post'));
  });

  it('keeps manual editing available when suggestions fail', async () => {
    stub({ suggest: 'fail' });
    renderWorkspace();

    expect(await screen.findByText(COPY.refineSuggestionsFailed, undefined, SLOW)).toBeInTheDocument();
    expect(screen.getByLabelText(COPY.refineItemsLabel)).toBeEnabled();
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

    expect(screen.getByRole('button', { name: COPY.refineSaving })).toBeDisabled();
    expect(screen.getByRole('button', { name: COPY.back })).toBeDisabled();
  });

  it('goes back', async () => {
    stub();
    const { onCancel } = renderWorkspace();

    fireEvent.click(screen.getByRole('button', { name: COPY.back }));
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
    stub();
    const { onSave } = renderWorkspace();
    await screen.findByText('First post', undefined, SLOW);

    fireEvent.input(screen.getByLabelText(COPY.refineItemsLabel, { exact: true }), {
      target: { value: 'li.post' },
    });

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
});
