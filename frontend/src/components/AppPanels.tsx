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

interface CreateFeedPanelProperties {
  focusComposerKey: number;
  feedFormData: FeedFormData;
  feedFieldErrors: FeedFieldErrors;
  conversionError?: string;
  isConverting: boolean;
  submitDisabled: boolean;
  strategies: Strategy[];
  strategiesLoading: boolean;
  strategiesError?: string;
  feedCreationEnabled: boolean;
  featuredFeeds: Array<{ path: string; title: string; description: string }>;
  tokenDraft: string;
  tokenError: string;
  showTokenPrompt: boolean;
  manualRetryStrategy: string;
  onFeedSubmit: (event: Event) => void;
  onFeedFieldChange: (key: 'url' | 'strategy', value: string) => void;
  onTokenDraftChange: (value: string) => void;
  onSaveToken: () => void;
  onCancelTokenPrompt: () => void;
  onRetryWithStrategy: () => void;
  strategyHint: (strategy: Strategy) => string;
}

function strategyOptionLabel(strategy: Strategy) {
  if (strategy.id === 'faraday') return 'Default';
  if (strategy.id === 'browserless') return 'JavaScript pages (recommended)';
  return strategy.display_name;
}

export function CreateFeedPanel({
  focusComposerKey,
  feedFormData,
  feedFieldErrors,
  conversionError,
  isConverting,
  submitDisabled,
  strategies,
  strategiesLoading,
  strategiesError,
  feedCreationEnabled,
  featuredFeeds,
  tokenDraft,
  tokenError,
  showTokenPrompt,
  manualRetryStrategy,
  onFeedSubmit,
  onFeedFieldChange,
  onTokenDraftChange,
  onSaveToken,
  onCancelTokenPrompt,
  onRetryWithStrategy,
  strategyHint,
}: CreateFeedPanelProperties) {
  const selectedStrategy = strategies.find((strategy) => strategy.id === feedFormData.strategy);
  const urlInputReference = useRef<HTMLInputElement>(undefined as never);
  const tokenInputReference = useRef<HTMLInputElement>(undefined as never);

  useLayoutEffect(() => {
    if (!urlInputReference.current || globalThis.window === undefined) return;

    const focusHandle = globalThis.requestAnimationFrame(() => {
      const input = urlInputReference.current;
      if (!input) return;

      input.focus();
      input.select();
    });

    return () => globalThis.cancelAnimationFrame(focusHandle);
  }, [focusComposerKey]);

  useLayoutEffect(() => {
    if (!showTokenPrompt || !tokenInputReference.current || globalThis.window === undefined) return;

    const focusHandle = globalThis.requestAnimationFrame(() => {
      tokenInputReference.current?.focus();
    });

    return () => globalThis.cancelAnimationFrame(focusHandle);
  }, [showTokenPrompt]);

  return (
    <form class="form-shell form-shell--minimal" onSubmit={onFeedSubmit}>
      <div class={`field-stack field-stack--dense${showTokenPrompt ? ' field-stack--inactive' : ''}`}>
        <DominantField
          id="url"
          label="Page URL"
          type="text"
          value={feedFormData.url}
          placeholder="example.com/articles"
          inputMode="url"
          autoCapitalize="off"
          spellcheck={false}
          autoFocus
          inputRef={urlInputReference}
          actionLabel={isConverting ? 'Creating feed link' : 'Generate feed URL'}
          actionText={isConverting ? '...' : '>'}
          disabled={submitDisabled}
          error={feedFieldErrors.url}
          onInput={(event) => onFeedFieldChange('url', (event.target as HTMLInputElement).value)}
        />

        <label class="field-block field-block--centered field-block--compact" htmlFor="strategy">
          <select
            id="strategy"
            name="strategy"
            class="input input--minimal"
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
          <>
            <p class="field-help field-help--alert">Feed creation is disabled on this instance.</p>
            {featuredFeeds.length > 0 && (
              <div
                class="ui-card ui-card--notice ui-card--padded notice"
                role="status"
                aria-label="Included feeds"
              >
                <p class="ui-eyebrow">Included feeds</p>
                <div class="notice__title">Try a working included feed</div>
                <p class="notice__intro">Start with a ready-made feed from this instance.</p>
                <div class="featured-feed-list" role="list" aria-label="Featured feeds">
                  {featuredFeeds.map((feed) => (
                    <div key={feed.path} class="featured-feed-item" role="listitem">
                      <a href={feed.path} class="featured-feed-item__link" aria-label={feed.title}>
                        <span class="featured-feed-item__title">{feed.title}</span>
                        <span class="featured-feed-item__description">{feed.description}</span>
                      </a>
                    </div>
                  ))}
                </div>
                <p class="notice__meta">
                  <a
                    href="https://html2rss.github.io/web-application/how-to/use-included-configs/"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Learn how included configs work.
                  </a>
                </p>
              </div>
            )}
          </>
        )}
      </div>

      {showTokenPrompt && (
        <div class="token-gate" role="group" aria-label="Access token">
          <div class="token-gate__copy">
            <h2>Enter access token</h2>
            <p class="token-gate__hint">Required by this instance.</p>
          </div>
          <label class="field-block field-block--stretch field-block--compact" htmlFor="access-token">
            <span class="field-label field-label--ghost">Access token</span>
            <input
              id="access-token"
              name="access-token"
              type="password"
              class="input input--mono input--minimal"
              aria-label="Access token"
              placeholder="Paste access token"
              autoComplete="off"
              autoCapitalize="off"
              autoCorrect="off"
              spellcheck={false}
              data-1p-ignore="true"
              data-lpignore="true"
              ref={tokenInputReference}
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
            <button type="button" class="btn btn--primary" onClick={onSaveToken}>
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
        <div class="ui-card ui-card--notice ui-card--padded notice" data-tone="error" role="alert">
          <div class="notice__title">Could not create feed link</div>
          <p>{conversionError}</p>
        </div>
      )}

      {isConverting && (
        <div class="ui-card ui-card--notice ui-card--padded notice" data-state="loading" role="status">
          <div class="notice__title">Creating feed link</div>
          <p>Checking readiness now.</p>
        </div>
      )}

      {feedFieldErrors.form && (
        <div class="ui-card ui-card--notice ui-card--padded notice" data-tone="error" role="alert">
          <p>{feedFieldErrors.form}</p>
          {manualRetryStrategy && (
            <div class="notice__actions">
              <button type="button" class="btn btn--ghost" onClick={onRetryWithStrategy}>
                Retry with {manualRetryStrategy}
              </button>
            </div>
          )}
        </div>
      )}
    </form>
  );
}

