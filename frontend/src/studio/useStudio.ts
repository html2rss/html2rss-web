import { useEffect, useRef, useState } from 'preact/hooks';
import { isAbortError } from '../api/http/client';
import { isFeedCreationError } from '../feeds/feedsService';
import { COPY } from '../journey/copy';
import {
  previewStudioFeed,
  StudioRequestError,
  suggestStudioSelectors,
  validateStudioSelectors,
  type StudioPreview,
  type StudioValidationOutcome,
} from './studioService';
import type { StudioIssue, StudioSuggestionState } from './studioModel';
import {
  emptyDraft,
  selectorsFromDraft,
  toggleSelectorParts,
  withEnhance,
  withFieldSelector,
  withItemsSelector,
  type StudioDraft,
  type StudioFieldId,
  type StudioSelectors,
} from './selectorDraft';

export const STUDIO_VALIDATE_DELAY_MS = 300;
export const STUDIO_PREVIEW_SETTLE_MS = 800;

export type LivePreview =
  | { readonly status: 'idle' }
  | { readonly status: 'loading'; readonly held: StudioPreview | undefined }
  | { readonly status: 'ready'; readonly sample: StudioPreview }
  | { readonly status: 'failed'; readonly message: string };

interface StudioCore {
  readonly draft: StudioDraft;
  readonly yaml: string;
  readonly live: LivePreview;
  readonly validated: boolean;
}

export type StudioState =
  | (StudioCore & { readonly phase: 'editing' | 'validating' | 'saving' })
  | (StudioCore & { readonly phase: 'invalid'; readonly issues: readonly StudioIssue[] })
  | (StudioCore & { readonly phase: 'failed'; readonly message: string });

interface UseStudioOptions {
  readonly url: string;
  readonly token: string;
  readonly validateDelayMs?: number;
  readonly previewSettleMs?: number;
}

