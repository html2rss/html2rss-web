import { useLayoutEffect, useRef } from 'preact/hooks';
import type { RefObject } from 'preact';
import { Bookmarklet } from './Bookmarklet';
import { DominantField } from './DominantField';
import { Notice } from './Notice';
import type { AppViewModel } from '../feed';
import { COPY } from '../journey/copy';
import { presentErrorMessage } from '../journey/presentError';

export interface FeedFormData {
  url: string;
}

export interface FeedFieldErrors {
  url: string;
  form: string;
}

type CreatePanelViewModel = Exclude<AppViewModel, { kind: 'result' }>;

interface CreateFeedPanelProperties {
  focusComposerKey: number;
  viewModel: CreatePanelViewModel;
  isConverting: boolean;
  feedFormData: FeedFormData;
  feedFieldErrors: FeedFieldErrors;
  submitDisabled: boolean;
  feedCreationEnabled: boolean;
  featuredFeeds: Array<{ path: string; title: string; description: string }>;
  tokenDraft: string;
  onFeedSubmit: (event: Event) => void;
  onFeedFieldChange: (key: 'url', value: string) => void;
  onTokenDraftChange: (value: string) => void;
  onSaveToken: () => void;
  onCancelTokenPrompt: () => void;
  onRetryCreate: () => void;
}

interface UrlEntrySectionProperties {
  url: string;
  disabled: boolean;
  error: string;
  isConverting: boolean;
  feedCreationEnabled: boolean;
  featuredFeeds: Array<{ path: string; title: string; description: string }>;
  inputRef: RefObject<HTMLInputElement>;
  onInput: (value: string) => void;
}

