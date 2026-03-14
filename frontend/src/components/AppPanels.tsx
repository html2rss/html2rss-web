import { useLayoutEffect, useRef } from 'preact/hooks';
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
  if (!feedCreationEnabled) return 'This instance is read-only right now.';
  if (accessTokenRequired && !hasAccessToken) return 'You will be asked for a token when you submit.';
  return '';
}

interface CreateFeedPanelProps {
  focusComposerKey: number;
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
  focusComposerKey,
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
  const urlInputRef = useRef<HTMLInputElement | null>(null);

  useLayoutEffect(() => {
    if (!urlInputRef.current || typeof window === 'undefined') return;

    const focusHandle = window.requestAnimationFrame(() => {
      const input = urlInputRef.current;
      if (!input) return;

      input.focus();
      input.select();
    });

    return () => window.cancelAnimationFrame(focusHandle);
  }, [focusComposerKey]);

  return (
    <section class="surface surface--primary">
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
                autoFocus
                ref={urlInputRef}
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
                  : 'Start with the standard mode first.'}
            </p>
            {accessNote && <p class="field-help">{accessNote}</p>}
          </div>
        </div>

        {showTokenPrompt && (
          <div class="token-gate" role="group" aria-label="Access token">
            <div class="token-gate__copy">
              <span class="field-label">Access token</span>
              <h3>Add access token</h3>
              <p class="muted-copy">This instance needs a token to generate this feed.</p>
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
                  onKeyDown={(event) => {
                    if (event.key !== 'Enter') return;

                    event.preventDefault();
                    void onSaveToken();
                  }}
                  onInput={(event) => onTokenDraftChange((event.target as HTMLInputElement).value)}
                />
                <span class="field-error">{tokenError}</span>
              </label>
              <div class="token-gate__actions">
                <button type="button" class="btn btn--primary" onClick={onSaveToken}>
                  Save and continue
                </button>
                <button type="button" class="btn btn--ghost" onClick={onCancelTokenPrompt}>
                  Back
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
    <section class={`surface surface--info${hasAccessToken ? ' surface--info-compact' : ''}`}>
      <div class="surface__header">
        <h2>{hasAccessToken ? 'Utilities' : 'Run your own instance'}</h2>
        {!hasAccessToken && <p class="muted-copy">Use Docker when you want your own copy.</p>}
      </div>

      {!hasAccessToken && (
        <div class="instance-info">
          <p>Start with the getting-started guide, then keep the bookmarklet and token controls here.</p>
        </div>
      )}

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
          <>
            <span class="support-status">Saved token in this browser</span>
            <button type="button" class="btn btn--ghost" onClick={onClearToken}>
              Clear saved token
            </button>
          </>
        )}
      </div>
    </section>
  );
}
