import { useEffect, useState } from 'preact/hooks';
import { isAbortError } from '../feeds/feedsService';
import { COPY } from '../journey/copy';
import {
  previewSelectors,
  suggestSelectors,
  validateSelectors,
  type RefineCandidates,
  type RefineIssue,
  type RefinePreview,
} from './refineService';
import {
  emptyDraft,
  isDraftComplete,
  selectorsFromDraft,
  type RefineDraft,
  type RefineFieldId,
} from './selectorDraft';

const CHECK_DELAY_MS = 400;

export type SuggestionState =
  | { readonly status: 'loading' }
  | { readonly status: 'ready'; readonly candidates: RefineCandidates }
  | { readonly status: 'failed' };

export type PreviewState =
  | { readonly status: 'idle' }
  | { readonly status: 'loading' }
  | { readonly status: 'ready'; readonly preview: RefinePreview }
  | { readonly status: 'failed'; readonly message: string };

interface UseRefineOptions {
  readonly url: string;
  readonly token: string;
}

function errorMessage(error: unknown): string {
  const message = (error as { message?: unknown } | undefined)?.message;
  return typeof message === 'string' && message ? message : COPY.refineUnavailable;
}

/** Seeds an empty draft from the best capture candidates so the first view is almost right. */
function seedDraft(candidates: RefineCandidates): RefineDraft {
  const [best] = candidates.items;
  const first = (field: RefineFieldId) => candidates.fields[field][0]?.selector ?? '';
  return {
    items: best?.selector ?? '',
    enhance: best?.enhance ?? false,
    fields: { title: first('title'), link: first('link'), published: first('published') },
  };
}

export function useRefine({ url, token }: UseRefineOptions) {
  const [draft, setDraft] = useState<RefineDraft>(emptyDraft);
  const [suggestion, setSuggestion] = useState<SuggestionState>({ status: 'loading' });
  const [issues, setIssues] = useState<readonly RefineIssue[]>([]);
  const [preview, setPreview] = useState<PreviewState>({ status: 'idle' });

  useEffect(() => {
    const controller = new AbortController();
    const load = async () => {
      try {
        const candidates = await suggestSelectors(url, token, controller.signal);
        setSuggestion({ status: 'ready', candidates });
        setDraft((current) => (isDraftComplete(current) ? current : seedDraft(candidates)));
      } catch (error) {
        if (!isAbortError(error)) setSuggestion({ status: 'failed' });
      }
    };
    void load();
    return () => controller.abort();
  }, [url, token]);

  useEffect(() => {
    if (!isDraftComplete(draft)) {
      setIssues([]);
      setPreview({ status: 'idle' });
      return;
    }

    const controller = new AbortController();
    const timer = setTimeout(async () => {
      const selectors = selectorsFromDraft(draft);
      try {
        const found = await validateSelectors(selectors, token, controller.signal);
        setIssues(found);
        if (found.length > 0) {
          setPreview({ status: 'idle' });
          return;
        }
        setPreview({ status: 'loading' });
        setPreview({
          status: 'ready',
          preview: await previewSelectors(url, selectors, token, controller.signal),
        });
      } catch (error) {
        if (!isAbortError(error)) setPreview({ status: 'failed', message: errorMessage(error) });
      }
    }, CHECK_DELAY_MS);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [draft, url, token]);

  const canSave =
    isDraftComplete(draft) &&
    issues.length === 0 &&
    preview.status === 'ready' &&
    preview.preview.failureKind === undefined;

  return { draft, setDraft, suggestion, issues, preview, canSave };
}
