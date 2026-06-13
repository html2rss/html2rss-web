import { useLayoutEffect, useRef } from 'preact/hooks';
import { Bookmarklet } from './Bookmarklet';
import { DominantField } from './DominantField';
import { Notice } from './Notice';
import type { FeedCreationError } from '../api/contracts';

export interface FeedFormData {
  url: string;
}

export interface FeedFieldErrors {
  url: string;
  form: string;
}

export type WorkflowState = 'create' | 'submitting' | 'token_prompt' | 'result' | 'error';

export type WorkflowErrorKind = FeedCreationError['kind'];

interface CreateFeedPanelProperties {
  focusComposerKey: number;
  workflowState: WorkflowState;
  feedFormData: FeedFormData;
  feedFieldErrors: FeedFieldErrors;
  conversionError?: FeedCreationError;
  errorKind?: WorkflowErrorKind;
  isConverting: boolean;
  submitDisabled: boolean;
  feedCreationEnabled: boolean;
  featuredFeeds: Array<{ path: string; title: string; description: string }>;
  tokenDraft: string;
  tokenError: string;
  showTokenPrompt: boolean;
  onFeedSubmit: (event: Event) => void;
  onFeedFieldChange: (key: 'url', value: string) => void;
  onTokenDraftChange: (value: string) => void;
  onSaveToken: () => void;
  onCancelTokenPrompt: () => void;
  onRetryCreate: () => void;
}

export function CreateFeedPanel({
  focusComposerKey,
  workflowState,
  feedFormData,
  feedFieldErrors,
  conversionError,
  errorKind,
  isConverting,
  submitDisabled,
  feedCreationEnabled,
  featuredFeeds,
  tokenDraft,
  tokenError,
  showTokenPrompt,
  onFeedSubmit,
  onFeedFieldChange,
  onTokenDraftChange,
  onSaveToken,
  onCancelTokenPrompt,
  onRetryCreate,
}: CreateFeedPanelProperties) {
  const urlInputReference = useRef<HTMLInputElement>(undefined as never);
  const tokenInputReference = useRef<HTMLInputElement>(undefined as never);
  const failureMessage = conversionError?.message || feedFieldErrors.form;
  const showRetryButton = Boolean(
    conversionError && conversionError.nextAction === 'retry' && conversionError.retryAction !== 'none'
  );

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
    <form
      class="form-shell form-shell--minimal"
      onSubmit={onFeedSubmit}
      data-state={workflowState}
      data-error-kind={errorKind}
    >
      <div class={`field-stack field-stack--dense${showTokenPrompt ? ' field-stack--inactive' : ''}`}>
        <DominantField
          className="layout-rail-reading"
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

        {!feedCreationEnabled && (
          <>
            <p class="field-help field-help--alert">Feed creation is disabled on this instance.</p>
            {featuredFeeds.length > 0 && (
              <Notice
                className="layout-rail-reading"
                role="status"
                ariaLabel="Included feeds"
                title="Try a working included feed"
              >
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
              </Notice>
            )}
          </>
        )}
      </div>

      {showTokenPrompt && (
        <div class="token-gate layout-rail-reading" role="group" aria-label="Access token">
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

      {failureMessage && (
        <Notice
          className="layout-rail-reading"
          tone="error"
          title="Couldn't create feed yet"
          actions={
            showRetryButton && (
              <button type="button" class="btn btn--primary" onClick={onRetryCreate}>
                Try again
              </button>
            )
          }
        >
          <p>{failureMessage}</p>
        </Notice>
      )}

      {isConverting && (
        <Notice className="layout-rail-reading" state="loading" title="Creating feed link">
          <p>Preparing preview.</p>
        </Notice>
      )}
    </form>
  );
}

interface UtilityStripProperties {
  hasAccessToken: boolean;
  openapiUrl?: string;
  onClearToken: () => void;
  onShowBookmarkletHelp: () => void;
}

export function UtilityStrip({
  hasAccessToken,
  openapiUrl,
  onClearToken,
  onShowBookmarkletHelp,
}: UtilityStripProperties) {
  const normalizedOpenapiUrl = normalizeLocalOriginUrl(openapiUrl);
  const includedFeedsHref = (() => {
    const directoryUrl = new URL('https://html2rss.github.io/feed-directory/');
    if (globalThis.window === undefined) return directoryUrl.toString();

    const instanceUrl = new URL('/', globalThis.location.origin);
    directoryUrl.hash = `!url=${encodeURIComponent(instanceUrl.toString())}`;
    return directoryUrl.toString();
  })();

  return (
    <section class="utility-strip" aria-label="Utilities">
      <div class="utility-strip__items">
        <a href={includedFeedsHref} target="_blank" rel="noopener noreferrer" class="utility-link">
          Try included feeds
        </a>
        <Bookmarklet onClick={onShowBookmarkletHelp} />
        {hasAccessToken && (
          <button type="button" class="utility-button" onClick={onClearToken}>
            Logout
          </button>
        )}
        <a
          href="https://hub.docker.com/r/html2rss/web"
          target="_blank"
          rel="noopener noreferrer"
          class="utility-link"
        >
          Install from Docker Hub
        </a>
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
      </div>
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
