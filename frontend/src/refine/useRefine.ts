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

type SuggestionState =
  | { readonly status: 'loading' }
  | { readonly status: 'ready'; readonly candidates: RefineCandidates }
  | { readonly status: 'failed' };

type PreviewState =
  | { readonly status: 'idle' }
  | { readonly status: 'loading' }
  | { readonly status: 'ready'; readonly preview: RefinePreview }
  | { readonly status: 'failed'; readonly message: string };

interface UseRefineOptions {
  readonly url: string;
  readonly token: string;
  /** Called when the server rejects the access token, so the caller can ask for a new one. */
  readonly onAuthFailure: () => void;
}

interface ApiFailure {
  kind?: string;
  nextAction?: string;
  message?: unknown;
}

function isAuthFailure(error: unknown): boolean {
  const { kind, nextAction } = (error ?? {}) as ApiFailure;
  return kind === 'auth' || nextAction === 'enter_token';
}

/** Plain-language text; raw network errors and generic server defaults never reach the screen. */
function errorMessage(error: unknown): string {
  const { kind, message } = (error ?? {}) as ApiFailure;
  if (kind === undefined || kind === 'network') return COPY.refineOffline;
  if (kind === 'input' && typeof message === 'string' && message) return message;
  return COPY.refineUnavailable;
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

export function useRefine({ url, token, onAuthFailure }: UseRefineOptions) {
  const [draft, setDraft] = useState<RefineDraft>(emptyDraft);
  const [suggestion, setSuggestion] = useState<SuggestionState>({ status: 'loading' });
  const [issues, setIssues] = useState<readonly RefineIssue[]>([]);
  const [preview, setPreview] = useState<PreviewState>({ status: 'idle' });
  // The draft the current preview belongs to; a newer draft is not saveable until it is previewed too.
  const [previewedDraft, setPreviewedDraft] = useState<RefineDraft | undefined>(undefined);
  const [recheckCount, setRecheckCount] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    const load = async () => {
      try {
        const candidates = await suggestSelectors(url, token, controller.signal);
        setSuggestion({ status: 'ready', candidates });
        setDraft((current) => (isDraftComplete(current) ? current : seedDraft(candidates)));
      } catch (error) {
        if (isAbortError(error)) return;
        if (isAuthFailure(error)) onAuthFailure();
        else setSuggestion({ status: 'failed' });
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
        const result = await previewSelectors(url, selectors, token, controller.signal);
        setPreview({ status: 'ready', preview: result });
        setPreviewedDraft(draft);
      } catch (error) {
        if (isAbortError(error)) return;
        if (isAuthFailure(error)) onAuthFailure();
        else setPreview({ status: 'failed', message: errorMessage(error) });
      }
    }, CHECK_DELAY_MS);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [draft, url, token, recheckCount]);

  const canSave =
    isDraftComplete(draft) &&
    issues.length === 0 &&
    preview.status === 'ready' &&
    previewedDraft === draft &&
    preview.preview.failureKind === undefined;

  const recheck = () => setRecheckCount((count) => count + 1);

  return { draft, setDraft, suggestion, issues, preview, canSave, recheck };
}
