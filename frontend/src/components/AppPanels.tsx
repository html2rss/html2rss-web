import { useState } from 'preact/hooks';
import { Bookmarklet } from './Bookmarklet';

export interface Strategy {
  id: string;
  name: string;
  display_name: string;
}

export interface AuthFormData {
  username: string;
  token: string;
}

export interface AuthFieldErrors {
  username: string;
  token: string;
  form: string;
}

export interface FeedFormData {
  url: string;
  strategy: string;
}

export interface FeedFieldErrors {
  url: string;
  form: string;
}

interface GuestOnboardingPanelProps {
  mode: 'guest-demo' | 'guest-auth';
  demoError: string;
  authFormData: AuthFormData;
  authFieldErrors: AuthFieldErrors;
  onModeChange: (mode: 'guest-demo' | 'guest-auth') => void;
  onConvert: (url: string) => void;
  onAuthSubmit: (event: Event) => void;
  onAuthFieldChange: (key: 'username' | 'token', value: string) => void;
  onBackToDemo: () => void;
}

export function GuestOnboardingPanel({
  mode,
  demoError,
  authFormData,
  authFieldErrors,
  onModeChange,
  onConvert,
  onAuthSubmit,
  onAuthFieldChange,
  onBackToDemo,
}: GuestOnboardingPanelProps) {
  const demoSources = [
    {
      id: 'github',
      label: 'GitHub Trending',
      hint: 'Trending repositories',
      url: 'https://github.com/trending',
    },
    {
      id: 'hackernews',
      label: 'Hacker News',
      hint: 'Latest tech discussions',
      url: 'https://news.ycombinator.com',
    },
    {
      id: 'hardware',
      label: 'Hardware Reviews',
      hint: 'German tech reviews',
      url: 'https://www.chip.de',
    },
  ];
  const [selectedDemoId, setSelectedDemoId] = useState(demoSources[0].id);
  const selectedDemoUrl = demoSources.find((source) => source.id === selectedDemoId)?.url ?? demoSources[0].url;

  return (
    <section class="workspace">
      <div class="panel-meta">
        <span />
        {mode === 'guest-demo' ? (
          <button type="button" class="btn btn--link" onClick={() => onModeChange('guest-auth')}>
            Sign in
          </button>
        ) : (
          <button type="button" class="btn btn--link btn--meta" onClick={onBackToDemo}>
            ← Back to demo
          </button>
        )}
      </div>

      {mode === 'guest-demo' ? (
        <div class="form">
          <h2 class="workspace-title">Convert website to RSS</h2>
          <p class="field-help">Try a demo source instantly. Sign in to convert your own URLs.</p>

          <div class="field">
            <label for="demo-source" class="label">Demo source</label>
            <select
              id="demo-source"
              class="input"
              value={selectedDemoId}
              onChange={(e) => setSelectedDemoId((e.target as HTMLSelectElement).value)}
            >
              {demoSources.map((source) => (
                <option key={source.id} value={source.id}>
                  {source.label} — {source.hint}
                </option>
              ))}
            </select>
          </div>

          {demoError && (
            <div class="notice notice--error notice--compact" role="alert">
              <h4>Demo conversion error</h4>
              <p>{demoError}</p>
            </div>
          )}

          <div class="form-actions">
            <button type="button" class="btn btn--ghost" onClick={() => onConvert(selectedDemoUrl)}>
              Run demo
            </button>
          </div>
        </div>
      ) : (
        <form id="auth-section" class="form" onSubmit={onAuthSubmit}>
          <h2 class="workspace-title">Convert website to RSS</h2>

          {authFieldErrors.form && (
            <div class="notice notice--error notice--compact" role="alert">
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
              onInput={(e) => onAuthFieldChange('username', (e.target as HTMLInputElement).value)}
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
              onInput={(e) => onAuthFieldChange('token', (e.target as HTMLInputElement).value)}
            />
            <div class="field-error" id="token-error">
              {authFieldErrors.token}
            </div>
          </div>

          <p class="field-help">
            Need a token? Ask your html2rss-web admin or read the{' '}
            <a href="https://html2rss.github.io/" target="_blank" rel="noopener noreferrer">
              official docs
            </a>
            .
          </p>

          <div class="form-actions">
            <button type="submit" class="btn btn--accent">
              Sign in
            </button>
          </div>
        </form>
      )}
    </section>
  );
}

interface MemberConvertPanelProps {
  username: string;
  onLogout: () => void;
  feedFormData: FeedFormData;
  feedFieldErrors: FeedFieldErrors;
  conversionError: string | null;
  isConverting: boolean;
  strategies: Strategy[];
  strategiesLoading: boolean;
  strategiesError: string | null;
  onFeedSubmit: (event: Event) => void;
  onFeedFieldChange: (key: 'url' | 'strategy', value: string) => void;
  strategyHint: (strategy: Strategy) => string;
}

export function MemberConvertPanel({
  username,
  onLogout,
  feedFormData,
  feedFieldErrors,
  conversionError,
  isConverting,
  strategies,
  strategiesLoading,
  strategiesError,
  onFeedSubmit,
  onFeedFieldChange,
  strategyHint,
}: MemberConvertPanelProps) {
  const selectedStrategy = strategies.find((strategy) => strategy.id === feedFormData.strategy);

  return (
    <section class="workspace">
      <div class="panel-meta">
        <span class="panel-meta__primary">{username}</span>
        <button type="button" onClick={onLogout} class="btn btn--link btn--meta">
          Log out
        </button>
      </div>

      <form id="feed-section" class="form" onSubmit={onFeedSubmit}>
        <h2 class="workspace-title">Convert a website</h2>
        <div class="field">
          <label for="url" class="label" data-required>URL</label>
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
              onInput={(e) => onFeedFieldChange('url', (e.target as HTMLInputElement).value)}
            />
            <button type="submit" class="btn btn--accent" disabled={isConverting}>
              {isConverting ? 'Converting...' : 'Convert'}
            </button>
          </div>
          <div class="field-error field-error--compact" id="url-error">
            {feedFieldErrors.url}
          </div>
        </div>

        <div class="field">
          <label for="strategy" class="label">Strategy</label>
          {strategiesError && (
            <div class="notice notice--error" role="alert">
              <p>Failed to load strategies: {strategiesError}</p>
            </div>
          )}
          {strategiesLoading ? (
            <p>Loading strategies...</p>
          ) : (
            <>
              <select
                id="strategy"
                name="strategy"
                class="input"
                value={feedFormData.strategy}
                onChange={(e) => onFeedFieldChange('strategy', (e.target as HTMLSelectElement).value)}
              >
                {strategies.map((strategy) => (
                  <option key={strategy.id} value={strategy.id}>
                    {strategy.display_name}
                  </option>
                ))}
              </select>
              {selectedStrategy && <p class="field-help">{strategyHint(selectedStrategy)}</p>}
            </>
          )}
        </div>

        {conversionError && (
          <div class="notice notice--error notice--compact" role="alert">
            <h4>Conversion error</h4>
            <p>{conversionError}</p>
          </div>
        )}

        {feedFieldErrors.form && (
          <div class="notice notice--error notice--compact" role="alert">
            <p>{feedFieldErrors.form}</p>
          </div>
        )}
      </form>

      <Bookmarklet />
    </section>
  );
}
