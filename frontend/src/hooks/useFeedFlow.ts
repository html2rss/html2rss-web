import { useEffect, useRef, useState } from 'preact/hooks';
import { useFeedConversion } from './useFeedConversion';
import { clearFeedDraftState, loadFeedDraftState, saveFeedDraftState } from '../utils/feedWorkflowStorage';
import { normalizeUserUrl } from '../utils/url';
import type { FeedCreationError } from '../api/contracts';
import { COPY } from '../copy';
import type { AppRoute } from '../routes/appRoute';

const EMPTY_FEED_ERRORS = { url: '', form: '' };
const DEFAULT_FEED_CREATION = { enabled: true, access_token_required: true };

interface RouteNavigationOptions {
  replace?: boolean;
}

export interface FeedFlowDependencies {
  token: string | undefined;
  metadata: any;
  isLoading: boolean;
  saveToken: (token: string) => Promise<void>;
  clearToken: () => void;
  route: AppRoute;
  navigate: (route: AppRoute, options?: RouteNavigationOptions) => void;
}

export function useFeedFlow({
  token,
  metadata,
  isLoading,
  saveToken,
  clearToken,
  route,
  navigate,
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

  const autoSubmitUrlReference = useRef<string | undefined>(route.prefillUrl);
  const hasAutoSubmittedReference = useRef(false);

  // Prefill URL effect
  useEffect(() => {
    if (!route.prefillUrl) return;
    autoSubmitUrlReference.current = route.prefillUrl;
    if (feedFormData.url) return;

    setFeedFormData((previous) => ({ ...previous, url: route.prefillUrl ?? previous.url }));
  }, [feedFormData.url, route.prefillUrl]);

  const feedCreation = metadata?.instance.feed_creation ?? DEFAULT_FEED_CREATION;
  const submitDisabled = isConverting || !feedCreation.enabled;

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
    const normalizedUrl = normalizeUserUrl(feedFormData.url);

    if (!normalizedUrl) {
      setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, url: 'Source URL is required.' });
      return false;
    }

    if (!feedCreation.enabled) {
      setFeedFieldErrors({
        ...EMPTY_FEED_ERRORS,
        form: COPY.creationDisabled,
      });
      return false;
    }

    if (feedCreation.access_token_required && !accessToken) {
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
        setTokenError('Access token was rejected. Paste a valid token to continue.');
        setFeedFieldErrors(EMPTY_FEED_ERRORS);
        return false;
      }

      if (failure.nextAction === 'correct_input') {
        setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, form: failure.message });
        return false;
      }

      setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, form: failure.message });
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
      setTokenError(error instanceof Error ? error.message : 'Unable to save access token.');
    }
  };

  // Auto-submit effect
  useEffect(() => {
    const autoSubmitUrl = autoSubmitUrlReference.current;
    if (!autoSubmitUrl || hasAutoSubmittedReference.current) return;
    if (isLoading) return;
    if (feedFormData.url !== autoSubmitUrl) return;

    if (feedCreation.access_token_required && !token) {
      hasAutoSubmittedReference.current = true;
      setFeedFormData((previous) => ({ ...previous, url: normalizeUserUrl(autoSubmitUrl) }));
      setTokenError('');
      if (route.kind !== 'token') {
        navigate({ kind: 'token', prefillUrl: normalizeUserUrl(autoSubmitUrl) });
      }
      return;
    }

    hasAutoSubmittedReference.current = true;
    setFeedFieldErrors(EMPTY_FEED_ERRORS);
    void attemptFeedCreation(token ?? '');
  }, [feedCreation.access_token_required, feedFormData.url, isLoading, navigate, route.kind, token]);

  // Fail-closed result route: only valid with matching in-memory result.
  useEffect(() => {
    if (route.kind !== 'result') return;

    const isMatched = Boolean(result && result.feed.feed_token === route.feedToken);
    if (isMatched) return;

    // Do not carry a prefill URL — that would re-trigger auto-submit and bounce back to result.
    navigate({ kind: 'create' }, { replace: true });
  }, [navigate, result, route]);

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
    feedCreationEnabled: feedCreation.enabled,
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
