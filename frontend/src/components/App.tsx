import { useEffect, useRef, useState } from 'preact/hooks';
import { ResultDisplay } from './ResultDisplay';
import { CreateFeedPanel, UtilityStrip, type Strategy } from './AppPanels';
import { useAccessToken } from '../hooks/useAccessToken';
import { useApiMetadata } from '../hooks/useApiMetadata';
import { useFeedConversion } from '../hooks/useFeedConversion';
import { useStrategies } from '../hooks/useStrategies';
import { normalizeUserUrl } from '../utils/url';

const EMPTY_FEED_ERRORS = { url: '', form: '' };
const DEFAULT_FEED_CREATION = { enabled: true, access_token_required: true };
const preferredStrategy = (strategies: { id: string }[]) =>
  strategies.find((strategy) => strategy.id === 'faraday')?.id ?? strategies[0]?.id;

interface ConversionErrorWithMeta extends Error {
  manualRetryStrategy?: string;
}

function BrandLockup() {
  return (
    <a class="brand-lockup" href="/" aria-label="html2rss">
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
  } = useFeedConversion();
  const { strategies, isLoading: strategiesLoading, error: strategiesError } = useStrategies();

  const [feedFormData, setFeedFormData] = useState({ url: '', strategy: '' });
  const [feedFieldErrors, setFeedFieldErrors] = useState(EMPTY_FEED_ERRORS);
  const [showTokenPrompt, setShowTokenPrompt] = useState(false);
  const [tokenDraft, setTokenDraft] = useState('');
  const [tokenError, setTokenError] = useState('');
  const [manualRetryStrategy, setManualRetryStrategy] = useState('');
  const [focusCreateComposerKey, setFocusCreateComposerKey] = useState(0);
  const autoSubmitUrlRef = useRef<string | null>(null);
  const hasAutoSubmittedRef = useRef(false);
  const selectedStrategy = feedFormData.strategy || preferredStrategy(strategies) || '';

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const urlParam = new URLSearchParams(window.location.search).get('url');
    if (!urlParam) return;
    autoSubmitUrlRef.current = urlParam;
    if (feedFormData.url) return;

    setFeedFormData((prev) => ({ ...prev, url: urlParam }));
  }, [feedFormData.url]);

  useEffect(() => {
    const nextStrategy = preferredStrategy(strategies);
    if (!nextStrategy) return;

    const hasCurrentStrategy = strategies.some((strategy) => strategy.id === feedFormData.strategy);
    if (!hasCurrentStrategy) setFeedFormData((prev) => ({ ...prev, strategy: nextStrategy }));
  }, [strategies, feedFormData.strategy]);

  const feedCreation = metadata?.instance.feed_creation ?? DEFAULT_FEED_CREATION;
  const featuredFeeds = metadata?.instance.featured_feeds ?? [];
  const submitDisabled = isConverting || strategiesLoading || !feedCreation.enabled || showTokenPrompt;

  const setFeedField = (key: 'url' | 'strategy', value: string) => {
    setFeedFormData((prev) => ({ ...prev, [key]: value }));
    setFeedFieldErrors((prev) => ({
      ...prev,
      url: key === 'url' ? '' : prev.url,
      form: '',
    }));
    setManualRetryStrategy('');
    clearError();
  };

  const strategyHint = (strategy: Strategy) => {
    if (strategy.id === 'faraday') return 'Start here for most pages.';
    if (strategy.id === 'browserless') return 'Use this if the page loads content with JavaScript.';
    return strategy.name;
  };

  const isAccessTokenError = (message: string) => {
    const normalized = message.toLowerCase();
    const mentionsAuthToken =
      normalized.includes('access token') ||
      normalized.includes('token') ||
      normalized.includes('authentication') ||
      normalized.includes('bearer');

    return (
      normalized.includes('unauthorized') ||
      normalized.includes('invalid token') ||
      normalized.includes('token rejected') ||
      normalized.includes('authentication') ||
      (normalized.includes('forbidden') && mentionsAuthToken)
    );
  };

  const isActionableStrategySwitch = (message: string, currentStrategy: string, retryStrategy: string) => {
    if (currentStrategy !== 'faraday' || retryStrategy !== 'browserless') return false;

    const normalized = message.toLowerCase();
    return !(
      normalized.includes('unauthorized') ||
      normalized.includes('forbidden') ||
      normalized.includes('not allowed') ||
      normalized.includes('disabled') ||
      normalized.includes('access token') ||
      normalized.includes('token') ||
      normalized.includes('authentication') ||
      normalized.includes('bad request') ||
      normalized.includes('url') ||
      normalized.includes('unsupported strategy')
    );
  };

  const attemptFeedCreation = async (accessToken: string, strategyOverride?: string) => {
    const strategy = strategyOverride || selectedStrategy;
    const normalizedUrl = normalizeUserUrl(feedFormData.url);

    if (!normalizedUrl) {
      setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, url: 'Source URL is required.' });
      return false;
    }

    if (!strategy) {
      setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, form: 'Strategy is required' });
      return false;
    }

    if (!feedCreation.enabled) {
      setFeedFieldErrors({
        ...EMPTY_FEED_ERRORS,
        form: 'Custom feed generation is disabled for this instance.',
      });
      return false;
    }

    if (feedCreation.access_token_required && !accessToken) {
      setFeedFormData((prev) => ({ ...prev, url: normalizedUrl }));
      clearError();
      setShowTokenPrompt(true);
      setTokenError('');
      return false;
    }

    try {
      setFeedFormData((prev) => ({ ...prev, url: normalizedUrl }));
      await convertFeed(normalizedUrl, strategy, accessToken);
      setShowTokenPrompt(false);
      setTokenError('');
      setManualRetryStrategy('');
      return true;
    } catch (submitError) {
      const message = submitError instanceof Error ? submitError.message : 'Unable to start feed generation.';
      const retryStrategy = (submitError as ConversionErrorWithMeta).manualRetryStrategy ?? '';
      setManualRetryStrategy(
        isActionableStrategySwitch(message, strategy, retryStrategy) ? retryStrategy : ''
      );

      if (feedCreation.access_token_required && isAccessTokenError(message)) {
        clearToken();
        clearError();
        setTokenDraft('');
        setShowTokenPrompt(true);
        setTokenError('Access token was rejected. Paste a valid token to continue.');
        setFeedFieldErrors(EMPTY_FEED_ERRORS);
        return false;
      }

      if (message.toLowerCase().includes('url')) {
        setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, url: message });
      } else {
        setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, form: message });
      }
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
    setManualRetryStrategy('');
    setFocusCreateComposerKey((current) => current + 1);
  };

  const handleRetryWithStrategy = () => {
    if (!manualRetryStrategy) return;

    setFeedFormData((prev) => ({ ...prev, strategy: manualRetryStrategy }));
    setFeedFieldErrors(EMPTY_FEED_ERRORS);
    clearError();
    void attemptFeedCreation(token ?? '', manualRetryStrategy);
  };

  useEffect(() => {
    const autoSubmitUrl = autoSubmitUrlRef.current;
    if (!autoSubmitUrl || hasAutoSubmittedRef.current) return;
    if (strategiesLoading || metadataLoading || tokenLoading) return;
    if (feedFormData.url !== autoSubmitUrl || !selectedStrategy) return;

    if (feedCreation.access_token_required && !token) {
      hasAutoSubmittedRef.current = true;
      setFeedFormData((prev) => ({ ...prev, url: normalizeUserUrl(autoSubmitUrl) }));
      setShowTokenPrompt(true);
      setTokenError('');
      return;
    }

    hasAutoSubmittedRef.current = true;
    setFeedFieldErrors(EMPTY_FEED_ERRORS);
    void attemptFeedCreation(token ?? '');
  }, [
    feedCreation.access_token_required,
    feedFormData.url,
    metadataLoading,
    selectedStrategy,
    strategiesLoading,
    token,
    tokenLoading,
  ]);

  if (metadataLoading || tokenLoading) {
    return (
      <section class="workspace-shell workspace-shell--centered workspace-shell--loading">
        <BrandLockup />
        <div class="ui-card ui-card--notice ui-card--roomy notice" data-state="loading" aria-live="polite">
          <div class="notice__spinner" aria-hidden="true" />
          <div>
            <strong>Loading instance</strong>
            <p>Reading feed-generation capabilities.</p>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section class="workspace-shell workspace-shell--centered">
      <header class="workspace-hero">
        <BrandLockup />
      </header>

      {(metadataError || tokenStateError) && (
        <section class="ui-card ui-card--notice ui-card--padded notice" data-tone="error" role="alert">
          <div class="notice__title">Instance metadata unavailable</div>
          <p>{metadataError ?? tokenStateError}</p>
        </section>
      )}

      {result ? (
        <ResultDisplay result={result} onCreateAnother={handleCreateAnother} />
      ) : (
        <>
          <CreateFeedPanel
            focusComposerKey={focusCreateComposerKey}
            feedFormData={{ ...feedFormData, strategy: selectedStrategy }}
            feedFieldErrors={feedFieldErrors}
            conversionError={conversionError}
            isConverting={isConverting}
            submitDisabled={submitDisabled}
            strategies={strategies}
            strategiesLoading={strategiesLoading}
            strategiesError={strategiesError}
            feedCreationEnabled={feedCreation.enabled}
            featuredFeeds={featuredFeeds}
            accessTokenRequired={feedCreation.access_token_required}
            hasAccessToken={hasToken}
            tokenDraft={tokenDraft}
            tokenError={tokenError}
            showTokenPrompt={showTokenPrompt}
            onFeedSubmit={handleFeedSubmit}
            onFeedFieldChange={setFeedField}
            onTokenDraftChange={(value) => {
              setTokenDraft(value);
              setTokenError('');
              clearError();
            }}
            onSaveToken={handleSaveToken}
            onCancelTokenPrompt={() => {
              setShowTokenPrompt(false);
              setTokenError('');
              clearError();
            }}
            manualRetryStrategy={manualRetryStrategy}
            onRetryWithStrategy={handleRetryWithStrategy}
            strategyHint={strategyHint}
          />
          <UtilityStrip
            hidden={showTokenPrompt}
            hasAccessToken={hasToken}
            openapiUrl={metadata?.api.openapi_url ?? null}
            onClearToken={() => {
              clearToken();
              setShowTokenPrompt(false);
              clearError();
            }}
          />
        </>
      )}
    </section>
  );
}