function UrlEntrySection({
  url,
  disabled,
  error,
  isConverting,
  feedCreationEnabled,
  featuredFeeds,
  inputRef,
  onInput,
}: UrlEntrySectionProperties) {
  return (
    <>
      <DominantField
        className="layout-rail-reading"
        id="url"
        label={COPY.pageUrl}
        type="text"
        value={url}
        placeholder={COPY.pageUrlPlaceholder}
        inputMode="url"
        autoCapitalize="off"
        spellcheck={false}
        autoFocus
        inputRef={inputRef}
        actionLabel={isConverting ? COPY.creating : COPY.generateFeed}
        actionText={isConverting ? '...' : '>'}
        disabled={disabled}
        error={error}
        onInput={(event) => onInput(event.currentTarget.value)}
      />

      {!feedCreationEnabled && (
        <>
          <p class="field-help field-help--alert">{COPY.creationDisabled}</p>
          {featuredFeeds.length > 0 && (
            <Notice
              className="layout-rail-reading"
              role="status"
              ariaLabel={COPY.includedFeedsTitle}
              title={COPY.includedFeedsTitle}
            >
              <p class="notice__intro">{COPY.includedFeedsIntro}</p>
              <div class="layout-stack layout-stack--tight" role="list" aria-label={COPY.includedFeedsTitle}>
                {featuredFeeds.map((feed) => (
                  <div key={feed.path} role="listitem">
                    <a
                      href={feed.path}
                      class="ui-card ui-item--card layout-stack layout-stack--tight"
                      aria-label={feed.title}
                    >
                      <span class="ui-item__title">{feed.title}</span>
                      <span class="ui-item__excerpt">{feed.description}</span>
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
                  {COPY.includedFeedsLearnMore}
                </a>
              </p>
            </Notice>
          )}
        </>
      )}
    </>
  );
}

interface TokenGateSectionProperties {
  tokenDraft: string;
  tokenError: string;
  isConverting: boolean;
  inputRef: RefObject<HTMLInputElement>;
  onTokenDraftChange: (value: string) => void;
  onSaveToken: () => void;
  onCancelTokenPrompt: () => void;
}

function TokenGateSection({
  tokenDraft,
  tokenError,
  isConverting,
  inputRef,
  onTokenDraftChange,
  onSaveToken,
  onCancelTokenPrompt,
}: TokenGateSectionProperties) {
  return (
    <div
      class="token-gate ui-card ui-card--padded ui-card--framed"
      role="group"
      aria-labelledby="access-token-title"
    >
      <div class="token-gate__copy">
        <h2 id="access-token-title" class="ui-display-title">
          {COPY.tokenTitle}
        </h2>
        <p class="ui-eyebrow">{COPY.tokenHint}</p>
      </div>
      <label class="field-block field-block--stretch field-block--compact" htmlFor="access-token">
        <input
          id="access-token"
          name="access-token"
          type="password"
          class="input input--mono"
          aria-label={COPY.tokenTitle}
          placeholder={COPY.tokenPlaceholder}
          autoComplete="off"
          autoCapitalize="off"
          autoCorrect="off"
          spellcheck={false}
          data-1p-ignore="true"
          data-lpignore="true"
          ref={inputRef}
          value={tokenDraft}
          onKeyDown={(event) => {
            if (event.key !== 'Enter') return;

            event.preventDefault();
            void onSaveToken();
          }}
          onInput={(event) => onTokenDraftChange(event.currentTarget.value)}
        />
        {tokenError ? <span class="field-error">{tokenError}</span> : undefined}
      </label>
      <a
        href="https://html2rss.github.io/web-application/getting-started/"
        target="_blank"
        rel="noopener noreferrer"
        class="token-gate__nudge token-gate__nudge-link"
      >
        {COPY.dockerSetup}
      </a>
      <div class="token-gate__actions">
        <button type="button" class="btn btn--primary" disabled={isConverting} onClick={onSaveToken}>
          {isConverting ? COPY.creating : COPY.saveAndContinue}
        </button>
      </div>
      <div class="token-gate__back">
        <button type="button" class="btn btn--quiet btn--linkish" onClick={onCancelTokenPrompt}>
          {COPY.back}
        </button>
      </div>
    </div>
  );
}

interface ActionFeedbackProperties {
  failureMessage: string;
  isConverting: boolean;
  isShowRetryButton: boolean;
  onRetryCreate: () => void;
}

function ActionFeedback({
  failureMessage,
  isConverting,
  isShowRetryButton,
  onRetryCreate,
}: ActionFeedbackProperties) {
  return (
    <>
      {failureMessage && (
        <Notice
          className="layout-rail-reading"
          tone="error"
          title={COPY.createFailedTitle}
          actions={
            isShowRetryButton && (
              <button type="button" class="btn btn--primary" onClick={onRetryCreate}>
                {COPY.tryAgain}
              </button>
            )
          }
        >
          <p>{failureMessage}</p>
        </Notice>
      )}

      {isConverting && <Notice className="layout-rail-reading" state="loading" title={COPY.creating} />}
    </>
  );
}

export function CreateFeedPanel({
  focusComposerKey,
  viewModel,
  isConverting: flowConverting,
  feedFormData,
  feedFieldErrors,
  submitDisabled,
  feedCreationEnabled,
  featuredFeeds,
  tokenDraft,
  onFeedSubmit,
  onFeedFieldChange,
  onTokenDraftChange,
  onSaveToken,
  onCancelTokenPrompt,
  onRetryCreate,
}: CreateFeedPanelProperties) {
  const urlInputReference = useRef<HTMLInputElement>(null);
  const tokenInputReference = useRef<HTMLInputElement>(null);
  const tokenDialogReference = useRef<HTMLDialogElement>(null);

  const isTokenPrompt = viewModel.kind === 'token_prompt';
  const isSubmitting = viewModel.kind === 'submitting';
  const conversionError =
    viewModel.kind === 'error' || viewModel.kind === 'token_prompt' ? viewModel.error : undefined;
  const tokenError = viewModel.kind === 'token_prompt' ? viewModel.tokenError : '';
  const errorKind = viewModel.kind === 'error' ? viewModel.errorKind : conversionError?.kind;
  const failureMessage = isTokenPrompt
    ? ''
    : presentErrorMessage(
        conversionError?.code,
        (viewModel.kind === 'error' ? viewModel.message : undefined) ||
          conversionError?.message ||
          feedFieldErrors.form
      );
  const isShowRetryButton = Boolean(
    conversionError && conversionError.nextAction === 'retry' && conversionError.retryAction !== 'none'
  );
  const isCreateConverting = !isTokenPrompt && isSubmitting;
  const tokenConverting = isTokenPrompt && flowConverting;

  useLayoutEffect(() => {
    if (isTokenPrompt || !urlInputReference.current || globalThis.window === undefined) return;

    const focusHandle = requestAnimationFrame(() => {
      const input = urlInputReference.current;
      if (!input) return;

      input.focus();
      input.select();
    });

    return () => cancelAnimationFrame(focusHandle);
  }, [focusComposerKey, isTokenPrompt]);

  useLayoutEffect(() => {
    if (!isTokenPrompt || !tokenInputReference.current || globalThis.window === undefined) return;

    const focusHandle = requestAnimationFrame(() => {
      tokenInputReference.current?.focus();
    });

    return () => cancelAnimationFrame(focusHandle);
  }, [isTokenPrompt]);

  useLayoutEffect(() => {
    const dialog = tokenDialogReference.current;
    if (!dialog || !isTokenPrompt) return;

    try {
      if (!dialog.open) dialog.showModal();
    } catch {
      dialog.setAttribute('open', '');
    }

    if (!dialog.open) dialog.setAttribute('open', '');

    return () => {
      try {
        if (dialog.open) dialog.close();
      } catch {
        dialog.removeAttribute('open');
      }
    };
  }, [isTokenPrompt]);

  return (
    <form
      class="form-shell form-shell--minimal"
      onSubmit={onFeedSubmit}
      data-state={viewModel.kind}
      data-error-kind={errorKind}
    >
      <div class="field-stack" inert={isTokenPrompt || undefined}>
        <UrlEntrySection
          url={feedFormData.url}
          disabled={submitDisabled}
          error={feedFieldErrors.url}
          isConverting={isCreateConverting}
          feedCreationEnabled={feedCreationEnabled}
          featuredFeeds={featuredFeeds}
          inputRef={urlInputReference}
          onInput={(value) => onFeedFieldChange('url', value)}
        />
        <ActionFeedback
          failureMessage={failureMessage}
          isConverting={isCreateConverting}
          isShowRetryButton={isShowRetryButton}
          onRetryCreate={onRetryCreate}
        />
      </div>
      {isTokenPrompt ? (
        <dialog
          ref={tokenDialogReference}
          class="token-dialog"
          aria-labelledby="access-token-title"
          onCancel={(event) => {
            event.preventDefault();
            onCancelTokenPrompt();
          }}
          onClick={(event) => {
            if (event.target === event.currentTarget) onCancelTokenPrompt();
          }}
        >
          <TokenGateSection
            tokenDraft={tokenDraft}
            tokenError={tokenError}
            isConverting={tokenConverting}
            inputRef={tokenInputReference}
            onTokenDraftChange={onTokenDraftChange}
            onSaveToken={onSaveToken}
            onCancelTokenPrompt={onCancelTokenPrompt}
          />
        </dialog>
      ) : undefined}
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
    if (globalThis.window === undefined) return directoryUrl.href;

    const instanceUrl = new URL('/', location.origin);
    directoryUrl.hash = `!url=${encodeURIComponent(instanceUrl.href)}`;
    return directoryUrl.href;
  })();

  return (
    <section class="utility-strip" aria-label={COPY.utilities}>
      <div class="utility-strip__items">
        <a href={includedFeedsHref} target="_blank" rel="noopener noreferrer" class="utility-link">
          {COPY.tryIncludedFeeds}
        </a>
        <Bookmarklet onClick={onShowBookmarkletHelp} />
        {hasAccessToken && (
          <button type="button" class="utility-button" onClick={onClearToken}>
            {COPY.logout}
          </button>
        )}
        <a
          href="https://hub.docker.com/r/html2rss/web"
          target="_blank"
          rel="noopener noreferrer"
          class="utility-link"
        >
          {COPY.dockerInstall}
        </a>
        {openapiUrl && (
          <a
            href={normalizedOpenapiUrl ?? openapiUrl}
            target="_blank"
            rel="noopener noreferrer"
            class="utility-link"
          >
            {COPY.openapiSpec}
          </a>
        )}
        <a
          href="https://github.com/html2rss/html2rss-web"
          target="_blank"
          rel="noopener noreferrer"
          class="utility-link"
        >
          {COPY.sourceCode}
        </a>
      </div>
    </section>
  );
}

function normalizeLocalOriginUrl(value?: string): string | undefined {
  if (!value || globalThis.window === undefined) return value;

  try {
    const target = new URL(value, location.origin);
    const current = new URL(location.origin);
    const isLocalHost = (host: string) => host === 'localhost' || host === '127.0.0.1';

    if (isLocalHost(current.hostname) && isLocalHost(target.hostname) && target.port !== current.port) {
      return `${current.origin}${target.pathname}${target.search}${target.hash}`;
    }

    return target.href;
  } catch {
    return value;
  }
}
