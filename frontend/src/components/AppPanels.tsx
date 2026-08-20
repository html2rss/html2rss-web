import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'preact/hooks';
import type { JSX, RefObject } from 'preact';
import { Bookmarklet } from './Bookmarklet';
import { DominantField } from './DominantField';
import { Notice } from './Notice';
import type { CatalogEntry } from '../catalog';
import { catalogFeedHref, findCatalogEntries } from '../catalog';
import type { AppViewModel } from '../feed';
import { COPY } from '../journey/copy';

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
  isCreating: boolean;
  feedFormData: FeedFormData;
  feedFieldErrors: FeedFieldErrors;
  submitDisabled: boolean;
  feedCreationEnabled: boolean;
  catalogEntries: CatalogEntry[];
  featuredFeeds: CatalogEntry[];
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
  isCreating: boolean;
  feedCreationEnabled: boolean;
  catalogEntries: CatalogEntry[];
  featuredFeeds: CatalogEntry[];
  inputRef: RefObject<HTMLInputElement>;
  onInput: (value: string) => void;
}

const CATALOG_FIND_LISTBOX_ID = 'catalog-find-hits';

function catalogHitOptionId(index: number): string {
  return `${CATALOG_FIND_LISTBOX_ID}-option-${index}`;
}

interface CatalogHitListProperties {
  entries: readonly CatalogEntry[];
  ariaLabel: string;
  listboxId?: string;
  activeIndex?: number;
}

function CatalogHitList({ entries, ariaLabel, listboxId, activeIndex }: CatalogHitListProperties) {
  const isListbox = listboxId !== undefined;

  return (
    <div
      class="catalog-hit-list layout-stack layout-stack--tight"
      id={listboxId}
      role={isListbox ? 'listbox' : 'list'}
      aria-label={ariaLabel}
    >
      {entries.map((entry, index) => {
        const isActive = isListbox && activeIndex === index;
        const hit = (
          <a
            key={entry.id}
            id={isListbox ? catalogHitOptionId(index) : undefined}
            href={catalogFeedHref(entry)}
            rel="noopener"
            class="catalog-hit"
            role={isListbox ? 'option' : undefined}
            aria-selected={isListbox ? isActive : undefined}
            data-active={isActive ? '' : undefined}
            aria-label={entry.title}
          >
            <span class="catalog-hit__title ui-item__title">{entry.title}</span>
            {entry.description ? (
              <span class="catalog-hit__excerpt ui-item__excerpt">{entry.description}</span>
            ) : undefined}
          </a>
        );

        if (isListbox) return hit;

        return (
          <div key={entry.id} role="listitem">
            {hit}
          </div>
        );
      })}
    </div>
  );
}

