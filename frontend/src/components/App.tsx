import { useState, useEffect } from 'preact/hooks';
import { AuthForm } from './AuthForm';
import { FeedForm } from './FeedForm';
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

  useEffect(() => {
    if (isAuthenticated) {
      setCurrentView('main');
      setShowAuthForm(false);
    } else {
      setCurrentView('demo');
    }
  }, [isAuthenticated]);

  const handleLogin = async (username: string, token: string) => {
    try {
      await login(username, token);
      setCurrentView('main');
    } catch (error) {
      throw error;
    }
  };

  const handleLogout = () => {
    logout();
    setCurrentView('demo');
    setShowAuthForm(false);
    clearResult();
  };

  const handleShowAuth = () => {
    setShowAuthForm(true);
  };

  const handleDemoConversion = async (url: string) => {
    try {
      await convertFeed(url, 'ssrf_filter', 'self-host-for-full-access');
    } catch (error) {
    }
  };

  const handleFeedConversion = async (url: string, strategy: string) => {
    if (!isAuthenticated) {
      setCurrentView('auth');
      return;
    }
    try {
      await convertFeed(url, strategy, token || '');
    } catch (error) {
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
          <AuthForm onLogin={handleLogin} />
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
            <FeedForm onConvert={handleFeedConversion} isConverting={isConverting} />
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
