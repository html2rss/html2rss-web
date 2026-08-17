import type { JSX } from 'preact';
import { ResultDisplay } from './ResultDisplay';
import { CreateFeedPanel, UtilityStrip } from './AppPanels';
import { Notice } from './Notice';
import { COPY } from '../copy';
import { useAppPresenter } from '../hooks/useAppPresenter';

function BrandLockup({ onNavigateHome }: { onNavigateHome: () => void }) {
  return (
    <a
      class="brand-lockup"
      href="/#/create"
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

export function App() {
  const {
    viewModel,
    feedFormData,
    feedFieldErrors,
    tokenDraft,
    bookmarkletNotice,
    focusCreateComposerKey,
    metadata,
    hasToken,
    isConverting,
    submitDisabled,
    feedCreationEnabled,
    featuredFeeds,
    metadataLoading,
    tokenLoading,
    metadataError,
    tokenStateError,
    onFeedSubmit,
    onFeedFieldChange,
    onTokenDraftChange,
    onSaveToken,
    onCancelTokenPrompt,
    onRetryCreate,
    onCreateAnother,
    onRetryPreview,
    onClearToken,
    onShowBookmarkletHelp,
    setBookmarkletNotice,
    navigate,
  } = useAppPresenter();

  let bodyContent: JSX.Element;
  if (metadataLoading || tokenLoading) {
    bodyContent = (
      <Notice title="Loading instance" state="loading" ariaLive="polite">
        <p>Reading feed-generation capabilities.</p>
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
        isConverting={isConverting}
        feedFormData={feedFormData}
        feedFieldErrors={feedFieldErrors}
        submitDisabled={submitDisabled}
        feedCreationEnabled={feedCreationEnabled}
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

  return (
    <div class="page-shell">
      <main class="page-main">
        <section class="workspace-shell workspace-shell--centered">
          <header class="workspace-hero">
            <BrandLockup onNavigateHome={() => navigate({ kind: 'create' })} />
          </header>

          <div class="workspace-content">
            {bookmarkletNotice && (
              <Notice
                title={COPY.bookmarkletTitle}
                actions={
                  <button
                    type="button"
                    class="btn btn--quiet btn--linkish"
                    onClick={() => setBookmarkletNotice('')}
                  >
                    {COPY.dismiss}
                  </button>
                }
              >
                <p>{COPY.bookmarkletHelp}</p>
              </Notice>
            )}

            {(metadataError || tokenStateError) && (
              <Notice tone="error" title={COPY.instanceMetadataUnavailable}>
                <p>{metadataError ?? tokenStateError}</p>
              </Notice>
            )}

            {bodyContent}
          </div>
        </section>
      </main>

      <footer class="app-footer" aria-label="Footer navigation">
        <div class="app-footer__inner">
          <UtilityStrip
            hasAccessToken={hasToken}
            openapiUrl={metadata?.api.openapi_url}
            onClearToken={onClearToken}
            onShowBookmarkletHelp={onShowBookmarkletHelp}
          />
        </div>
      </footer>
    </div>
  );
}
