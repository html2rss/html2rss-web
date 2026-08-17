import { useSession } from '../session';
import { useFeedFlow } from '../feed';
import { useAppRoute } from '../routes/appRoute';

/**
 * Custom hook that coordinates session and feed flow domain modules,
 * deriving the active ViewModel for the main application shell.
 */
export function useAppPresenter() {
  const { route, navigate, createEntryKey } = useAppRoute();

  const {
    token,
    hasToken,
    metadata,
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
    isConverting,
    clearError,
    feedFormData,
    feedFieldErrors,
    tokenDraft,
    tokenError,
    bookmarkletNotice,
    focusCreateComposerKey,
    submitDisabled,
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
    tokenStateError,
    metadataError,
  });

  return {
    route,
    viewModel,
    feedFormData,
    feedFieldErrors,
    tokenDraft,
    tokenError,
    bookmarkletNotice,
    focusCreateComposerKey,
    metadata,
    hasToken,
    isConverting,
    submitDisabled: submitDisabled || viewModel.kind === 'token_prompt',
    feedCreationEnabled,
    featuredFeeds,
    metadataLoading: sessionLoading,
    tokenLoading: sessionLoading,
    metadataError,
    tokenStateError,
    onFeedSubmit,
    onFeedFieldChange,
    onTokenDraftChange: (value: string) => {
      setTokenDraft(value);
      setTokenError('');
      clearError();
    },
    onSaveToken,
    onCancelTokenPrompt,
    onRetryCreate,
    onCreateAnother,
    onRetryPreview,
    onClearToken: () => {
      clearToken();
      clearError();
      navigate({ kind: 'create', prefillUrl: feedFormData.url || undefined });
    },
    onShowBookmarkletHelp: () => setBookmarkletNotice('show'),
    setBookmarkletNotice,
    navigate,
  };
}
