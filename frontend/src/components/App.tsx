import type { JSX } from 'preact';
import { ResultDisplay } from './ResultDisplay';
import { CreateFeedPanel, UtilityStrip } from './AppPanels';
import { Notice } from './Notice';
import { COPY } from '../journey/copy';
import { useSession } from '../session';
import { useFeedFlow } from '../feed';
import { buildAppRouteHref, useAppRoute } from '../routes/appRoute';

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

export function App() {
  const { route, navigate, createEntryKey } = useAppRoute();

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
    bookmarkletNotice,
    focusCreateComposerKey,
    submitDisabled: flowSubmitDisabled,
    onFeedFieldChange,
    onFeedSubmit,
    onSaveToken,
    onCancelTokenPrompt,
    onRetryCreate,
    onCreateAnother,
    onRetryPreview,
    setBookmarkletNotice,
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
  const onShowBookmarkletHelp = () => setBookmarkletNotice('show');

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
            openapiUrl={metadata?.api.openapi_url}
            onClearToken={onClearToken}
            onShowBookmarkletHelp={onShowBookmarkletHelp}
          />
        </div>
      </footer>
    </div>
  );
}
