import { useEffect, useRef, useState } from 'preact/hooks';
import { useFeedCreation } from './useFeedCreation';
import { decideJourney, type UnresolvedWorkspace } from './decideJourney';
import { clearFeedDraftState, loadFeedDraftState, saveFeedDraftState } from '../utils/feedWorkflowStorage';
import { expandCreateUrl } from '../utils/url';
import type { FeedCreationError } from '../api/contracts';
import type { StudioSelectors } from '../studio/selectorDraft';
import { isFeedCreationError } from '../feeds/feedsService';
import { COPY } from '../journey/copy';
import type { AppRoute } from '../routes/appRoute';
import type { MayCreateResult } from '../session';

const EMPTY_FEED_ERRORS = { url: '', form: '' };
const EXTRACTION_EMPTY = 'EXTRACTION_EMPTY';

interface RouteNavigationOptions {
  replace?: boolean;
}

export interface FeedFlowDependencies {
  token: string | undefined;
  isLoading: boolean;
  feedCreationEnabled: boolean;
  isStudioEnabled: boolean;
  mayCreate: (accessToken?: string) => MayCreateResult;
  saveToken: (token: string) => Promise<void>;
  clearToken: () => void;
  route: AppRoute;
  navigate: (route: AppRoute, options?: RouteNavigationOptions) => void;
  createEntryKey: number;
}

/**
 * Sole frontend journey owner: navigate transitions + closed UI kind via decideJourney.
 */
