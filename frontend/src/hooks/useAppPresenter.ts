import { useEffect, useRef, useState } from 'preact/hooks';
import { useAccessToken } from './useAccessToken';
import { useApiMetadata } from './useApiMetadata';
import { useFeedConversion } from './useFeedConversion';
import { useAppRoute } from '../routes/appRoute';
import { clearFeedDraftState, loadFeedDraftState, saveFeedDraftState } from '../utils/feedWorkflowStorage';
import { normalizeUserUrl } from '../utils/url';
import { deriveAppViewModel } from '../appViewModel';
import type { FeedCreationError } from '../api/contracts';

const EMPTY_FEED_ERRORS = { url: '', form: '' };
const DEFAULT_FEED_CREATION = { enabled: true, access_token_required: true };

/**
 * Custom hook that consolidates app coordination, route synchronization,
 * auto-submit effects, and side-effects.
 */
export function useAppPresenter() {
  const { route, navigate } = useAppRoute();
  const {
    token,
    hasToken,
    saveToken,
    clearToken,
    isLoading: tokenLoading,
    error: tokenStateError,
  } = useAccessToken();
  const { metadata, isLoading: metadataLoading, error: metadataError } = useApiMetadata();
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

  const isTokenRoute = route.kind === 'token';
  const activeResult =
    route.kind === 'result' && result?.feed.feed_token === route.feedToken ? result : undefined;

  let visibleRouteKind: 'create' | 'token' | 'result' = 'create';
  if (activeResult) {
    visibleRouteKind = 'result';
  } else if (isTokenRoute) {
    visibleRouteKind = 'token';
  }

  const viewModel = deriveAppViewModel({
    conversionError,
    feedFieldErrors,
    isConverting,
    routeKind: visibleRouteKind,
    tokenError,
    tokenStateError,
    metadataError,
    result: activeResult,
  });

  // Prefill URL effect
  useEffect(() => {
    if (!route.prefillUrl) return;
    autoSubmitUrlReference.current = route.prefillUrl;
    if (feedFormData.url) return;

    setFeedFormData((previous) => ({ ...previous, url: route.prefillUrl ?? previous.url }));
  }, [feedFormData.url, route.prefillUrl]);

  const feedCreation = metadata?.instance.feed_creation ?? DEFAULT_FEED_CREATION;
  const featuredFeeds = metadata?.instance.featured_feeds ?? [];
  const submitDisabled = isConverting || !feedCreation.enabled || viewModel.kind === 'token_prompt';

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
        form: 'Feed creation is disabled on this instance.',
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

  const onCreateAnother = () => {
    clearResult();
    setFocusCreateComposerKey((current) => current + 1);
    navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
  };

  const onRetryCreate = () => {
    setFeedFieldErrors(EMPTY_FEED_ERRORS);
    clearError();
    void attemptFeedCreation(token ?? '');
  };

  // Auto-submit effect
  useEffect(() => {
    const autoSubmitUrl = autoSubmitUrlReference.current;
    if (!autoSubmitUrl || hasAutoSubmittedReference.current) return;
    if (metadataLoading || tokenLoading) return;
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
  }, [
    feedCreation.access_token_required,
    feedFormData.url,
    metadataLoading,
    navigate,
    route.kind,
    token,
    tokenLoading,
  ]);

  return {
    route,
    viewModel,
    feedFormData,
    feedFieldErrors,
    tokenDraft,
    tokenError,
    bookmarkletNotice,
    focusCreateComposerKey,
    metadata,
    hasToken,
    submitDisabled,
    feedCreationEnabled: feedCreation.enabled,
    featuredFeeds,
    metadataLoading,
    tokenLoading,
    metadataError,
    tokenStateError,
    onFeedSubmit,
    onFeedFieldChange,
    onTokenDraftChange: (value: string) => {
      setTokenDraft(value);
      setTokenError('');
      clearError();
    },
    onSaveToken,
    onCancelTokenPrompt: () => {
      setTokenError('');
      clearError();
      navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
    },
    onRetryCreate,
    onCreateAnother,
    onRetryPreview: retryPreviewFetch,
    onClearToken: () => {
      clearToken();
      clearError();
      navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
    },
    onShowBookmarkletHelp: () => setBookmarkletNotice('show'),
    setBookmarkletNotice,
    navigate,
  };
}
