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
  const tokenInputRef = useRef<HTMLInputElement | null>(null);
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

  useLayoutEffect(() => {
    if (!showTokenPrompt || !tokenInputRef.current || typeof window === 'undefined') return;

    const focusHandle = window.requestAnimationFrame(() => {
      tokenInputRef.current?.focus();
    });

    return () => window.cancelAnimationFrame(focusHandle);
  }, [showTokenPrompt]);

  return (
    <form class="form-shell form-shell--minimal" onSubmit={onFeedSubmit}>
      <div class={`field-stack field-stack--dense${showTokenPrompt ? ' field-stack--inactive' : ''}`}>
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
          disabled={isConverting || !feedCreationEnabled || showTokenPrompt}
          error={feedFieldErrors.url}
          onInput={(event) => onFeedFieldChange('url', (event.target as HTMLInputElement).value)}
        />

        <label class="field-block field-block--select field-block--subtle" htmlFor="strategy">
          <select
            id="strategy"
            name="strategy"
            class="input input--select input--subtle"
            value={feedFormData.strategy}
            disabled={strategiesLoading || showTokenPrompt}
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
            <p class="token-gate__hint">This instance needs an access token.</p>
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
              ref={tokenInputRef}
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
          <a
            href="https://html2rss.github.io/web-application/getting-started/"
            target="_blank"
            rel="noopener noreferrer"
            class="token-gate__nudge token-gate__nudge-link"
          >
            Set up your own instance with Docker.
          </a>
          <div class="token-gate__actions">
            <button type="button" class="btn btn--ghost" onClick={onSaveToken}>
              Save and continue
            </button>
          </div>
          <div class="token-gate__back">
            <button type="button" class="btn btn--quiet btn--linkish" onClick={onCancelTokenPrompt}>
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
  hidden?: boolean;
  hasAccessToken: boolean;
  onClearToken: () => void;
}

export function UtilityStrip({ hidden = false, hasAccessToken, onClearToken }: UtilityStripProps) {
  const [isOpen, setIsOpen] = useState(false);

  if (hidden) return null;

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
