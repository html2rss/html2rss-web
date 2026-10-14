import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/preact';
import { http, HttpResponse } from 'msw';
import type { StudioSelectors } from '../studio/selectorDraft';
import { server } from './mocks/server';
import {
  buildStructuredErrorResponse,
  DEFAULT_SUGGEST_BUCKETS,
  selectorsFromValidateRequest,
  pageUrlFrom,
  suggestSuccessBody,
  validateSuccessBody,
  validateYamlForSelectors,
  studioPreviewSuccessBody,
} from './mocks/apiFixtures';
import { ConfigStudio } from '../studio';
import { COPY } from '../journey/copy';

vi.mock('../studio/useStudio', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../studio/useStudio')>();
  return {
    ...actual,
    useStudio: (options: Parameters<typeof actual.useStudio>[0]) =>
      actual.useStudio({ ...options, validateDelayMs: 0, previewSettleMs: 0 }),
  };
});

const pageUrl = 'https://example.com/articles';
const decisionNotice = 'We could not extract feed items from this page yet.';
const imagePreview = studioPreviewSuccessBody([
  {
    title: 'With image',
    url: 'https://example.com/sample',
    published_at: '2024-01-02',
    image: 'https://cdn.example/a.jpg',
  },
  { title: 'No image', url: 'https://example.com/plain' },
]);

function echoValidate() {
  server.use(
    http.post('/api/v1/feeds/validate', async ({ request }) => {
      const body = await request.json();
      const selectors = selectorsFromValidateRequest(body);
      const yaml = validateYamlForSelectors(selectors, pageUrlFrom(body));
      return HttpResponse.json(validateSuccessBody(selectors, yaml));
    })
  );
}

function stubSuggest(body: unknown = suggestSuccessBody(DEFAULT_SUGGEST_BUCKETS)) {
  server.use(http.post('/api/v1/feeds/suggest_selectors', () => HttpResponse.json(body)));
}

function stubPreview(body: unknown = studioPreviewSuccessBody()) {
  server.use(http.post('/api/v1/feeds/preview', () => HttpResponse.json(body)));
}

function renderStudio(
  onGenerate = vi.fn<(selectors: StudioSelectors) => Promise<void>>(),
  extras: Partial<{
    mode: 'ready' | 'unresolved';
    directoryHandoff: boolean;
    decisionNotice: string;
    token: string;
  }> = {}
) {
  render(
    <ConfigStudio
      url={pageUrl}
      token={extras.token ?? 'tok'}
      mode={extras.mode ?? 'unresolved'}
      directoryHandoff={extras.directoryHandoff}
      decisionNotice={extras.decisionNotice}
      onGenerate={onGenerate}
    />
  );
  return { onGenerate };
}

function itemsChip(name = COPY.addSelector('Sample headline')) {
  return within(screen.getByRole('group', { name: COPY.selectorChoices })).getByRole('button', { name });
}

async function waitForItemsChip(name = COPY.addSelector('Sample headline')) {
  await waitFor(() => expect(itemsChip(name)).toBeInTheDocument());
  return itemsChip(name);
}

