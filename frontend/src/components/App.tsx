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

  const [currentView, setCurrentView] = useState<'demo' | 'auth' | 'main'>('demo');
  const [showAuthForm, setShowAuthForm] = useState(false);

  // Update view state based on authentication
  useEffect(() => {
    if (isAuthenticated) {
      setCurrentView('main');
      setShowAuthForm(false);
    } else {
      setCurrentView('demo');
    }
  }, [isAuthenticated]);

  // Initialize form handlers
  useEffect(() => {
    initializeFormHandlers();
  }, [isAuthenticated, token]);

  const initializeFormHandlers = () => {
    // Auth form handler
    const authButton = document.getElementById('auth-button');
    if (authButton) {
      authButton.onclick = handleAuthSubmit;
    }

    // Feed form handler
    const feedForm = document.querySelector('#feed-section');
    if (feedForm) {
      const form = feedForm.querySelector('form') || feedForm;
      form.onsubmit = handleFeedSubmit;
    }

    // Logout button handler
    const logoutButton = document.getElementById('logout-button');
    if (logoutButton) {
      logoutButton.onclick = handleLogout;
    }
  };

  const handleAuthSubmit = async () => {
    const usernameInput = document.getElementById('username') as HTMLInputElement;
    const tokenInput = document.getElementById('token') as HTMLInputElement;

    if (!usernameInput?.value || !tokenInput?.value) return;

    try {
      await login(usernameInput.value, tokenInput.value);
    } catch (error) {
      // Error handling is done by the useAuth hook
    }
  };

  const handleFeedSubmit = async (e: Event) => {
    e.preventDefault();

    const urlInput = document.getElementById('url') as HTMLInputElement;
    const strategyInput = document.querySelector('input[name="strategy"]:checked') as HTMLInputElement;

    if (!urlInput?.value) return;

    const strategy = strategyInput?.value || 'ssrf_filter';

    try {
      await convertFeed(urlInput.value, strategy, token || '');
    } catch (error) {
      // Error handling is done by the useFeedConversion hook
    }
  };

  // Update user display in static form
  useEffect(() => {
    if (isAuthenticated) {
      const userDisplay = document.getElementById('user-display');
      if (userDisplay) userDisplay.textContent = username || '';
    }
  }, [isAuthenticated, username]);

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
              />
              <div class="form-error" id="token-error"></div>
            </div>

            <div class="form-row">
              <button type="button" class="form-button" id="auth-button">
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
                    <div class="radio-option selected">
                      <input type="radio" id="strategy-ssrf" name="strategy" value="ssrf_filter" checked />
                      <label for="strategy-ssrf">
                        <strong>SSRF Filter</strong>
                        <div class="description">Recommended - Safe and secure</div>
                      </label>
                    </div>
                    <div class="radio-option">
                      <input type="radio" id="strategy-browserless" name="strategy" value="browserless" />
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
