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

const DEMO_SOURCES = [
  {
    id: 'github',
    label: 'GitHub Trending',
    hint: 'Repository leaderboard',
    url: 'https://github.com/trending',
  },
  {
    id: 'hackernews',
    label: 'Hacker News',
    hint: 'Front page discussion feed',
    url: 'https://news.ycombinator.com',
  },
  {
    id: 'hardware',
    label: 'CHIP.de',
    hint: 'Article-heavy consumer tech site',
    url: 'https://www.chip.de',
  },
] as const;

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
  const [selectedDemoId, setSelectedDemoId] = useState<(typeof DEMO_SOURCES)[number]['id']>(
    DEMO_SOURCES[0].id
  );
  const selectedDemo = DEMO_SOURCES.find((source) => source.id === selectedDemoId) ?? DEMO_SOURCES[0];

  return (
    <section class={`state-layout ${mode === 'guest-auth' ? 'state-layout--auth' : 'state-layout--guest'}`}>
      <aside class="surface surface--sidebar">
        <div class="surface__header">
          <p class="eyebrow">public entrypoint</p>
          <h2>Choose a controlled path</h2>
        </div>
        <div class="stack stack--lg">
          <p class="muted-copy">
            The guest path is for quick verification. Operator mode unlocks arbitrary URLs and strategy
            selection.
          </p>
          <div class="metric-strip" aria-label="guest capabilities">
            <div class="metric-tile">
              <strong>3</strong>
              <span>demo sites</span>
            </div>
            <div class="metric-tile">
              <strong>1</strong>
              <span>feed output</span>
            </div>
            <div class="metric-tile">
              <strong>0</strong>
              <span>branding noise</span>
            </div>
          </div>
          <div class="surface__section">
            <div class="subtle-list">
              <span>demo mode: fixed inputs</span>
              <span>auth mode: token-gated operator access</span>
              <span>output: RSS endpoint with preview</span>
            </div>
          </div>
        </div>
      </aside>

      {mode === 'guest-demo' ? (
        <section class="surface surface--main">
          <div class="surface__header surface__header--row">
            <div>
              <p class="eyebrow">guest mode</p>
              <h2>Convert website to RSS</h2>
            </div>
            <button type="button" class="btn btn--secondary" onClick={() => onModeChange('guest-auth')}>
              Sign in
            </button>
          </div>

          <p class="muted-copy">Try a demo source instantly. Sign in to convert your own URLs.</p>

          <div class="demo-grid" role="list" aria-label="demo sources">
            {DEMO_SOURCES.map((source) => (
              <button
                key={source.id}
                type="button"
                class={`demo-card${source.id === selectedDemoId ? ' demo-card--selected' : ''}`}
                aria-pressed={source.id === selectedDemoId}
                onClick={() => setSelectedDemoId(source.id)}
              >
                <span class="demo-card__eyebrow">{source.id}</span>
                <strong>{source.label}</strong>
                <span>{source.hint}</span>
                <code>{source.url}</code>
              </button>
            ))}
          </div>

          <div class="surface__section surface__section--footer">
            <p class="muted-copy">
              Selected demo: <span class="surface__operator">{selectedDemo.label}</span>
            </p>
            <button type="button" class="btn btn--primary" onClick={() => onConvert(selectedDemo.url)}>
              Run demo
            </button>
          </div>

          {demoError && (
            <div class="notice notice--error" role="alert">
              <div class="notice__title">Demo conversion failed</div>
              <p>{demoError}</p>
            </div>
          )}
        </section>
      ) : (
        <form class="surface surface--main form-shell" onSubmit={onAuthSubmit}>
          <div class="surface__header surface__header--row">
            <div>
              <p class="eyebrow">operator mode</p>
              <h2>Authenticate with username and token</h2>
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
              Need a token? Ask your html2rss admin or check the{' '}
              <a href="https://html2rss.github.io/" target="_blank" rel="noopener noreferrer">
                official docs
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
            <h2>Convert a website</h2>
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
          <p class="eyebrow">operator tools</p>
          <h2>Low-friction entry points</h2>
        </div>
        <div class="stack stack--lg">
          <p class="muted-copy">
            Keep a single tab open, paste the target URL, then copy the resulting endpoint into your reader.
          </p>
          <div class="surface__section">
            <div class="subtle-list">
              <span>default path: direct fetch</span>
              <span>fallback path: browser rendering</span>
              <span>result path: copy generated feed URL</span>
            </div>
          </div>
          <Bookmarklet />
        </div>
      </aside>
    </section>
  );
}