interface UtilityStripProperties {
  hidden?: boolean;
  hasAccessToken: boolean;
  openapiUrl?: string;
  onClearToken: () => void;
}

export function UtilityStrip({
  hidden = false,
  hasAccessToken,
  openapiUrl,
  onClearToken,
}: UtilityStripProperties) {
  const [isOpen, setIsOpen] = useState(false);
  const normalizedOpenapiUrl = normalizeLocalOriginUrl(openapiUrl);
  const includedFeedsHref = (() => {
    const directoryUrl = new URL('https://html2rss.github.io/feed-directory/');
    if (globalThis.window === undefined) return directoryUrl.toString();

    const instanceUrl = new URL('/', globalThis.location.origin);
    directoryUrl.hash = `!url=${encodeURIComponent(instanceUrl.toString())}`;
    return directoryUrl.toString();
  })();

  if (hidden) return;

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
          <a href={includedFeedsHref} target="_blank" rel="noopener noreferrer" class="utility-link">
            Try included feeds
          </a>
          <Bookmarklet />
          {openapiUrl && (
            <a
              href={normalizedOpenapiUrl ?? openapiUrl}
              target="_blank"
              rel="noopener noreferrer"
              class="utility-link"
            >
              OpenAPI spec
            </a>
          )}
          <a
            href="https://github.com/html2rss/html2rss-web"
            target="_blank"
            rel="noopener noreferrer"
            class="utility-link"
          >
            Source code
          </a>
          <a
            href="https://hub.docker.com/r/html2rss/web"
            target="_blank"
            rel="noopener noreferrer"
            class="utility-link"
          >
            Install from Docker Hub
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

function normalizeLocalOriginUrl(value?: string): string | undefined {
  if (!value || globalThis.window === undefined) return value;

  try {
    const target = new URL(value, globalThis.location.origin);
    const current = new URL(globalThis.location.origin);
    const isLocalHost = (host: string) => host === 'localhost' || host === '127.0.0.1';

    if (isLocalHost(current.hostname) && isLocalHost(target.hostname) && target.port !== current.port) {
      return `${current.origin}${target.pathname}${target.search}${target.hash}`;
    }

    return target.toString();
  } catch {
    return value;
  }
}
