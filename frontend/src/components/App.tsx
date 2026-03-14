import { useEffect, useState } from 'preact/hooks';
import { ResultDisplay } from './ResultDisplay';
import { CreateFeedPanel, InstanceInfo, QuickToolsPanel, type Strategy } from './AppPanels';
import { useAccessToken } from '../hooks/useAccessToken';
import { useApiMetadata } from '../hooks/useApiMetadata';
import { useFeedConversion } from '../hooks/useFeedConversion';
import { useStrategies } from '../hooks/useStrategies';

const EMPTY_FEED_ERRORS = { url: '', form: '' };

function BrandLockup() {
  return (
    <div class="brand-lockup" aria-label="html2rss">
      <span class="brand-lockup__mark" aria-hidden="true">
        <span />
        <span />
        <span />
      </span>
      <div class="brand-lockup__text">
        <strong>html2rss</strong>
        <span>html to feed</span>
      </div>
    </div>
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
  const { isConverting, result, error: conversionError, convertFeed, clearResult } = useFeedConversion();
  const { strategies, isLoading: strategiesLoading, error: strategiesError } = useStrategies();

  const [feedFormData, setFeedFormData] = useState({ url: '', strategy: 'ssrf_filter' });
  const [feedFieldErrors, setFeedFieldErrors] = useState(EMPTY_FEED_ERRORS);
  const [showTokenPrompt, setShowTokenPrompt] = useState(false);
  const [tokenDraft, setTokenDraft] = useState('');
  const [tokenError, setTokenError] = useState('');

  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (feedFormData.url) return;

    const urlParam = new URLSearchParams(window.location.search).get('url');
    if (!urlParam) return;

    setFeedFormData((prev) => ({ ...prev, url: urlParam }));
  }, [feedFormData.url]);

  useEffect(() => {
    const nextStrategy = strategies[0]?.id;
    if (!nextStrategy) return;

    const hasCurrentStrategy = strategies.some((strategy) => strategy.id === feedFormData.strategy);
    if (!hasCurrentStrategy) setFeedFormData((prev) => ({ ...prev, strategy: nextStrategy }));
  }, [strategies, feedFormData.strategy]);

  const feedCreation = metadata?.instance.feed_creation ?? { enabled: true, access_token_required: true };

  const setFeedField = (key: 'url' | 'strategy', value: string) => {
    setFeedFormData((prev) => ({ ...prev, [key]: value }));
    setFeedFieldErrors((prev) => ({
      ...prev,
      url: key === 'url' ? '' : prev.url,
      form: '',
    }));
  };

  const strategyHint = (strategy: Strategy) => {
    if (strategy.id === 'ssrf_filter') return 'Direct fetch for standard documents and static pages.';
    if (strategy.id === 'browserless')
      return 'Rendered browser pass for JavaScript-heavy pages, SPAs, and delayed content.';
    return strategy.name;
  };

  const handleFeedSubmit = async (event: Event) => {
    event.preventDefault();
    setFeedFieldErrors(EMPTY_FEED_ERRORS);

    if (!feedFormData.url.trim()) {
      setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, url: 'Source URL is required.' });
      return;
    }

    if (!feedCreation.enabled) {
      setFeedFieldErrors({
        ...EMPTY_FEED_ERRORS,
        form: 'Custom feed generation is disabled for this instance.',
      });
      return;
    }

    if (feedCreation.access_token_required && !hasToken) {
      setShowTokenPrompt(true);
      setTokenError('Add an access token to create a custom feed.');
      return;
    }

    try {
      await convertFeed(feedFormData.url, feedFormData.strategy, token ?? '');
    } catch (submitError) {
      const message = submitError instanceof Error ? submitError.message : 'Unable to start feed generation.';
      if (message.toLowerCase().includes('url')) {
        setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, url: message });
      } else {
        setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, form: message });
      }
    }
  };

  const handleSaveToken = async () => {
    try {
      await saveToken(tokenDraft);
      setTokenError('');
      setShowTokenPrompt(false);
      setTokenDraft('');
    } catch (error) {
      setTokenError(error instanceof Error ? error.message : 'Unable to save access token.');
    }
  };

  const handleCreateAnother = () => {
    clearResult();
  };

  if (metadataLoading || tokenLoading) {
    return (
      <section class="workspace-shell workspace-shell--loading">
        <BrandLockup />
        <div class="status-card" aria-live="polite">
          <div class="status-card__spinner" aria-hidden="true" />
          <div>
            <strong>Loading instance</strong>
            <p>Reading feed-generation capabilities.</p>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section class="workspace-shell">
      <header class={`workspace-frame${result ? ' workspace-frame--compact' : ''}`}>
        <div class="workspace-frame__masthead">
          <BrandLockup />
        </div>
        {!result && (
          <div class="workspace-frame__titleblock">
            <h1>Turn web pages into stable feeds.</h1>
          </div>
        )}
      </header>

      {(metadataError || tokenStateError) && (
        <section class="notice notice--error" role="alert">
          <div class="notice__title">Instance metadata unavailable</div>
          <p>{metadataError ?? tokenStateError}</p>
        </section>
      )}

      {result ? (
        <ResultDisplay result={result} onCreateAnother={handleCreateAnother} />
      ) : (
        <div class="support-stack">
          <CreateFeedPanel
            feedFormData={feedFormData}
            feedFieldErrors={feedFieldErrors}
            conversionError={conversionError}
            isConverting={isConverting}
            strategies={strategies}
            strategiesLoading={strategiesLoading}
            strategiesError={strategiesError}
            feedCreationEnabled={feedCreation.enabled}
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
            }}
            onSaveToken={handleSaveToken}
            onCancelTokenPrompt={() => {
              setShowTokenPrompt(false);
              setTokenError('');
            }}
            strategyHint={strategyHint}
          />
          <QuickToolsPanel />
        </div>
      )}

      {!result && (
        <InstanceInfo
          feedCreationEnabled={feedCreation.enabled}
          accessTokenRequired={feedCreation.access_token_required}
          hasAccessToken={hasToken}
          onClearToken={() => {
            clearToken();
            setShowTokenPrompt(false);
          }}
        />
      )}
    </section>
  );
}
