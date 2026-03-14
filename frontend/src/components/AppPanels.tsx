import { useLayoutEffect, useRef, useState } from 'preact/hooks';
import { Bookmarklet } from './Bookmarklet';
import { DominantField } from './DominantField';

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
  const urlInputRef = useRef<HTMLInputElement | null>(null);
  const strategyOptionLabel = (strategy: Strategy) => {
    if (strategy.id === 'ssrf_filter') return 'Standard rendering';
    if (strategy.id === 'browserless') return 'JavaScript pages';
    return strategy.display_name;
  };

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
    <form class="form-shell form-shell--minimal" onSubmit={onFeedSubmit}>
      <div class="field-stack field-stack--dense">
        <DominantField
          id="url"
          label="Page URL"
          type="url"
          value={feedFormData.url}
          placeholder="https://example.com/article"
          autoFocus
          inputRef={urlInputRef}
          actionLabel={isConverting ? 'Generating feed URL' : 'Generate feed URL'}
          actionText={isConverting ? '...' : '>'}
          disabled={isConverting || !feedCreationEnabled}
          error={feedFieldErrors.url}
          onInput={(event) => onFeedFieldChange('url', (event.target as HTMLInputElement).value)}
        />

        <label class="field-block field-block--select field-block--subtle" htmlFor="strategy">
          <select
            id="strategy"
            name="strategy"
            class="input input--select input--subtle"
            value={feedFormData.strategy}
            disabled={strategiesLoading}
            onChange={(event) => onFeedFieldChange('strategy', (event.target as HTMLSelectElement).value)}
          >
            {strategiesLoading ? (
              <option value="">Loading…</option>
            ) : (
              strategies.map((strategy) => (
                <option key={strategy.id} value={strategy.id}>
                  {strategyOptionLabel(strategy)}
                </option>
              ))
            )}
          </select>
        </label>
        {strategiesError && <p class="field-help">{strategiesError}</p>}
        {!strategiesError && selectedStrategy?.id === 'browserless' && (
          <p class="field-help">{strategyHint(selectedStrategy)}</p>
        )}

        {!feedCreationEnabled && (
          <p class="field-help field-help--alert">Custom feed generation is disabled for this instance.</p>
        )}
      </div>

      {showTokenPrompt && (
        <div class="token-gate" role="group" aria-label="Access token">
          <div class="token-gate__copy">
            <h2>Add access token</h2>
            <p class="field-help">Paste it once and continue.</p>
          </div>
          <label class="field-block field-block--token" htmlFor="access-token">
            <span class="field-label field-label--ghost">Access token</span>
            <input
              id="access-token"
              name="access-token"
              type="password"
              class="input input--mono input--subtle"
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
  );
}

interface UtilityStripProps {
  hasAccessToken: boolean;
  onClearToken: () => void;
}

export function UtilityStrip({ hasAccessToken, onClearToken }: UtilityStripProps) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <section class="utility-strip" aria-label="Utilities">
      <button
        type="button"
        class="utility-button utility-button--toggle"
        aria-expanded={isOpen ? 'true' : 'false'}
        onClick={() => setIsOpen((current) => !current)}
      >
        More
      </button>
      {isOpen && (
        <div class="utility-strip__items">
          <Bookmarklet />
          <a
            href="https://html2rss.github.io/"
            target="_blank"
            rel="noopener noreferrer"
            class="utility-link"
          >
            Getting started
          </a>
          <a
            href="https://github.com/html2rss/html2rss-web"
            target="_blank"
            rel="noopener noreferrer"
            class="utility-link"
          >
            Source code
          </a>
          {hasAccessToken && (
            <button type="button" class="utility-button" onClick={onClearToken}>
              Clear saved token
            </button>
          )}
        </div>
      )}
    </section>
  );
}
