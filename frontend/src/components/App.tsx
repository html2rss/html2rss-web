import { useState, useEffect } from 'preact/hooks';
import { DemoButtons } from './DemoButtons';
import { ResultDisplay } from './ResultDisplay';
import { QuickLogin } from './QuickLogin';
import { useAuth } from '../hooks/useAuth';
import { useFeedConversion } from '../hooks/useFeedConversion';
import { useStrategies } from '../hooks/useStrategies';
import styles from './App.module.css';

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
  const [authFieldErrors, setAuthFieldErrors] = useState({ username: '', token: '', form: '' });
  const [feedFormData, setFeedFormData] = useState({ url: '', strategy: 'ssrf_filter' });
  const [feedFieldErrors, setFeedFieldErrors] = useState({ url: '', form: '' });
  const [demoError, setDemoError] = useState('');

  useEffect(() => {
    if (isAuthenticated) {
      setShowAuthForm(false);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    if (strategies.length > 0 && !feedFormData.strategy) {
      setFeedFormData((prev) => ({ ...prev, strategy: strategies[0].id }));
    }
  }, [strategies]);

  const handleAuthSubmit = async (event?: Event) => {
    event?.preventDefault();

    setAuthFieldErrors({ username: '', token: '', form: '' });

    if (!authFormData.username.trim()) {
      setAuthFieldErrors({ username: 'Username is required.', token: '', form: '' });
      return;
    }
    if (!authFormData.token.trim()) {
      setAuthFieldErrors({ username: '', token: 'Token is required.', form: '' });
      return;
    }

    try {
      await login(authFormData.username, authFormData.token);
    } catch (error) {
      setAuthFieldErrors({
        username: '',
        token: '',
        form: error instanceof Error ? error.message : 'Unable to authenticate. Please try again.',
      });
    }
  };

  const handleFeedSubmit = async (event: Event) => {
    event.preventDefault();

    setFeedFieldErrors({ url: '', form: '' });
    if (!feedFormData.url.trim()) {
      setFeedFieldErrors({ url: 'Website URL is required.', form: '' });
      return;
    }

    try {
      await convertFeed(feedFormData.url, feedFormData.strategy, token || '');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unable to start conversion.';
      if (message.toLowerCase().includes('url')) {
        setFeedFieldErrors({ url: message, form: '' });
      } else {
        setFeedFieldErrors({ url: '', form: message });
      }
    }
  };

  const handleShowAuth = () => {
    setShowAuthForm(true);
  };

  const handleLogout = () => {
    logout();
    setShowAuthForm(false);
    clearResult();
  };

  const handleDemoConversion = async (url: string) => {
    setDemoError('');
    try {
      const demoStrategy = strategies.length > 0 ? strategies[0].id : 'ssrf_filter';
      await convertFeed(url, demoStrategy, 'self-host-for-full-access');
    } catch (error) {
      setDemoError(error instanceof Error ? error.message : 'Demo conversion failed. Please try again.');
    }
  };

  const showResultExperience = Boolean(result);

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
    <div class={`app-shell${showResultExperience ? ' app-shell--wide' : ''}`}>
      {authError && !showResultExperience && (
        <section class="notice notice--error" role="alert">
          <h3>Authentication error</h3>
          <p>{authError}</p>
          <button type="button" onClick={() => window.location.reload()} class="btn btn--outline">
            Retry
          </button>
        </section>
      )}

      {showResultExperience && result && (
        <>
          {isAuthenticated && (
            <div class="user-bar">
              <span>Logged in as {username}</span>
              <button type="button" onClick={handleLogout} class="btn btn--link">
                Logout
              </button>
            </div>
          )}

          <ResultDisplay
            result={result}
            onClose={clearResult}
            isAuthenticated={isAuthenticated}
            onLogout={isAuthenticated ? handleLogout : undefined}
            username={username}
          />
        </>
      )}

      {!showResultExperience && !isAuthenticated && !showAuthForm && !authError && (
        <section class="surface">
          <header class="surface-header">
            <h3 class="surface-header__title">🚀 Try it out</h3>
            <p class="surface-header__hint">
              Launch a demo conversion to see the results instantly. No sign-in required.
            </p>
            {demoError && (
              <div class="notice notice--error" role="alert">
                <p>{demoError}</p>
              </div>
            )}
          </header>
          <DemoButtons onConvert={handleDemoConversion} />
          <QuickLogin onShowLogin={handleShowAuth} />
        </section>
      )}

      {!showResultExperience && !isAuthenticated && showAuthForm && (
        <section class="surface">
          <header class="surface-header">
            <h3 class="surface-header__title">🔐 Sign in</h3>
            <p class="surface-header__hint">
              Use your html2rss credentials to convert any website. Tokens are stored for this browser session.
            </p>
            <p class="surface-header__hint">
              Need a token? Ask your html2rss-web admin or see the{' '}
              <a href="https://html2rss.github.io/" target="_blank" rel="noopener noreferrer">
                official docs
              </a>
              .
            </p>
          </header>

          <form id="auth-section" class="form" onSubmit={handleAuthSubmit}>
            {authFieldErrors.form && (
              <div class="notice notice--error" role="alert">
                <p>{authFieldErrors.form}</p>
              </div>
            )}
            <div class="field">
              <label for="username" class="label" data-required>
                Username
              </label>
              <input
                type="text"
                id="username"
                name="username"
                class="input"
                placeholder="Enter your username"
                required
                autocomplete="username"
                value={authFormData.username}
                onInput={(e) =>
                  setAuthFormData({ ...authFormData, username: (e.target as HTMLInputElement).value })
                }
              />
              <div class="field-error" id="username-error">
                {authFieldErrors.username}
              </div>
            </div>

            <div class="field">
              <label for="token" class="label" data-required>
                Token
              </label>
              <input
                type="password"
                id="token"
                name="token"
                class="input"
                placeholder="Enter your authentication token"
                required
                autocomplete="current-password"
                value={authFormData.token}
                onInput={(e) =>
                  setAuthFormData({ ...authFormData, token: (e.target as HTMLInputElement).value })
                }
              />
              <div class="field-error" id="token-error">
                {authFieldErrors.token}
              </div>
            </div>

            <div class="form-actions">
              <button type="submit" class="btn btn--accent">
                Authenticate
              </button>
            </div>
          </form>

          <button type="button" class="btn btn--link back-link" onClick={() => setShowAuthForm(false)}>
            ← Back to demo
          </button>
        </section>
      )}

      {!showResultExperience && isAuthenticated && (
        <section class="surface">
          <div class="user-bar">
            <span>Welcome, {username}!</span>
            <button type="button" onClick={handleLogout} class="btn btn--link">
              Logout
            </button>
          </div>

          <header class="surface-header">
            <h3 class="surface-header__title">🌐 Convert website</h3>
            <p class="surface-header__hint">Enter a URL to generate an RSS feed.</p>
          </header>

          <form id="feed-section" class="form form--spacious" onSubmit={handleFeedSubmit}>
            <div class="field">
              <label for="url" class="label" data-required>
                Website URL
              </label>
              <div class="field field--inline">
                <input
                  type="url"
                  id="url"
                  name="url"
                  class="input"
                  placeholder="https://example.com"
                  required
                  autofocus
                  autocomplete="url"
                  value={feedFormData.url}
                  onInput={(e) =>
                    setFeedFormData({ ...feedFormData, url: (e.target as HTMLInputElement).value })
                  }
                />
                <button type="submit" class="btn btn--accent" disabled={isConverting}>
                  {isConverting ? 'Converting...' : 'Convert'}
                </button>
              </div>
              <div class="field-error" id="url-error">
                {feedFieldErrors.url}
              </div>
            </div>

            <fieldset class="fieldset">
              <legend class="legend">Strategy</legend>
              {strategiesError && (
                <div class="notice notice--error" role="alert">
                  <p>Failed to load strategies: {strategiesError}</p>
                </div>
              )}
              {strategiesLoading ? (
                <div class={styles.loading}>
                  <div class={styles.loadingSpinner} aria-label="Loading strategies" />
                  <p>Loading strategies...</p>
                </div>
              ) : (
                <div class="radio-list" id="strategy-group">
                  {strategies.map((strategy) => (
                    <label
                      key={strategy.id}
                      class={`radio-card ${feedFormData.strategy === strategy.id ? 'is-selected' : ''}`}
                    >
                      <input
                        type="radio"
                        id={`strategy-${strategy.id}`}
                        name="strategy"
                        value={strategy.id}
                        class="radio-card__input"
                        checked={feedFormData.strategy === strategy.id}
                        onChange={(e) =>
                          setFeedFormData({ ...feedFormData, strategy: (e.target as HTMLInputElement).value })
                        }
                      />
                      <span class="radio-card__content">
                        <span class="radio-card__title">{strategy.display_name}</span>
                        <span class="radio-card__hint">
                          {strategy.id === 'ssrf_filter'
                            ? 'Recommended - safe and secure'
                            : strategy.id === 'browserless'
                              ? 'Great for pages that rely on JavaScript'
                              : `Strategy: ${strategy.name}`}
                        </span>
                      </span>
                    </label>
                  ))}
                </div>
              )}
            </fieldset>
          </form>
          {feedFieldErrors.form && (
            <div class="notice notice--error" role="alert">
              <p>{feedFieldErrors.form}</p>
            </div>
          )}
        </section>
      )}

      {!showResultExperience && error && (
        <section class="notice notice--error">
          <h3>Conversion error</h3>
          <p>{error}</p>
          <p>Double-check your token if this keeps happening.</p>
          <button type="button" class="btn btn--outline" onClick={clearResult}>
            Close
          </button>
        </section>
      )}
    </div>
  );
}
