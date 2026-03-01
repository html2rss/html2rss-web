import { useEffect, useState } from 'preact/hooks';
import { ResultDisplay } from './ResultDisplay';
import {
  GuestOnboardingPanel,
  MemberConvertPanel,
  type Strategy,
} from './AppPanels';
import { useAuth } from '../hooks/useAuth';
import { useFeedConversion } from '../hooks/useFeedConversion';
import { useStrategies } from '../hooks/useStrategies';
import styles from './App.module.css';

type ViewMode = 'result' | 'guest-demo' | 'guest-auth' | 'member';

const EMPTY_AUTH_ERRORS = { username: '', token: '', form: '' };
const EMPTY_FEED_ERRORS = { url: '', form: '' };

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
    if (strategy.id === 'ssrf_filter') return 'Recommended - safe and secure';
    if (strategy.id === 'browserless') return 'Great for pages that rely on JavaScript';
    return `Strategy: ${strategy.name}`;
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
    } catch (error) {
      setAuthFieldErrors({
        ...EMPTY_AUTH_ERRORS,
        form: error instanceof Error ? error.message : 'Unable to authenticate. Please try again.',
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
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unable to start conversion.';
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
    } catch (error) {
      setDemoError(error instanceof Error ? error.message : 'Demo conversion failed. Please try again.');
    }
  };

  const handleSignInFromResult = () => {
    clearResult();
    setShowAuthForm(true);
  };

  if (authLoading) {
    return (
      <div class="app-shell">
        <div class={styles.loading}>
          <div class={styles.loadingSpinner} aria-label="Loading application" />
          <p>Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div
      class={`app-shell${mode !== 'result' ? ' app-shell--workspace' : ''}`}
    >
      {authError && mode !== 'result' && (
        <section class="notice notice--error" role="alert">
          <h3>Authentication error</h3>
          <p>{authError}</p>
          <button type="button" onClick={() => window.location.reload()} class="btn btn--outline">
            Retry
          </button>
        </section>
      )}

      {mode === 'result' && result && (
        <ResultDisplay
          result={result}
          onClose={clearResult}
          isAuthenticated={isAuthenticated}
          onLogout={isAuthenticated ? handleLogout : undefined}
          username={username}
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
          username={username}
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
    </div>
  );
}