describe('ConfigStudio', () => {
  it('keeps Save/meadow visible while suggestions pending and densifies fields', async () => {
    echoValidate();
    stubPreview(imagePreview);
    const pending = Promise.withResolvers<Response>();
    server.use(http.post('/api/v1/feeds/suggest_selectors', () => pending.promise));
    renderStudio();

    expect(screen.getByText(COPY.selectorSuggestionsLoading)).toBeInTheDocument();
    expect(screen.getByLabelText(COPY.itemsSelector)).not.toHaveClass('input--lg');
    expect(screen.queryByText(COPY.previewFetchedCaption)).not.toBeInTheDocument();
    const save = screen.getByRole('button', { name: COPY.saveAndGenerate });
    expect(
      save.compareDocumentPosition(screen.getByLabelText(COPY.previewRegion)) &
        Node.DOCUMENT_POSITION_FOLLOWING
    ).not.toBe(0);

    pending.resolve(
      HttpResponse.json(
        suggestSuccessBody({
          items: [{ selector: 'article', enhance: false, sample: 'Sample headline' }],
          title: [{ selector: 'h2', sample: 'Headline' }],
        })
      )
    );
    await waitFor(() =>
      expect(screen.getByLabelText(`${COPY.fieldTitle} ${COPY.selector}`)).toBeInTheDocument()
    );
    expect(screen.getAllByText(COPY.fieldTitle)).toHaveLength(1);
    expect(document.querySelector('details')).toBeNull();
    expect(document.querySelector('.studio-enhance__label')).not.toHaveClass('ui-card');

    fireEvent.click(await waitForItemsChip());
    await waitFor(() => expect(screen.getByText('With image')).toBeInTheDocument());
    expect(screen.getByText(COPY.previewFetchedCaption)).toBeInTheDocument();
    expect(screen.getByLabelText(COPY.previewRegion).querySelector('.ui-item-list--grid')).toBeTruthy();
  });

  it('activates dormant fields, keeps empty suggestions neutral, and toggles chips without enhance', async () => {
    echoValidate();
    stubSuggest(suggestSuccessBody({}));
    const { unmount } = render(
      <ConfigStudio url={pageUrl} token="tok" mode="unresolved" onGenerate={vi.fn()} />
    );
    await waitFor(() => expect(screen.getByText(COPY.selectorSuggestionsEmpty)).toBeInTheDocument());
    expect(screen.queryByRole('group', { name: COPY.selectorChoices })).not.toBeInTheDocument();

    unmount();
    stubSuggest(suggestSuccessBody({ items: [{ selector: 'article', enhance: true, sample: 'Story A' }] }));
    renderStudio();
    await waitForItemsChip(COPY.addSelector('Story A'));
    fireEvent.click(screen.getByRole('button', { name: COPY.addOptionalField(COPY.fieldTitle) }));
    expect(screen.getByLabelText(`${COPY.fieldTitle} ${COPY.selector}`)).toHaveFocus();

    fireEvent.click(screen.getByLabelText(COPY.enhanceItems));
    fireEvent.click(itemsChip(COPY.addSelector('Story A')));
    expect(screen.getByLabelText(COPY.itemsSelector)).toHaveValue('a[href], article');
    expect(screen.getByLabelText(COPY.enhanceItems)).toBeChecked();
    fireEvent.click(itemsChip(COPY.removeSelector('Story A')));
    expect(screen.getByLabelText(COPY.itemsSelector)).toHaveValue('a[href]');
    expect(screen.getByLabelText(COPY.enhanceItems)).toBeChecked();
  });

  it('keeps editing when suggestions fail and supports retry', async () => {
    echoValidate();
    let attempts = 0;
    server.use(
      http.post('/api/v1/feeds/suggest_selectors', () => {
        attempts += 1;
        if (attempts === 1) {
          return HttpResponse.json(
            buildStructuredErrorResponse({
              code: 'STUDIO_DISABLED',
              message: 'Selector suggestions are unavailable',
              kind: 'input',
              retryable: false,
              next_action: 'none',
              retry_action: 'none',
            }),
            { status: 403 }
          );
        }
        return HttpResponse.json(
          suggestSuccessBody({ items: [{ selector: 'article.retry', sample: 'Sample headline' }] })
        );
      })
    );
    renderStudio();
    expect(await screen.findByText('Selector suggestions are unavailable')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: COPY.retrySelectorSuggestions }));
    await waitForItemsChip();
    expect(attempts).toBe(2);
  });

  it('shows field validation inline without issue-count panels', async () => {
    server.use(
      http.post('/api/v1/feeds/validate', () =>
        HttpResponse.json({
          success: true,
          data: {
            report: {
              success: false,
              issues: [
                { path: ['selectors', 'title', 'selector'], code: 'missing_key', message: 'is missing' },
                { path: ['selectors', 'url', 'selector'], code: 'constraint', message: 'is invalid' },
              ],
            },
            selectors: { items: { selector: 'article', enhance: false } },
            yaml: 'selectors: {}',
          },
        })
      )
    );
    renderStudio();
    await waitFor(() => expect(screen.getByText('is missing')).toBeInTheDocument());
    expect(screen.getByText('is invalid')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /issue/i })).not.toBeInTheDocument();
  });

  it('gates sample images on token and offers check again on preview failure', async () => {
    echoValidate();
    stubPreview(imagePreview);
    let view = render(<ConfigStudio url={pageUrl} token="tok" mode="unresolved" onGenerate={vi.fn()} />);
    fireEvent.click(await waitForItemsChip());
    await waitFor(() => expect(screen.getByText('With image')).toBeInTheDocument());
    expect(document.querySelectorAll('img.studio-sample-image')).toHaveLength(1);

    view.unmount();
    stubPreview(imagePreview);
    view = render(<ConfigStudio url={pageUrl} token="  " mode="unresolved" onGenerate={vi.fn()} />);
    fireEvent.click(await waitForItemsChip());
    await waitFor(() => expect(screen.getByText('With image')).toBeInTheDocument());
    expect(document.querySelector('img')).toBeNull();

    view.unmount();
    echoValidate();
    stubSuggest();
    server.use(http.post('/api/v1/feeds/preview', () => HttpResponse.error()));
    renderStudio();
    fireEvent.click(await waitForItemsChip());
    expect(await screen.findByRole('button', { name: COPY.checkAgain })).toBeInTheDocument();
  });

  it('copies yaml and activates ready Save after a candidate edit', async () => {
    echoValidate();
    const { onGenerate } = renderStudio(vi.fn(), { mode: 'ready', directoryHandoff: true });
    const save = screen.getByRole('button', { name: COPY.saveAndGenerate });
    expect(save).toBeDisabled();
    fireEvent.click(await waitForItemsChip());
    await waitFor(() => expect(save).toBeEnabled());
    expect(save).toHaveClass('btn--primary');
    expect(document.querySelector('.studio-actions')).toContainElement(
      screen.getByRole('link', { name: COPY.proposeDirectory })
    );

    vi.mocked(navigator.clipboard.writeText).mockRejectedValueOnce(new Error('denied'));
    fireEvent.click(screen.getByRole('button', { name: COPY.copyYaml }));
    await waitFor(() => expect(document.querySelector('[data-clipboard="failed"]')).toBeTruthy());
    fireEvent.click(screen.getByRole('button', { name: COPY.copyYaml }));
    await waitFor(() => expect(navigator.clipboard.writeText).toHaveBeenCalled());

    fireEvent.click(save);
    await waitFor(() => expect(onGenerate).toHaveBeenCalled());
    expect(onGenerate.mock.calls[0]?.[0]).toEqual({
      items: { selector: 'a[href], article', enhance: false },
    });
  });

  it('does not re-echo Decision on save/suggest failure; keeps distinct save Notice', async () => {
    echoValidate();
    server.use(
      http.post('/api/v1/feeds/suggest_selectors', () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            code: 'EXTRACTION_EMPTY',
            message: decisionNotice,
            kind: 'input',
            retryable: false,
            next_action: 'none',
            retry_action: 'none',
          }),
          { status: 422 }
        )
      )
    );
    const echoSave = vi
      .fn<(selectors: StudioSelectors) => Promise<void>>()
      .mockRejectedValue(new Error(decisionNotice));
    const { unmount } = render(
      <ConfigStudio
        url={pageUrl}
        token="tok"
        mode="unresolved"
        decisionNotice={decisionNotice}
        onGenerate={echoSave}
      />
    );
    expect(await screen.findByText(COPY.selectorSuggestionsFailed)).toBeInTheDocument();
    expect(screen.queryByText(decisionNotice)).not.toBeInTheDocument();
    const save = screen.getByRole('button', { name: COPY.saveAndGenerate });
    await waitFor(() => expect(save).toBeEnabled());
    fireEvent.click(save);
    await waitFor(() => expect(echoSave).toHaveBeenCalled());
    expect(screen.queryByText(COPY.createFailedTitle)).not.toBeInTheDocument();

    unmount();
    echoValidate();
    stubSuggest();
    const distinct = vi
      .fn<(selectors: StudioSelectors) => Promise<void>>()
      .mockRejectedValue(new Error('Unable to reach the server.'));
    renderStudio(distinct, { decisionNotice });
    const distinctSave = screen.getByRole('button', { name: COPY.saveAndGenerate });
    await waitFor(() => expect(distinctSave).toBeEnabled());
    fireEvent.click(distinctSave);
    expect(await screen.findByText(COPY.createFailedTitle)).toBeInTheDocument();
    expect(screen.getByText('Unable to reach the server.')).toBeInTheDocument();
  });
});
