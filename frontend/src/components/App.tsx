import { useEffect, useRef, useState } from 'preact/hooks';
import type { JSX } from 'preact';
import { ResultDisplay } from './ResultDisplay';
import { CreateFeedPanel, UtilityStrip } from './AppPanels';
import { Notice } from './Notice';
import { useAccessToken } from '../hooks/useAccessToken';
import { useApiMetadata } from '../hooks/useApiMetadata';
import { useFeedConversion } from '../hooks/useFeedConversion';
import { useAppRoute } from '../routes/appRoute';
import { clearFeedDraftState, loadFeedDraftState, saveFeedDraftState } from '../utils/feedWorkflowStorage';
import { normalizeUserUrl } from '../utils/url';
import type { WorkflowState } from './AppPanels';
import type { FeedCreationError } from '../api/contracts';

const EMPTY_FEED_ERRORS = { url: '', form: '' };
const DEFAULT_FEED_CREATION = { enabled: true, access_token_required: true };

function deriveWorkflowState({
  conversionError,
  feedFieldErrors,
  isConverting,
  routeKind,
  tokenError,
  tokenStateError,
  metadataError,
}: {
  conversionError?: FeedCreationError;
  feedFieldErrors: { url: string; form: string };
  isConverting: boolean;
  routeKind: string;
  tokenError: string;
  tokenStateError?: string;
  metadataError?: string;
}): WorkflowState {
  if (tokenStateError || metadataError) return 'error';
  if (routeKind === 'token' || tokenError) return 'token_prompt';
  if (conversionError?.nextAction === 'enter_token' || conversionError?.kind === 'auth')
    return 'token_prompt';
  if (routeKind === 'result') return 'result';
  if (feedFieldErrors.url || feedFieldErrors.form || conversionError?.nextAction === 'correct_input') {
    return 'error';
  }
  if (isConverting) return 'submitting';

  if (conversionError) return 'error';

  return 'create';
}

function BrandLockup({ onNavigateHome }: { onNavigateHome: () => void }) {
  return (
    <a
      class="brand-lockup"
      href="/#/create"
      aria-label="html2rss"
      onClick={(event) => {
        event.preventDefault();
        onNavigateHome();
      }}
    >
      <span class="brand-lockup__mark" aria-hidden="true">
        <span />
        <span />
        <span />
      </span>
      <strong class="brand-lockup__wordmark">html2rss</strong>
    </a>
  );
}

export function App() {
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
  let visibleRouteKind = 'create';
  if (activeResult) {
    visibleRouteKind = 'result';
  } else if (isTokenRoute) {
    visibleRouteKind = 'token';
  }
  const workflowState: WorkflowState = deriveWorkflowState({
    conversionError,
    feedFieldErrors,
    isConverting,
    routeKind: visibleRouteKind,
    tokenError,
    tokenStateError,
    metadataError,
  });

  useEffect(() => {
    if (!route.prefillUrl) return;
    autoSubmitUrlReference.current = route.prefillUrl;
    if (feedFormData.url) return;

    setFeedFormData((previous) => ({ ...previous, url: route.prefillUrl ?? previous.url }));
  }, [feedFormData.url, route.prefillUrl]);

  const feedCreation = metadata?.instance.feed_creation ?? DEFAULT_FEED_CREATION;
  const featuredFeeds = metadata?.instance.featured_feeds ?? [];
  const submitDisabled = isConverting || !feedCreation.enabled || isTokenRoute;

  const setFeedField = (key: 'url', value: string) => {
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

  const handleFeedSubmit = async (event: Event) => {
    event.preventDefault();
    setFeedFieldErrors(EMPTY_FEED_ERRORS);
    await attemptFeedCreation(token ?? '');
  };

  const handleSaveToken = async () => {
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

  const handleCreateAnother = () => {
    clearResult();
    setFocusCreateComposerKey((current) => current + 1);
    navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
  };

  const handleRetryCreation = () => {
    setFeedFieldErrors(EMPTY_FEED_ERRORS);
    clearError();
    void attemptFeedCreation(token ?? '');
  };

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

  let bodyContent: JSX.Element;
  if (metadataLoading || tokenLoading) {
    bodyContent = (
      <Notice title="Loading instance" state="loading" ariaLive="polite">
        <p>Reading feed-generation capabilities.</p>
      </Notice>
    );
  } else if (activeResult) {
    bodyContent = (
      <ResultDisplay
        result={activeResult}
        workflowState={workflowState}
        onCreateAnother={handleCreateAnother}
        onRetryPreview={retryPreviewFetch}
      />
    );
  } else {
    bodyContent = (
      <CreateFeedPanel
        focusComposerKey={focusCreateComposerKey}
        workflowState={workflowState}
        feedFormData={feedFormData}
        feedFieldErrors={feedFieldErrors}
        conversionError={conversionError}
        errorKind={conversionError?.kind}
        isConverting={isConverting}
        submitDisabled={submitDisabled}
        feedCreationEnabled={feedCreation.enabled}
        featuredFeeds={featuredFeeds}
        tokenDraft={tokenDraft}
        tokenError={tokenError}
        showTokenPrompt={isTokenRoute}
        onFeedSubmit={handleFeedSubmit}
        onFeedFieldChange={setFeedField}
        onTokenDraftChange={(value) => {
          setTokenDraft(value);
          setTokenError('');
          clearError();
        }}
        onSaveToken={handleSaveToken}
        onCancelTokenPrompt={() => {
          setTokenError('');
          clearError();
          navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
        }}
        onRetryCreate={handleRetryCreation}
      />
    );
  }

  return (
    <div class="page-shell">
      <main class="page-main">
        <section class="workspace-shell workspace-shell--centered">
          <header class="workspace-hero">
            <BrandLockup onNavigateHome={() => navigate({ kind: 'create' })} />
          </header>

          <div class="workspace-content">
            {bookmarkletNotice && (
              <Notice
                title="How to use the Bookmarklet"
                actions={
                  <button
                    type="button"
                    class="btn btn--quiet btn--linkish"
                    onClick={() => setBookmarkletNotice('')}
                  >
                    Dismiss
                  </button>
                }
              >
                <p style="margin: 0; line-height: 1.5;">
                  Drag the "Bookmarklet" link from the footer to your browser's bookmarks bar. When viewing
                  any website you want to convert to RSS, click the bookmark to automatically prefill its URL
                  here.
                </p>
              </Notice>
            )}

            {(metadataError || tokenStateError) && (
              <Notice tone="error" title="Instance metadata unavailable">
                <p>{metadataError ?? tokenStateError}</p>
              </Notice>
            )}

            {bodyContent}
          </div>
        </section>
      </main>

      <footer class="app-footer" aria-label="Footer navigation">
        <div class="app-footer__inner">
          <UtilityStrip
            hasAccessToken={hasToken}
            openapiUrl={metadata?.api.openapi_url}
            onClearToken={() => {
              clearToken();
              clearError();
              navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
            }}
            onShowBookmarkletHelp={() => setBookmarkletNotice('show')}
          />
        </div>
      </footer>
    </div>
  );
}