function UrlEntrySection({
  url,
  disabled,
  error,
  isCreating,
  feedCreationEnabled,
  catalogEntries,
  featuredFeeds,
  inputRef,
  onInput,
}: UrlEntrySectionProperties) {
  const catalogHits = useMemo(() => findCatalogEntries(url, catalogEntries), [url, catalogEntries]);
  const [activeHitIndex, setActiveHitIndex] = useState<number | undefined>(undefined);
  const hasHits = catalogHits.length > 0;

  useEffect(() => {
    setActiveHitIndex(undefined);
  }, [catalogHits]);

  const handleUrlKeyDown: JSX.KeyboardEventHandler<HTMLInputElement> = (event) => {
    if (!hasHits || event.isComposing || event.repeat) return;

    if (event.key === 'ArrowDown') {
      event.preventDefault();
      setActiveHitIndex((current) => (current === undefined ? 0 : (current + 1) % catalogHits.length));
      return;
    }

    if (event.key === 'ArrowUp') {
      event.preventDefault();
      setActiveHitIndex((current) =>
        current === undefined
          ? catalogHits.length - 1
          : (current - 1 + catalogHits.length) % catalogHits.length
      );
      return;
    }

    if (event.key === 'Escape') {
      if (activeHitIndex === undefined) return;
      event.preventDefault();
      setActiveHitIndex(undefined);
      return;
    }

    if (event.key === 'Enter' && activeHitIndex !== undefined) {
      const active = catalogHits[activeHitIndex];
      if (!active) return;

      event.preventDefault();
      location.assign(catalogFeedHref(active));
    }
  };

  return (
    <>
      <DominantField
        className="layout-rail-reading"
        id="url"
        label={COPY.urlLabel}
        type="text"
        value={url}
        placeholder={COPY.urlPlaceholder}
        inputMode="url"
        autoCapitalize="off"
        spellcheck={false}
        autoFocus
        inputRef={inputRef}
        actionLabel={isCreating ? COPY.creating : COPY.createFeed}
        actionText={isCreating ? '...' : '>'}
        disabled={disabled}
        error={error}
        aria-controls={hasHits ? CATALOG_FIND_LISTBOX_ID : undefined}
        aria-expanded={hasHits}
        aria-activedescendant={activeHitIndex === undefined ? undefined : catalogHitOptionId(activeHitIndex)}
        onKeyDown={handleUrlKeyDown}
        onInput={(event) => onInput(event.currentTarget.value)}
      />

      {hasHits && (
        <div class="layout-rail-reading" role="status">
          <p class="field-help">{COPY.catalogFindHint}</p>
          <CatalogHitList
            entries={catalogHits}
            ariaLabel={COPY.catalogFindHitsLabel}
            listboxId={CATALOG_FIND_LISTBOX_ID}
            activeIndex={activeHitIndex}
          />
        </div>
      )}

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
              <CatalogHitList entries={featuredFeeds} ariaLabel={COPY.includedFeedsTitle} />
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
  isCreating: boolean;
  inputRef: RefObject<HTMLInputElement>;
  onTokenDraftChange: (value: string) => void;
  onSaveToken: () => void;
  onCancelTokenPrompt: () => void;
}

function TokenGateSection({
  tokenDraft,
  tokenError,
  isCreating,
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
        <button type="button" class="btn btn--primary" disabled={isCreating} onClick={onSaveToken}>
          {isCreating ? COPY.creating : COPY.saveAndContinue}
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
  isCreating: boolean;
  isShowRetryButton: boolean;
  onRetryCreate: () => void;
}

function ActionFeedback({
  failureMessage,
  isCreating,
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

      {isCreating && <Notice className="layout-rail-reading" state="loading" title={COPY.creating} />}
    </>
  );
}

export function CreateFeedPanel({
  focusComposerKey,
  viewModel,
  isCreating: flowCreating,
  feedFormData,
  feedFieldErrors,
  submitDisabled,
  feedCreationEnabled,
  catalogEntries,
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
  const creationError =
    viewModel.kind === 'error' || viewModel.kind === 'token_prompt' ? viewModel.error : undefined;
  const tokenError = viewModel.kind === 'token_prompt' ? viewModel.tokenError : '';
  const errorKind = viewModel.kind === 'error' ? viewModel.errorKind : creationError?.kind;
  const failureMessage = isTokenPrompt
    ? ''
    : (viewModel.kind === 'error' ? viewModel.message : undefined) ||
      creationError?.message ||
      feedFieldErrors.form;
  const isShowRetryButton = Boolean(
    creationError && creationError.nextAction === 'retry' && creationError.retryAction !== 'none'
  );
  const isCreatingFeed = !isTokenPrompt && isSubmitting;
  const tokenCreating = isTokenPrompt && flowCreating;

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
          isCreating={isCreatingFeed}
          feedCreationEnabled={feedCreationEnabled}
          catalogEntries={catalogEntries}
          featuredFeeds={featuredFeeds}
          inputRef={urlInputReference}
          onInput={(value) => onFeedFieldChange('url', value)}
        />
        <ActionFeedback
          failureMessage={failureMessage}
          isCreating={isCreatingFeed}
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
            isCreating={tokenCreating}
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
