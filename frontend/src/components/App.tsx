import { useState, useEffect } from 'preact/hooks';
import { DemoButtons } from './DemoButtons';
import { ResultDisplay } from './ResultDisplay';
import { QuickLogin } from './QuickLogin';
import { useAuth } from '../hooks/useAuth';
import { useFeedConversion } from '../hooks/useFeedConversion';

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

  const [showAuthForm, setShowAuthForm] = useState(false);
  const [authFormData, setAuthFormData] = useState({ username: '', token: '' });
  const [feedFormData, setFeedFormData] = useState({ url: '', strategy: 'ssrf_filter' });

  // Update view state based on authentication
  useEffect(() => {
    if (isAuthenticated) {
      setShowAuthForm(false);
    }
  }, [isAuthenticated]);

  const handleAuthSubmit = async () => {
    if (!authFormData.username || !authFormData.token) return;

    try {
      await login(authFormData.username, authFormData.token);
    } catch (error) {
      // Error handling is done by the useAuth hook
    }
  };

  const handleFeedSubmit = async (e: Event) => {
    e.preventDefault();

    if (!feedFormData.url) return;

    try {
      await convertFeed(feedFormData.url, feedFormData.strategy, token || '');
    } catch (error) {
      // Error handling is done by the useFeedConversion hook
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
    try {
      await convertFeed(url, 'ssrf_filter', 'self-host-for-full-access');
    } catch (error) {
      // Error handling is done by the useFeedConversion hook
    }
  };

  if (authLoading) {
    return (
      <div class="app-container">
        <div class="loading-section">
          <div class="loading-spinner" aria-label="Loading application"></div>
          <p>Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div class="app-container">
      {/* Auth Error Display */}
      {authError && (
        <div class="error-section" role="alert">
          <h3>⚠️ Authentication Error</h3>
          <p>{authError}</p>
          <button onClick={() => window.location.reload()} class="retry-btn">
            Retry
          </button>
        </div>
      )}

      {/* Demo Section - Always visible for new users */}
      {!isAuthenticated && !showAuthForm && !authError && (
        <div class="demo-section">
          <div class="section-header">
            <h3>🚀 Try It Out</h3>
            <p class="section-description">
              Click any button below to instantly convert these websites to RSS feeds - no signup required!
            </p>
          </div>
          <DemoButtons onConvert={handleDemoConversion} />

          {/* Quick login for existing users */}
          <QuickLogin onShowLogin={handleShowAuth} />
        </div>
      )}

      {/* Auth Section - Show when user clicks "Sign in here" */}
      {!isAuthenticated && showAuthForm && (
        <div class="auth-section">
          <div class="section-header">
            <h3>🔐 Sign In</h3>
            <p class="section-description">Enter your credentials to convert any website.</p>
          </div>
          <div id="auth-section">
            <div class="form-group-compact">
              <label for="username" class="form-label required">
                Username
              </label>
              <input
                type="text"
                id="username"
                name="username"
                class="form-input"
                placeholder="Enter your username"
                required
                autocomplete="username"
                value={authFormData.username}
                onInput={(e) =>
                  setAuthFormData({ ...authFormData, username: (e.target as HTMLInputElement).value })
                }
              />
              <div class="form-error" id="username-error"></div>
            </div>

            <div class="form-group-compact">
              <label for="token" class="form-label required">
                Token
              </label>
              <input
                type="password"
                id="token"
                name="token"
                class="form-input"
                placeholder="Enter your authentication token"
                required
                autocomplete="current-password"
                value={authFormData.token}
                onInput={(e) =>
                  setAuthFormData({ ...authFormData, token: (e.target as HTMLInputElement).value })
                }
              />
              <div class="form-error" id="token-error"></div>
            </div>

            <div class="form-row">
              <button type="button" class="form-button" id="auth-button" onClick={handleAuthSubmit}>
                Authenticate
              </button>
            </div>
          </div>
          <div class="auth-footer">
            <button type="button" class="back-to-demo-btn" onClick={() => setShowAuthForm(false)}>
              ← Back to demo
            </button>
          </div>
        </div>
      )}

      {/* Main Content - Show when authenticated */}
      {isAuthenticated && (
        <div class="main-content-section">
          <div class="user-info">
            <span>Welcome, {username}!</span>
            <button onClick={handleLogout} class="logout-btn">
              Logout
            </button>
          </div>

          <div class="url-section">
            <div class="section-header">
              <h3>🌐 Convert Website</h3>
              <p class="section-description">Enter the URL of the website you want to convert to RSS</p>
            </div>
            <div id="feed-section">
              <form onSubmit={handleFeedSubmit}>
                <div class="form-group-compact">
                  <label for="url" class="form-label required">
                    Website URL
                  </label>
                  <div class="form-row">
                    <div class="form-group">
                      <input
                        type="url"
                        id="url"
                        name="url"
                        class="form-input"
                        placeholder="https://example.com"
                        required
                        autocomplete="url"
                        value={feedFormData.url}
                        onInput={(e) =>
                          setFeedFormData({ ...feedFormData, url: (e.target as HTMLInputElement).value })
                        }
                      />
                      <div class="form-error" id="url-error"></div>
                    </div>
                    <button type="submit" class="form-button" disabled={isConverting}>
                      {isConverting ? 'Converting...' : 'Convert'}
                    </button>
                  </div>
                </div>

                <div class="form-group-compact">
                  <label class="form-label">Strategy</label>
                  <div class="radio-group" id="strategy-group">
                    <div class={`radio-option ${feedFormData.strategy === 'ssrf_filter' ? 'selected' : ''}`}>
                      <input
                        type="radio"
                        id="strategy-ssrf"
                        name="strategy"
                        value="ssrf_filter"
                        checked={feedFormData.strategy === 'ssrf_filter'}
                        onChange={(e) =>
                          setFeedFormData({ ...feedFormData, strategy: (e.target as HTMLInputElement).value })
                        }
                      />
                      <label for="strategy-ssrf">
                        <strong>SSRF Filter</strong>
                        <div class="description">Recommended - Safe and secure</div>
                      </label>
                    </div>
                    <div class={`radio-option ${feedFormData.strategy === 'browserless' ? 'selected' : ''}`}>
                      <input
                        type="radio"
                        id="strategy-browserless"
                        name="strategy"
                        value="browserless"
                        checked={feedFormData.strategy === 'browserless'}
                        onChange={(e) =>
                          setFeedFormData({ ...feedFormData, strategy: (e.target as HTMLInputElement).value })
                        }
                      />
                      <label for="strategy-browserless">
                        <strong>Browserless</strong>
                        <div class="description">For JavaScript-heavy sites</div>
                      </label>
                    </div>
                  </div>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Results Section - Show when there's a result */}
      {result && <ResultDisplay result={result} onClose={clearResult} />}

      {/* Error Display */}
      {error && (
        <div class="error-section">
          <h3>❌ Error</h3>
          <p>{error}</p>
          <button onClick={clearResult} class="close-btn">
            Close
          </button>
        </div>
      )}
    </div>
  );
}
