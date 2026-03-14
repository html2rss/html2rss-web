import { useEffect, useState } from 'preact/hooks';
import { Bookmarklet } from './Bookmarklet';
import type { DemoSourceRecord } from '../api/contracts';

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
  demoSources: DemoSourceRecord[];
  demoLoading: boolean;
  demoStatusMessage: string | null;
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
  demoSources,
  demoLoading,
  demoStatusMessage,
  authFormData,
  authFieldErrors,
  onModeChange,
  onConvert,
  onAuthSubmit,
  onAuthFieldChange,
  onBackToDemo,
}: GuestOnboardingPanelProps) {
  const [selectedDemoId, setSelectedDemoId] = useState('');

  useEffect(() => {
    if (!demoSources[0]) return;
    if (demoSources.some((source) => source.id === selectedDemoId)) return;

    setSelectedDemoId(demoSources[0].id);
  }, [demoSources, selectedDemoId]);

  const selectedDemo = demoSources.find((source) => source.id === selectedDemoId) ?? demoSources[0] ?? null;

  return (
    <section class={`state-layout ${mode === 'guest-auth' ? 'state-layout--auth' : 'state-layout--guest'}`}>
      <aside class="surface surface--sidebar">
        <div class="surface__header">
          <p class="eyebrow">public demo</p>
          <h2>Fixed sources only</h2>
        </div>
        <div class="stack">
          <p class="muted-copy">Run a known source. Sign in to submit your own URL.</p>
          <div class="surface__section">
            <p class="muted-copy">The demo source list and token come from the server.</p>
          </div>
        </div>
      </aside>

      {mode === 'guest-demo' ? (
        <section class="surface surface--main">
          <div class="surface__header surface__header--row">
            <div>
              <p class="eyebrow">guest mode</p>
              <h2>Run a demo source</h2>
            </div>
            <button type="button" class="btn btn--secondary" onClick={() => onModeChange('guest-auth')}>
              Sign in
            </button>
          </div>

          <ul class="demo-grid" aria-label="demo sources">
            {demoSources.map((source) => (
              <li key={source.id}>
                <button
                  type="button"
                  class={`demo-card${source.id === selectedDemoId ? ' demo-card--selected' : ''}`}
                  aria-pressed={source.id === selectedDemoId}
                  onClick={() => setSelectedDemoId(source.id)}
                >
                  <strong>{formatDemoLabel(source.url)}</strong>
                  <code>{source.url}</code>
                </button>
              </li>
            ))}
          </ul>

          <div class="surface__section surface__section--footer">
            <p class="muted-copy">
              {selectedDemo ? formatDemoLabel(selectedDemo.url) : 'No demo source available.'}
            </p>
            <button
              type="button"
              class="btn btn--primary"
              disabled={demoLoading || !selectedDemo || Boolean(demoStatusMessage)}
              onClick={() => selectedDemo && onConvert(selectedDemo.url)}
            >
              Run demo
            </button>
          </div>

          {demoStatusMessage && (
            <div class="notice notice--error" role="alert">
              <p>{demoStatusMessage}</p>
            </div>
          )}

          {demoError && (
            <div class="notice notice--error" role="alert">
              <p>{demoError}</p>
            </div>
          )}
        </section>
      ) : (
        <form class="surface surface--main form-shell" onSubmit={onAuthSubmit}>
          <div class="surface__header surface__header--row">
            <div>
              <p class="eyebrow">operator mode</p>
              <h2>Sign in</h2>
            </div>
            <button type="button" class="btn btn--ghost" onClick={onBackToDemo}>
              Back to demo
            </button>
          </div>

          {authFieldErrors.form && (
            <div class="notice notice--error" role="alert">
              <p>{authFieldErrors.form}</p>
            </div>
          )}

          <div class="field-grid">
            <label class="field-block" htmlFor="username">
              <span class="field-label">Username</span>
              <input
                type="text"
                id="username"
                name="username"
                class="input"
                autocomplete="username"
                value={authFormData.username}
                onInput={(event) => onAuthFieldChange('username', (event.target as HTMLInputElement).value)}
              />
              <span class="field-error">{authFieldErrors.username}</span>
            </label>

            <label class="field-block" htmlFor="token">
              <span class="field-label">Token</span>
              <input
                type="password"
                id="token"
                name="token"
                class="input"
                autocomplete="current-password"
                value={authFormData.token}
                onInput={(event) => onAuthFieldChange('token', (event.target as HTMLInputElement).value)}
              />
              <span class="field-error">{authFieldErrors.token}</span>
            </label>
          </div>

          <div class="surface__section surface__section--footer">
            <p class="muted-copy">
              Need a token? See the{' '}
              <a href="https://html2rss.github.io/" target="_blank" rel="noopener noreferrer">
                docs
              </a>
              .
            </p>
            <button type="submit" class="btn btn--primary">
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
    <section class="state-layout state-layout--member">
      <form class="surface surface--main form-shell" onSubmit={onFeedSubmit}>
        <div class="surface__header surface__header--row">
          <div>
            <p class="eyebrow">operator workspace</p>
            <h2>Convert a page</h2>
          </div>
          <div class="surface__toolbar">
            <span class="surface__operator">
              operator:<span class="surface__operator-name">{username}</span>
            </span>
            <button type="button" onClick={onLogout} class="btn btn--secondary">
              Log out
            </button>
          </div>
        </div>

        <div class="field-stack">
          <label class="field-block" htmlFor="url">
            <span class="field-label">URL</span>
            <input
              type="url"
              id="url"
              name="url"
              class="input input--mono"
              placeholder="https://example.com/article"
              autofocus
              autocomplete="url"
              value={feedFormData.url}
              onInput={(event) => onFeedFieldChange('url', (event.target as HTMLInputElement).value)}
            />
            <span class="field-error">{feedFieldErrors.url}</span>
          </label>

          <div class="split-fields">
            <label class="field-block" htmlFor="strategy">
              <span class="field-label">Extraction strategy</span>
              <select
                id="strategy"
                name="strategy"
                class="input"
                value={feedFormData.strategy}
                disabled={strategiesLoading}
                onChange={(event) => onFeedFieldChange('strategy', (event.target as HTMLSelectElement).value)}
              >
                {strategiesLoading ? (
                  <option value="">Loading…</option>
                ) : (
                  strategies.map((strategy) => (
                    <option key={strategy.id} value={strategy.id}>
                      {strategy.display_name}
                    </option>
                  ))
                )}
              </select>
              <span class="field-help">
                {strategiesError
                  ? strategiesError
                  : selectedStrategy
                    ? strategyHint(selectedStrategy)
                    : 'No strategy selected.'}
              </span>
            </label>

            <div class="action-block">
              <span class="field-label">Action</span>
              <button type="submit" class="btn btn--primary btn--block" disabled={isConverting}>
                {isConverting ? 'Converting…' : 'Convert'}
              </button>
            </div>
          </div>
        </div>

        {conversionError && (
          <div class="notice notice--error" role="alert">
            <div class="notice__title">Conversion error</div>
            <p>{conversionError}</p>
          </div>
        )}

        {feedFieldErrors.form && (
          <div class="notice notice--error" role="alert">
            <p>{feedFieldErrors.form}</p>
          </div>
        )}
      </form>

      <aside class="surface surface--sidebar">
        <div class="surface__header">
          <p class="eyebrow">tools</p>
          <h2>Fast path</h2>
        </div>
        <div class="stack">
          <p class="muted-copy">Paste a URL. Pick a strategy. Copy the feed URL.</p>
          <Bookmarklet />
        </div>
      </aside>
    </section>
  );
}

const formatDemoLabel = (url: string): string => {
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.replace(/^www\./, '');
    const path = parsed.pathname.split('/').filter(Boolean).join(' / ');
    return path ? `${host} / ${path}` : host;
  } catch {
    return url;
  }
};