export function useFeedFlow({
  token,
  isLoading,
  feedCreationEnabled,
  isStudioEnabled,
  mayCreate,
  saveToken,
  clearToken,
  route,
  navigate,
  createEntryKey,
}: FeedFlowDependencies) {
  const {
    isCreating,
    result,
    error: creationError,
    createFeed,
    clearError,
    clearResult,
    retryPreviewFetch,
  } = useFeedCreation();

  const [feedFormData, setFeedFormData] = useState(() => loadFeedDraftState() ?? { url: '' });
  const [feedFieldErrors, setFeedFieldErrors] = useState(EMPTY_FEED_ERRORS);
  const [tokenDraft, setTokenDraft] = useState('');
  const [tokenError, setTokenError] = useState('');
  const [bookmarkletNotice, setBookmarkletNotice] = useState('');
  const [focusCreateComposerKey, setFocusCreateComposerKey] = useState(0);
  const [unresolved, setUnresolved] = useState<UnresolvedWorkspace | undefined>();

  const routePrefillUrl = route.kind === 'create' || route.kind === 'token' ? route.prefillUrl : undefined;
  const autoSubmitUrlReference = useRef<string | undefined>(routePrefillUrl);
  const hasAutoSubmittedReference = useRef(false);
  const previousRouteKindReference = useRef(route.kind);
  const previousCreateEntryKeyReference = useRef(createEntryKey);

  // Prefill URL effect — route prefill wins over persisted draft (bookmarklet / deep links).
  useEffect(() => {
    if (!routePrefillUrl) return;
    autoSubmitUrlReference.current = routePrefillUrl;
    hasAutoSubmittedReference.current = false;
    setFeedFormData((previous) => {
      if (previous.url === routePrefillUrl) return previous;
      return { ...previous, url: routePrefillUrl };
    });
    saveFeedDraftState({ url: routePrefillUrl });
  }, [routePrefillUrl]);

  const submitDisabled = isCreating || !feedCreationEnabled;

  const onFeedFieldChange = (key: 'url', value: string) => {
    setFeedFormData((previous) => {
      const next = { ...previous, [key]: value };
      if (next.url.trim()) {
        saveFeedDraftState(next);
      } else {
        clearFeedDraftState();
      }
      return next;
    });
    setFeedFieldErrors((previous) => ({ ...previous, url: '', form: '' }));
    clearError();
  };

  const openUnresolvedWorkspace = (url: string, notice: string) => {
    setUnresolved({ url, notice });
    setFeedFieldErrors(EMPTY_FEED_ERRORS);
    clearError();
    navigate({ kind: 'result' });
  };

  const attemptFeedCreation = async (accessToken: string) => {
    const expanded = expandCreateUrl(feedFormData.url);
    if ('error' in expanded) {
      setFeedFieldErrors({
        ...EMPTY_FEED_ERRORS,
        url: expanded.error === 'empty' ? COPY.urlRequired : COPY.invalidUrlFormat,
      });
      return false;
    }
    const normalizedUrl = expanded.ok;

    const gate = mayCreate(accessToken);
    if (gate === 'disabled') {
      setFeedFieldErrors({
        ...EMPTY_FEED_ERRORS,
        form: COPY.creationDisabled,
      });
      return false;
    }

    if (gate === 'needToken') {
      setFeedFormData((previous) => ({ ...previous, url: normalizedUrl }));
      clearError();
      setTokenError('');
      if (route.kind !== 'token') navigate({ kind: 'token', prefillUrl: normalizedUrl });
      return false;
    }

    try {
      setFeedFormData((previous) => ({ ...previous, url: normalizedUrl }));
      const createdResult = await createFeed(normalizedUrl, accessToken);
      clearFeedDraftState();
      setUnresolved(undefined);
      navigate({ kind: 'result', feedToken: createdResult.feed.feed_token });
      setTokenError('');
      return true;
    } catch (submitError) {
      const failure = submitError as FeedCreationError;

      if (failure.kind === 'auth' || failure.nextAction === 'enter_token') {
        clearToken();
        clearError();
        setTokenDraft('');
        if (route.kind !== 'token') navigate({ kind: 'token', prefillUrl: normalizedUrl });
        setTokenError(COPY.tokenRejected);
        setFeedFieldErrors(EMPTY_FEED_ERRORS);
        return false;
      }

      if (canRecoverEmptyExtraction(failure, isStudioEnabled, accessToken)) {
        openUnresolvedWorkspace(normalizedUrl, failure.message);
        return false;
      }

      setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, form: failure.message });
      if (route.kind === 'token') {
        // Prevent create-entry auto-submit from clearing Decision error before remount runs.
        hasAutoSubmittedReference.current = true;
        navigate({ kind: 'create', prefillUrl: normalizedUrl });
      }
      return false;
    }
  };

  const onFeedSubmit = async (event: Event) => {
    event.preventDefault();
    setFeedFieldErrors(EMPTY_FEED_ERRORS);
    await attemptFeedCreation(token ?? '');
  };

  const onSaveToken = async () => {
    try {
      const normalizedToken = tokenDraft.trim();
      await saveToken(normalizedToken);
      setTokenError('');
      const created = await attemptFeedCreation(normalizedToken);
      if (created) setTokenDraft('');
    } catch (error) {
      setTokenError(error instanceof Error ? error.message : COPY.unableToSaveToken);
    }
  };

  // Auto-submit effect
  useEffect(() => {
    const autoSubmitUrl = autoSubmitUrlReference.current;
    if (!autoSubmitUrl || hasAutoSubmittedReference.current) return;
    if (isLoading) return;
    if (feedFormData.url !== autoSubmitUrl) return;

    if (mayCreate(token) === 'needToken') {
      hasAutoSubmittedReference.current = true;
      const expanded = expandCreateUrl(autoSubmitUrl);
      const prefillUrl = 'error' in expanded ? autoSubmitUrl : expanded.ok;
      setFeedFormData((previous) => ({ ...previous, url: prefillUrl }));
      setTokenError('');
      if (route.kind !== 'token') {
        navigate({ kind: 'token', prefillUrl });
      }
      return;
    }

    hasAutoSubmittedReference.current = true;
    setFeedFieldErrors(EMPTY_FEED_ERRORS);
    void attemptFeedCreation(token ?? '');
  }, [feedFormData.url, isLoading, mayCreate, navigate, route.kind, token]);

  // Keep the hash aligned with in-memory result; only bounce empty deep links to create.
  useEffect(() => {
    if (route.kind !== 'result') return;

    if (result) {
      if (result.feed.feed_token === route.feedToken) return;
      // Studio re-generate commits the new token before navigate runs; follow memory, do not clear.
      navigate({ kind: 'result', feedToken: result.feed.feed_token }, { replace: true });
      return;
    }

    // Unresolved workspace is in-memory only — cold `#/result` without it recovers to create.
    if (!route.feedToken && unresolved) return;

    // Do not carry a prefill URL — that would re-trigger auto-submit and bounce back to result.
    navigate({ kind: 'create' }, { replace: true });
  }, [navigate, result, route, unresolved]);

  useEffect(() => {
    const previousKind = previousRouteKindReference.current;
    const previousCreateEntryKey = previousCreateEntryKeyReference.current;
    previousRouteKindReference.current = route.kind;
    previousCreateEntryKeyReference.current = createEntryKey;

    if (route.kind !== 'create') return;

    const didKindChangeToCreate = previousKind !== 'create';
    const isSameKindCreateEntry = previousKind === 'create' && previousCreateEntryKey !== createEntryKey;
    if (!didKindChangeToCreate && !isSameKindCreateEntry) return;

    clearResult();
    setUnresolved(undefined);
    setTokenError('');
    setTokenDraft('');
    if (isSameKindCreateEntry) {
      setFeedFieldErrors(EMPTY_FEED_ERRORS);
      clearError();
    } else if (feedFieldErrors.form) {
      // token→create non-auth failure: keep Decision error for retry chrome; do not auto-retry.
      hasAutoSubmittedReference.current = true;
    } else {
      // Kind change onto create without a projected form failure (e.g. result recovery).
      clearError();
    }
    if (!route.prefillUrl) autoSubmitUrlReference.current = undefined;
    setFocusCreateComposerKey((current) => current + 1);
  }, [clearError, clearResult, createEntryKey, feedFieldErrors.form, route]);

  const sourceUrl = inMemorySourceUrl(feedFormData.url, result?.feed.url, unresolved?.url);

  const generateFromStudio = async (selectors: StudioSelectors) => {
    const expanded = expandCreateUrl(sourceUrl);
    if ('error' in expanded) {
      throw new Error(expanded.error === 'empty' ? COPY.urlRequired : COPY.invalidUrlFormat);
    }

    try {
      const createdResult = await createFeed(expanded.ok, token ?? '', selectors);
      clearFeedDraftState();
      setUnresolved(undefined);
      navigate({ kind: 'result', feedToken: createdResult.feed.feed_token });
      setTokenError('');
    } catch (submitError) {
      if (!isFeedCreationError(submitError)) throw submitError;

      if (submitError.kind === 'auth' || submitError.nextAction === 'enter_token') {
        clearToken();
        clearError();
        setTokenDraft('');
        if (route.kind !== 'token') navigate({ kind: 'token', prefillUrl: expanded.ok });
        setTokenError(COPY.tokenRejected);
        return;
      }

      // Keep unresolved workspace anchored when save still returns empty extraction.
      if (canRecoverEmptyExtraction(submitError, isStudioEnabled, token ?? '') && unresolved) {
        setUnresolved({ url: expanded.ok, notice: submitError.message });
        clearError();
        throw submitError;
      }

      clearError();
      throw submitError;
    }
  };

  const viewModel = decideJourney({
    creationError,
    feedFieldErrors,
    isCreating,
    route,
    tokenError,
    result,
    unresolved,
  });

  return {
    viewModel,
    isCreating,
    result,
    creationError,
    clearError,
    clearResult,
    retryPreviewFetch,
    feedFormData,
    feedFieldErrors,
    tokenDraft,
    tokenError,
    bookmarkletNotice,
    focusCreateComposerKey,
    submitDisabled,
    feedCreationEnabled,
    onFeedFieldChange,
    onFeedSubmit,
    onSaveToken,
    onCancelTokenPrompt: () => {
      setTokenError('');
      setTokenDraft('');
      clearError();
      navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
    },
    onRetryCreate: () => {
      setFeedFieldErrors(EMPTY_FEED_ERRORS);
      clearError();
      void attemptFeedCreation(token ?? '');
    },
    onCreateAnother: () => {
      clearResult();
      setUnresolved(undefined);
      setFocusCreateComposerKey((current) => current + 1);
      // Keep the prior URL in the form; omit route prefill so the prefill effect
      // does not clear hasAutoSubmitted and auto-resubmit an empty extraction.
      hasAutoSubmittedReference.current = true;
      navigate({ kind: 'create' });
    },
    generateFromStudio,
    onRetryPreview: retryPreviewFetch,
    sourceUrl,
    setBookmarkletNotice,
    setTokenDraft,
    setTokenError,
  };
}

function canRecoverEmptyExtraction(
  failure: FeedCreationError,
  isStudioEnabled: boolean,
  accessToken: string
): boolean {
  return failure.code === EXTRACTION_EMPTY && isStudioEnabled && accessToken.trim().length > 0;
}

function inMemorySourceUrl(
  formUrl: string,
  pageUrl: string | undefined,
  unresolvedUrl: string | undefined
): string {
  const fromForm = formUrl.trim();
  if (fromForm) return fromForm;
  const fromUnresolved = unresolvedUrl?.trim() ?? '';
  if (fromUnresolved) return fromUnresolved;
  return pageUrl?.trim() ?? '';
}
