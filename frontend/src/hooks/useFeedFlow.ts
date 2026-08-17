import { useEffect, useRef, useState } from 'preact/hooks';
import { useFeedConversion } from './useFeedConversion';
import { clearFeedDraftState, loadFeedDraftState, saveFeedDraftState } from '../utils/feedWorkflowStorage';
import { expandCreateUrl } from '../utils/url';
import type { FeedCreationError } from '../api/contracts';
import { COPY } from '../copy';
import type { AppRoute } from '../routes/appRoute';
import type { MayCreateResult } from '../session';

const EMPTY_FEED_ERRORS = { url: '', form: '' };

interface RouteNavigationOptions {
  replace?: boolean;
}

export interface FeedFlowDependencies {
  token: string | undefined;
  isLoading: boolean;
  feedCreationEnabled: boolean;
  mayCreate: (accessToken?: string) => MayCreateResult;
  saveToken: (token: string) => Promise<void>;
  clearToken: () => void;
  route: AppRoute;
  navigate: (route: AppRoute, options?: RouteNavigationOptions) => void;
  createEntryKey: number;
}

export function useFeedFlow({
  token,
  isLoading,
  feedCreationEnabled,
  mayCreate,
  saveToken,
  clearToken,
  route,
  navigate,
  createEntryKey,
}: FeedFlowDependencies) {
  const {
    isConverting,
    result,
    error: conversionError,
    convertFeed,
    clearError,
    clearResult,
    retryPreviewFetch,
  } = useFeedConversion();

  const [feedFormData, setFeedFormData] = useState(() => loadFeedDraftState() ?? { url: '' });
  const [feedFieldErrors, setFeedFieldErrors] = useState(EMPTY_FEED_ERRORS);
  const [tokenDraft, setTokenDraft] = useState('');
  const [tokenError, setTokenError] = useState('');
  const [bookmarkletNotice, setBookmarkletNotice] = useState('');
  const [focusCreateComposerKey, setFocusCreateComposerKey] = useState(0);

  const routePrefillUrl = route.kind === 'result' ? undefined : route.prefillUrl;
  const autoSubmitUrlReference = useRef<string | undefined>(routePrefillUrl);
  const hasAutoSubmittedReference = useRef(false);
  const previousRouteKindReference = useRef(route.kind);
  const previousCreateEntryKeyReference = useRef(createEntryKey);

  // Prefill URL effect
  useEffect(() => {
    if (!routePrefillUrl) return;
    autoSubmitUrlReference.current = routePrefillUrl;
    if (feedFormData.url) return;

    setFeedFormData((previous) => ({ ...previous, url: routePrefillUrl }));
  }, [feedFormData.url, routePrefillUrl]);

  const submitDisabled = isConverting || !feedCreationEnabled;

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

  const attemptFeedCreation = async (accessToken: string) => {
    const expanded = expandCreateUrl(feedFormData.url);
    if ('error' in expanded) {
      setFeedFieldErrors({
        ...EMPTY_FEED_ERRORS,
        url: expanded.error === 'empty' ? COPY.sourceUrlRequired : COPY.invalidUrlFormat,
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
      const createdResult = await convertFeed(normalizedUrl, accessToken);
      clearFeedDraftState();
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

      setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, form: failure.message });
      if (route.kind === 'token') {
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
      const prefillUrl = expanded.error ? autoSubmitUrl : expanded.ok;
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

  // Recover unmatched result routes onto a remounted create view.
  useEffect(() => {
    if (route.kind !== 'result') return;

    const isMatched = Boolean(result && result.feed.feed_token === route.feedToken);
    if (isMatched) return;

    // Do not carry a prefill URL — that would re-trigger auto-submit and bounce back to result.
    navigate({ kind: 'create' }, { replace: true });
  }, [navigate, result, route]);

  useEffect(() => {
    const previousKind = previousRouteKindReference.current;
    const previousCreateEntryKey = previousCreateEntryKeyReference.current;
    previousRouteKindReference.current = route.kind;
    previousCreateEntryKeyReference.current = createEntryKey;

    if (route.kind !== 'create') return;

    const didKindChangeToCreate = previousKind !== 'create';
    const isSameKindCreateEntry = previousKind === 'create' && previousCreateEntryKey !== createEntryKey;
    if (!didKindChangeToCreate && !isSameKindCreateEntry) return;

    clearError();
    clearResult();
    setTokenError('');
    if (isSameKindCreateEntry) setFeedFieldErrors(EMPTY_FEED_ERRORS);
    if (!route.prefillUrl) autoSubmitUrlReference.current = undefined;
    setFocusCreateComposerKey((current) => current + 1);
  }, [createEntryKey, route]);

  return {
    isConverting,
    result,
    conversionError,
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
      setFocusCreateComposerKey((current) => current + 1);
      navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
    },
    onRetryPreview: retryPreviewFetch,
    setBookmarkletNotice,
    setTokenDraft,
    setTokenError,
  };
}