export function useStudio({
  url,
  token,
  validateDelayMs = STUDIO_VALIDATE_DELAY_MS,
  previewSettleMs = STUDIO_PREVIEW_SETTLE_MS,
}: UseStudioOptions) {
  const [state, setState] = useState<StudioState>({
    phase: 'editing',
    draft: emptyDraft(),
    yaml: '',
    validated: false,
    live: { status: 'idle' },
  });
  const [suggestion, setSuggestion] = useState<StudioSuggestionState>({ status: 'loading' });
  const [documentRevision, setDocumentRevision] = useState(0);

  const stateReference = useRef(state);
  stateReference.current = state;
  const requestIdReference = useRef(0);
  const previewRequestReference = useRef(0);
  const suggestRequestReference = useRef(0);
  const suggestAbortReference = useRef<AbortController | undefined>(undefined);
  const saveRequestReference = useRef(0);
  const previewTimerReference = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const previewAbortReference = useRef<AbortController | undefined>(undefined);
  const previewSettleReference = useRef(previewSettleMs);
  previewSettleReference.current = previewSettleMs;
  const initialUrlReference = useRef(url);

  useEffect(() => {
    const requestId = ++requestIdReference.current;
    const controller = new AbortController();
    const revision = documentRevision;
    const timer = setTimeout(() => {
      void runValidate(requestId, controller.signal, revision);
    }, validateDelayMs);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [documentRevision, token, url, validateDelayMs]);

  useEffect(() => {
    const requestId = ++suggestRequestReference.current;
    const controller = new AbortController();
    suggestAbortReference.current = controller;
    setSuggestion({ status: 'loading' });
    void loadSuggestion(requestId, controller.signal);

    return () => {
      controller.abort();
    };
  }, [url, token]);

  useEffect(() => {
    return () => {
      clearTimeout(previewTimerReference.current);
      previewAbortReference.current?.abort();
    };
  }, []);

  async function loadSuggestion(requestId: number, signal: AbortSignal) {
    try {
      const evidence = await suggestStudioSelectors(token, url, signal);
      if (signal.aborted || suggestRequestReference.current !== requestId) return;
      setSuggestion(evidence);
    } catch (error) {
      if (isAbortError(error) || signal.aborted || suggestRequestReference.current !== requestId) return;
      setSuggestion({
        status: 'failed',
        message: error instanceof StudioRequestError ? error.message : COPY.unableToReachServer,
      });
    }
  }

  async function runValidate(requestId: number, signal: AbortSignal, revision: number) {
    const sentDraft = stateReference.current.draft;
    cancelPreview();
    setState((previous) => ({ ...coreOf(previous), phase: 'validating' }));

    try {
      const outcome = await validateStudioSelectors(token, url, sentDraft, signal);
      if (signal.aborted || requestIdReference.current !== requestId) return;
      commitValidation(outcome, sentDraft, revision);
    } catch (error) {
      if (isAbortError(error) || signal.aborted || requestIdReference.current !== requestId) return;
      setState((previous) => ({
        ...coreOf(previous),
        phase: 'failed',
        live: restoreHeld(previous.live),
        message: error instanceof StudioRequestError ? error.message : COPY.unableToReachServer,
      }));
    }
  }

  function commitValidation(outcome: StudioValidationOutcome, sentDraft: StudioDraft, revision: number) {
    const draft = outcome.draft ? adoptServerDraft(sentDraft, outcome.draft) : sentDraft;
    const yaml = outcome.yaml ?? stateReference.current.yaml;

    if (!outcome.valid) {
      setState((previous) => ({
        ...coreOf(previous),
        phase: 'invalid',
        draft,
        yaml,
        issues: outcome.issues,
        live: restoreHeld(previous.live),
      }));
      return;
    }

    setState((previous) => ({
      ...coreOf(previous),
      phase: 'editing',
      draft,
      yaml,
      validated: true,
    }));
    if (revision === 0 && url === initialUrlReference.current) return;
    schedulePreview();
  }

  function editSelectors(update: (draft: StudioDraft) => StudioDraft) {
    cancelPreview();
    setState((previous) => ({
      ...coreOf(previous),
      phase: 'editing',
      draft: update(previous.draft),
      validated: false,
      live: refreshLive(previous.live),
    }));
    setDocumentRevision((revision) => revision + 1);
  }

  function cancelPreview() {
    clearTimeout(previewTimerReference.current);
    previewAbortReference.current?.abort();
    previewAbortReference.current = undefined;
    previewRequestReference.current += 1;
  }

  function schedulePreview() {
    cancelPreview();
    const requestId = previewRequestReference.current;
    previewTimerReference.current = setTimeout(() => {
      void runPreview(requestId);
    }, previewSettleReference.current);
  }

  async function runPreview(requestId: number) {
    const current = stateReference.current;
    if (!(current.phase === 'editing' && current.validated)) return;
    if (previewRequestReference.current !== requestId) return;

    const controller = new AbortController();
    previewAbortReference.current = controller;
    setState((previous) => {
      if (!(previous.phase === 'editing' && previous.validated)) return previous;
      if (previewRequestReference.current !== requestId) return previous;
      return {
        ...previous,
        live: {
          status: 'loading',
          held: studioPreviewSample(previous.live),
        },
      };
    });

    try {
      const sample = await previewStudioFeed(token, url, stateReference.current.draft, controller.signal);
      if (controller.signal.aborted || previewRequestReference.current !== requestId) return;
      if (sample.failure !== undefined) {
        setState((previous) => withLive(previous, { status: 'failed', message: COPY.previewUnavailable }));
        return;
      }
      setState((previous) => withLive(previous, { status: 'ready', sample }));
    } catch (error) {
      if (isAbortError(error) || controller.signal.aborted || previewRequestReference.current !== requestId)
        return;
      const message = error instanceof StudioRequestError ? error.message : COPY.unableToReachServer;
      setState((previous) => withLive(previous, { status: 'failed', message }));
    }
  }

  return {
    state,
    suggestion,
    isDirty: documentRevision > 0,
    setItemsSelector: (itemsSelector: string) => {
      editSelectors((draft) => withItemsSelector(draft, itemsSelector));
    },
    setEnhance: (isEnhanced: boolean) => {
      cancelPreview();
      setState((previous) => {
        const hasEnhanceFlipped = previous.draft.enhance !== isEnhanced;
        return {
          ...coreOf(previous),
          phase: 'editing',
          draft: withEnhance(previous.draft, isEnhanced),
          validated: false,
          live: hasEnhanceFlipped ? { status: 'idle' } : refreshLive(previous.live),
        };
      });
      setDocumentRevision((revision) => revision + 1);
    },
    setFieldSelector: (field: StudioFieldId, selector: string) => {
      editSelectors((draft) => withFieldSelector(draft, field, selector));
    },
    toggleItemsSelector: (selector: string) => {
      editSelectors((draft) => withItemsSelector(draft, toggleSelectorParts(draft.itemsSelector, selector)));
    },
    toggleFieldSelector: (field: StudioFieldId, selector: string) => {
      editSelectors((draft) =>
        withFieldSelector(draft, field, toggleSelectorParts(draft.fields[field].selector, selector))
      );
    },
    retrySuggestion: () => {
      suggestAbortReference.current?.abort();
      const requestId = ++suggestRequestReference.current;
      const controller = new AbortController();
      suggestAbortReference.current = controller;
      setSuggestion({ status: 'loading' });
      void loadSuggestion(requestId, controller.signal);
    },
    retryPreview: () => {
      const current = stateReference.current;
      if (!(current.phase === 'editing' && current.validated)) return;
      cancelPreview();
      void runPreview(previewRequestReference.current);
    },
    save: async (create: (selectors: StudioSelectors) => Promise<void>) => {
      const requestId = ++saveRequestReference.current;
      const current = stateReference.current;
      setState({ ...coreOf(current), phase: 'saving' });

      try {
        await create(selectorsFromDraft(current.draft));
        if (saveRequestReference.current !== requestId) return;
        setState({ ...coreOf(current), phase: 'editing', validated: true });
      } catch (error) {
        if (saveRequestReference.current !== requestId) return;
        setState({
          ...coreOf(current),
          phase: 'failed',
          message: failureMessage(error),
        });
      }
    },
  };
}

export function studioIssues(state: StudioState): readonly StudioIssue[] {
  return state.phase === 'invalid' ? state.issues : [];
}

export function canSaveStudio(state: StudioState): boolean {
  return state.phase === 'editing' && state.validated;
}

export function studioPreviewSample(live: LivePreview): StudioPreview | undefined {
  if (live.status === 'ready') return live.sample;
  if (live.status === 'loading') return live.held;
  return undefined;
}

function coreOf(state: StudioState): StudioCore {
  return {
    draft: state.draft,
    yaml: state.yaml,
    live: state.live,
    validated: state.validated,
  };
}

function withLive(state: StudioState, live: LivePreview): StudioState {
  return { ...state, live };
}

function refreshLive(live: LivePreview): LivePreview {
  return { status: 'loading', held: studioPreviewSample(live) };
}

function restoreHeld(live: LivePreview): LivePreview {
  const held = studioPreviewSample(live);
  if (held === undefined) return { status: 'idle' };
  return { status: 'ready', sample: held };
}

function adoptServerDraft(sent: StudioDraft, incoming: StudioDraft): StudioDraft {
  return {
    ...sent,
    itemsSelector: incoming.itemsSelector,
    enhance: incoming.enhance,
  };
}

function failureMessage(error: unknown): string {
  if (isFeedCreationError(error)) return error.message;
  if (error instanceof Error && error.message.trim()) return error.message;
  return COPY.createFailedTitle;
}
