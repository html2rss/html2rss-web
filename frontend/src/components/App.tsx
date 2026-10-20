import type { JSX } from 'preact';
import { useEffect, useRef } from 'preact/hooks';
import { ResultDisplay } from './ResultDisplay';
import { CreateFeedPanel, UtilityStrip } from './AppPanels';
import { IosShortcutHelp } from './IosShortcutHelp';
import { Notice } from './Notice';
import { COPY } from '../journey/copy';
import { useSession } from '../session';
import { useFeedFlow, type UtilityHelpKind } from '../feed';
import { buildAppRouteHref, buildCreatePrefillPrefix, useAppRoute } from '../routes/appRoute';

function BrandLockup({ onNavigateHome }: { onNavigateHome: () => void }) {
  return (
    <a
      class="brand-lockup"
      href={buildAppRouteHref({ kind: 'create' })}
      aria-label="html2rss"
      onClick={(event) => {
        event.preventDefault();
        onNavigateHome();
      }}
    >
      <span class="brand-lockup__mark" aria-hidden="true">
        <span />
        <span />
        <span />
      </span>
      <strong class="brand-lockup__wordmark">html2rss</strong>
    </a>
  );
}

function utilityHelpControlId(kind: UtilityHelpKind): string {
  return kind === 'bookmarklet' ? 'bookmarklet' : 'ios-shortcut';
}

export function App() {
  const { route, navigate, createEntryKey } = useAppRoute();
  const dismissHelpButtonReference = useRef<HTMLButtonElement>(null);
  const lastUtilityHelpReference = useRef<UtilityHelpKind | undefined>(undefined);
  const createPrefillPrefix = buildCreatePrefillPrefix();

  const {
    token,
    hasToken,
    metadata,
    catalogEntries,
    featuredFeeds,
    isLoading: sessionLoading,
    metadataError,
    tokenStateError,
    saveToken,
    clearToken,
    feedCreationEnabled,
    mayCreate,
  } = useSession();

  const {
    viewModel,
    isCreating,
    clearError,
    feedFormData,
    feedFieldErrors,
    tokenDraft,
    utilityHelp,
    focusCreateComposerKey,
    submitDisabled: flowSubmitDisabled,
    onFeedFieldChange,
    onFeedSubmit,
    onSaveToken,
    onCancelTokenPrompt,
    onRetryCreate,
    onCreateAnother,
    onRetryPreview,
    setUtilityHelp,
    setTokenDraft,
    setTokenError,
  } = useFeedFlow({
    token,
    isLoading: sessionLoading,
    feedCreationEnabled,
    mayCreate,
    saveToken,
    clearToken,
    route,
    navigate,
    createEntryKey,
  });

  useEffect(() => {
    if (!utilityHelp) return;

    lastUtilityHelpReference.current = utilityHelp;
    const focusHandle = requestAnimationFrame(() => {
      dismissHelpButtonReference.current?.focus();
    });
    return () => cancelAnimationFrame(focusHandle);
  }, [utilityHelp]);

  const submitDisabled = flowSubmitDisabled || viewModel.kind === 'token_prompt';
  const onTokenDraftChange = (value: string) => {
    setTokenDraft(value);
    setTokenError('');
    clearError();
  };
  const onClearToken = () => {
    clearToken();
    setTokenDraft('');
    setTokenError('');
    clearError();
    navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
  };
  const onShowBookmarkletHelp = () => setUtilityHelp('bookmarklet');
  const onShowIosShortcutHelp = () => setUtilityHelp('iosShortcut');
  const onDismissUtilityHelp = () => {
    const invoker = lastUtilityHelpReference.current;
    setUtilityHelp(undefined);
    requestAnimationFrame(() => {
      if (!invoker) return;
      const control = document.querySelector<HTMLElement>(`#${utilityHelpControlId(invoker)}`);
      control?.focus();
    });
  };

  let bodyContent: JSX.Element;
  if (sessionLoading) {
    bodyContent = (
      <Notice title={COPY.loadingInstance} state="loading" ariaLive="polite">
        <p>{COPY.loadingInstanceBody}</p>
      </Notice>
    );
  } else if (viewModel.kind === 'result') {
    bodyContent = (
      <ResultDisplay
        viewModel={viewModel}
        onCreateAnother={onCreateAnother}
        onRetryPreview={onRetryPreview}
      />
    );
  } else {
    bodyContent = (
      <CreateFeedPanel
        focusComposerKey={focusCreateComposerKey}
        viewModel={viewModel}
        isCreating={isCreating}
        feedFormData={feedFormData}
        feedFieldErrors={feedFieldErrors}
        submitDisabled={submitDisabled}
        feedCreationEnabled={feedCreationEnabled}
        catalogEntries={catalogEntries}
        featuredFeeds={featuredFeeds}
        tokenDraft={tokenDraft}
        onFeedSubmit={onFeedSubmit}
        onFeedFieldChange={onFeedFieldChange}
        onTokenDraftChange={onTokenDraftChange}
        onSaveToken={onSaveToken}
        onCancelTokenPrompt={onCancelTokenPrompt}
        onRetryCreate={onRetryCreate}
      />
    );
  }

  let utilityHelpNotice: JSX.Element | undefined;
  if (utilityHelp === 'bookmarklet') {
    utilityHelpNotice = (
      <Notice
        title={COPY.bookmarkletTitle}
        ariaLive="polite"
        onDismiss={onDismissUtilityHelp}
        dismissRef={dismissHelpButtonReference}
      >
        <p>{COPY.bookmarkletHelp}</p>
      </Notice>
    );
  } else if (utilityHelp === 'iosShortcut') {
    utilityHelpNotice = (
      <Notice
        title={COPY.iosShortcutTitle}
        ariaLive="polite"
        onDismiss={onDismissUtilityHelp}
        dismissRef={dismissHelpButtonReference}
      >
        <IosShortcutHelp createPrefillPrefix={createPrefillPrefix} />
      </Notice>
    );
  }

  return (
    <div class="page-shell">
      <main class="page-main layout-shell-padding">
        <section class="workspace-shell workspace-shell--centered">
          <header class="workspace-hero">
            <BrandLockup onNavigateHome={() => navigate({ kind: 'create' })} />
          </header>

          <div class="workspace-content">
            {utilityHelpNotice}

            {(metadataError || tokenStateError) && (
              <Notice
                tone="error"
                title={metadataError ? COPY.instanceMetadataUnavailable : COPY.accessTokenUnavailable}
              >
                <p>{metadataError ?? tokenStateError}</p>
              </Notice>
            )}

            {bodyContent}
          </div>
        </section>
      </main>

      <footer class="app-footer" aria-label={COPY.footerNav}>
        <div class="app-footer__inner">
          <UtilityStrip
            hasAccessToken={hasToken}
            catalogCount={catalogEntries.length}
            openapiUrl={metadata?.api.openapi_url}
            onClearToken={onClearToken}
            bookmarkletHelpExpanded={utilityHelp === 'bookmarklet'}
            iosShortcutHelpExpanded={utilityHelp === 'iosShortcut'}
            onShowBookmarkletHelp={onShowBookmarkletHelp}
            onShowIosShortcutHelp={onShowIosShortcutHelp}
          />
        </div>
      </footer>
    </div>
  );
}
