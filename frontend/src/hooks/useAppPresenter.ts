import { useSession } from './useSession';
import { useFeedFlow } from './useFeedFlow';
import { useAppRoute } from '../routes/appRoute';
import { deriveAppViewModel } from '../appViewModel';

/**
 * Custom hook that coordinates session and feed flow domain modules,
 * deriving the active ViewModel for the main application shell.
 */
export function useAppPresenter() {
  const { route, navigate } = useAppRoute();

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
  } = useSession();

  const {
    isConverting,
    result,
    conversionError,
    clearError,
    feedFormData,
    feedFieldErrors,
    tokenDraft,
    tokenError,
    bookmarkletNotice,
    focusCreateComposerKey,
    submitDisabled,
    feedCreationEnabled,
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
    metadata,
    isLoading: sessionLoading,
    saveToken,
    clearToken,
    route,
    navigate,
  });

  const viewModel = deriveAppViewModel({
    conversionError,
    feedFieldErrors,
    isConverting,
    route,
    tokenError,
    tokenStateError,
    metadataError,
    result,
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
