import { Bookmarklet } from './Bookmarklet';

export interface Strategy {
  id: string;
  name: string;
  display_name: string;
}

export interface FeedFormData {
  url: string;
  strategy: string;
}

export interface FeedFieldErrors {
  url: string;
  form: string;
}

function feedAccessNote(feedCreationEnabled: boolean, accessTokenRequired: boolean, hasAccessToken: boolean) {
  if (!feedCreationEnabled) return 'Feed creation is unavailable on this deployment.';
  if (accessTokenRequired && !hasAccessToken) return 'Custom URLs ask for an access token on submit.';
  return '';
}

interface CreateFeedPanelProps {
  feedFormData: FeedFormData;
  feedFieldErrors: FeedFieldErrors;
  conversionError: string | null;
  isConverting: boolean;
  strategies: Strategy[];
  strategiesLoading: boolean;
  strategiesError: string | null;
  feedCreationEnabled: boolean;
  accessTokenRequired: boolean;
  hasAccessToken: boolean;
  tokenDraft: string;
  tokenError: string;
  showTokenPrompt: boolean;
  onFeedSubmit: (event: Event) => void;
  onFeedFieldChange: (key: 'url' | 'strategy', value: string) => void;
  onTokenDraftChange: (value: string) => void;
  onSaveToken: () => void;
  onCancelTokenPrompt: () => void;
  strategyHint: (strategy: Strategy) => string;
}

export function CreateFeedPanel({
  feedFormData,
  feedFieldErrors,
  conversionError,
  isConverting,
  strategies,
  strategiesLoading,
  strategiesError,
  feedCreationEnabled,
  accessTokenRequired,
  hasAccessToken,
  tokenDraft,
  tokenError,
  showTokenPrompt,
  onFeedSubmit,
  onFeedFieldChange,
  onTokenDraftChange,
  onSaveToken,
  onCancelTokenPrompt,
  strategyHint,
}: CreateFeedPanelProps) {
  const selectedStrategy = strategies.find((strategy) => strategy.id === feedFormData.strategy);
  const accessNote = feedAccessNote(feedCreationEnabled, accessTokenRequired, hasAccessToken);

  return (
    <section class="surface surface--primary">
      <div class="surface__header">
        <h2>Create a feed</h2>
      </div>

      <form class="form-shell" onSubmit={onFeedSubmit}>
        <div class="field-stack field-stack--dense">
          <div class="composer-block">
            <label class="field-block field-block--primary" htmlFor="url">
              <span class="field-label">Source URL</span>
              <input
                type="url"
                id="url"
                name="url"
                class="input input--mono input--hero"
                placeholder="https://example.com/article"
                autocomplete="url"
                value={feedFormData.url}
                onInput={(event) => onFeedFieldChange('url', (event.target as HTMLInputElement).value)}
              />
              <span class="field-error">{feedFieldErrors.url}</span>
            </label>

            <div class="action-block action-block--compact">
              <button
                type="submit"
                class="btn btn--primary btn--block"
                disabled={isConverting || !feedCreationEnabled}
              >
                {isConverting ? 'Generating…' : 'Generate feed URL'}
              </button>
            </div>
          </div>

          <div class="form-toolbar">
            <label class="field-block field-block--compact" htmlFor="strategy">
              <span class="field-label">Rendering</span>
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
            </label>
          </div>

          <div class="support-copy">
            <p class="field-help">
              {strategiesError
                ? strategiesError
                : selectedStrategy
                  ? strategyHint(selectedStrategy)
                  : 'Choose the standard strategy unless the page depends on client-side rendering.'}
            </p>
            {accessNote && <p class="field-help">{accessNote}</p>}
          </div>
        </div>

        {showTokenPrompt && (
          <div class="token-gate" role="group" aria-label="Access token">
            <div class="token-gate__copy">
              <span class="field-label">Access token</span>
              <p class="muted-copy">Save one token in this browser session to continue.</p>
            </div>
            <div class="token-gate__controls">
              <label class="field-block" htmlFor="access-token">
                <input
                  id="access-token"
                  name="access-token"
                  type="password"
                  class="input input--mono"
                  aria-label="Access token"
                  placeholder="Paste access token"
                  autocomplete="off"
                  value={tokenDraft}
                  onInput={(event) => onTokenDraftChange((event.target as HTMLInputElement).value)}
                />
                <span class="field-error">{tokenError}</span>
              </label>
              <div class="token-gate__actions">
                <button type="button" class="btn btn--primary" onClick={onSaveToken}>
                  Continue
                </button>
                <button type="button" class="btn btn--ghost" onClick={onCancelTokenPrompt}>
                  Cancel
                </button>
              </div>
            </div>
          </div>
        )}

        {conversionError && (
          <div class="notice notice--error" role="alert">
            <div class="notice__title">Feed generation failed</div>
            <p>{conversionError}</p>
          </div>
        )}

        {feedFieldErrors.form && (
          <div class="notice notice--error" role="alert">
            <p>{feedFieldErrors.form}</p>
          </div>
        )}
      </form>
    </section>
  );
}

interface InstanceInfoProps {
  hasAccessToken: boolean;
  onClearToken: () => void;
}

export function InstanceInfo({ hasAccessToken, onClearToken }: InstanceInfoProps) {
  return (
    <section class="surface surface--info">
      <div class="surface__header">
        <h2>Run your own instance</h2>
      </div>

      <div class="instance-info">
        <p>
          Start locally with Docker, then wire in included feeds, automatic generation, or custom configs.
        </p>
      </div>

      <div class="instance-utility">
        <Bookmarklet />
      </div>

      <div class="surface__toolbar">
        <a
          href="https://html2rss.github.io/"
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn--secondary"
        >
          Getting started
        </a>
        {hasAccessToken && (
          <button type="button" class="btn btn--ghost" onClick={onClearToken}>
            Clear token
          </button>
        )}
      </div>
    </section>
  );
}
