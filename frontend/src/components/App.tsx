import { useEffect, useState } from 'preact/hooks';
import { ResultDisplay } from './ResultDisplay';
import { GuestOnboardingPanel, MemberConvertPanel, type Strategy } from './AppPanels';
import { useAuth } from '../hooks/useAuth';
import { useFeedConversion } from '../hooks/useFeedConversion';
import { useStrategies } from '../hooks/useStrategies';

type ViewMode = 'result' | 'guest-demo' | 'guest-auth' | 'member';

const EMPTY_AUTH_ERRORS = { username: '', token: '', form: '' };
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
        <span>HTML ingestion to RSS feed output</span>
      </div>
    </div>
  );
}

export function App() {
  const {
    isAuthenticated,
    username,
    token,
    login,
    logout,
    isLoading: authLoading,
    error: authError,
  } = useAuth();
  const { isConverting, result, error, convertFeed, clearResult } = useFeedConversion();
  const { strategies, isLoading: strategiesLoading, error: strategiesError } = useStrategies(token);

  const [showAuthForm, setShowAuthForm] = useState(false);
  const [authFormData, setAuthFormData] = useState({ username: '', token: '' });
  const [authFieldErrors, setAuthFieldErrors] = useState(EMPTY_AUTH_ERRORS);
  const [feedFormData, setFeedFormData] = useState({ url: '', strategy: 'ssrf_filter' });
  const [feedFieldErrors, setFeedFieldErrors] = useState(EMPTY_FEED_ERRORS);
  const [demoError, setDemoError] = useState('');

  useEffect(() => {
    if (isAuthenticated) setShowAuthForm(false);
  }, [isAuthenticated]);

  useEffect(() => {
    if (strategies.length > 0 && !feedFormData.strategy) {
      setFeedFormData((prev) => ({ ...prev, strategy: strategies[0].id }));
    }
  }, [strategies, feedFormData.strategy]);

  const mode: ViewMode = result
    ? 'result'
    : isAuthenticated
      ? 'member'
      : showAuthForm
        ? 'guest-auth'
        : 'guest-demo';

  const setAuthField = (key: 'username' | 'token', value: string) => {
    setAuthFormData((prev) => ({ ...prev, [key]: value }));
  };

  const setFeedField = (key: 'url' | 'strategy', value: string) => {
    setFeedFormData((prev) => ({ ...prev, [key]: value }));
  };

  const strategyHint = (strategy: Strategy) => {
    if (strategy.id === 'ssrf_filter') return 'Direct fetch. Fast path for standard documents.';
    if (strategy.id === 'browserless')
      return 'Browser render. Use for JavaScript-heavy pages and SPA output.';
    return strategy.name;
  };

  const handleAuthSubmit = async (event: Event) => {
    event.preventDefault();
    setAuthFieldErrors(EMPTY_AUTH_ERRORS);

    if (!authFormData.username.trim()) {
      setAuthFieldErrors({ ...EMPTY_AUTH_ERRORS, username: 'Username is required.' });
      return;
    }
    if (!authFormData.token.trim()) {
      setAuthFieldErrors({ ...EMPTY_AUTH_ERRORS, token: 'Token is required.' });
      return;
    }

    try {
      await login(authFormData.username, authFormData.token);
    } catch (submitError) {
      setAuthFieldErrors({
        ...EMPTY_AUTH_ERRORS,
        form: submitError instanceof Error ? submitError.message : 'Unable to authenticate.',
      });
    }
  };

  const handleFeedSubmit = async (event: Event) => {
    event.preventDefault();
    setFeedFieldErrors(EMPTY_FEED_ERRORS);

    if (!feedFormData.url.trim()) {
      setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, url: 'Website URL is required.' });
      return;
    }

    try {
      await convertFeed(feedFormData.url, feedFormData.strategy, token ?? '');
    } catch (submitError) {
      const message = submitError instanceof Error ? submitError.message : 'Unable to start conversion.';
      if (message.toLowerCase().includes('url')) {
        setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, url: message });
      } else {
        setFeedFieldErrors({ ...EMPTY_FEED_ERRORS, form: message });
      }
    }
  };

  const handleLogout = () => {
    logout();
    setShowAuthForm(false);
    clearResult();
  };

  const handleDemoConversion = async (url: string) => {
    setDemoError('');
    try {
      const demoStrategy = strategies[0]?.id ?? 'ssrf_filter';
      await convertFeed(url, demoStrategy, 'CHANGE_ME_DEMO_TOKEN');
    } catch (submitError) {
      setDemoError(submitError instanceof Error ? submitError.message : 'Demo conversion failed.');
    }
  };

  const handleSignInFromResult = () => {
    clearResult();
    setShowAuthForm(true);
  };

  if (authLoading) {
    return (
      <section class="workspace-shell workspace-shell--loading">
        <BrandLockup />
        <div class="status-card" aria-live="polite">
          <div class="status-card__spinner" aria-hidden="true" />
          <div>
            <strong>Booting session</strong>
            <p>Checking stored credentials and available strategies.</p>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section class={`workspace-shell workspace-shell--${mode}`}>
      <header class="workspace-frame">
        <div class="workspace-frame__masthead">
          <BrandLockup />
          <div class="workspace-frame__context">
            <span>{isAuthenticated ? `operator:${username}` : 'guest:public'}</span>
            <span>{mode === 'result' ? 'feed-ready' : 'interactive'}</span>
          </div>
        </div>
        <div class="workspace-frame__titleblock">
          <p class="eyebrow">html to rss conversion tool</p>
          <h1>
            {mode === 'result'
              ? 'Feed generated'
              : isAuthenticated
                ? 'Convert and inspect source pages'
                : 'Convert public HTML into a feed endpoint'}
          </h1>
          <p class="lede">
            Compact operator UI. Minimal inputs, explicit states, one canonical action per outcome.
          </p>
        </div>
      </header>

      {authError && mode !== 'result' && (
        <section class="notice notice--error" role="alert">
          <div class="notice__title">Authentication error</div>
          <p>{authError}</p>
          <button type="button" onClick={() => window.location.reload()} class="btn btn--secondary">
            Reload session
          </button>
        </section>
      )}

      {mode === 'result' && result && (
        <ResultDisplay
          result={result}
          onClose={clearResult}
          isAuthenticated={isAuthenticated}
          onLogout={isAuthenticated ? handleLogout : undefined}
          username={username ?? undefined}
          onRequestSignIn={!isAuthenticated ? handleSignInFromResult : undefined}
        />
      )}

      {(mode === 'guest-demo' || mode === 'guest-auth') && !authError && (
        <GuestOnboardingPanel
          mode={mode}
          demoError={demoError}
          authFormData={authFormData}
          authFieldErrors={authFieldErrors}
          onModeChange={(nextMode) => setShowAuthForm(nextMode === 'guest-auth')}
          onConvert={handleDemoConversion}
          onAuthSubmit={handleAuthSubmit}
          onAuthFieldChange={setAuthField}
          onBackToDemo={() => setShowAuthForm(false)}
        />
      )}

      {mode === 'member' && (
        <MemberConvertPanel
          username={username ?? ''}
          onLogout={handleLogout}
          feedFormData={feedFormData}
          feedFieldErrors={feedFieldErrors}
          conversionError={error}
          isConverting={isConverting}
          strategies={strategies}
          strategiesLoading={strategiesLoading}
          strategiesError={strategiesError}
          onFeedSubmit={handleFeedSubmit}
          onFeedFieldChange={setFeedField}
          strategyHint={strategyHint}
        />
      )}
    </section>
  );
}
