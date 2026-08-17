import type {
  CreatedFeedResult,
  FeedCreationError,
  FeedPreviewState,
  FeedPreviewWarning,
  FeedRecord,
} from './api/contracts';
import type { AppRoute } from './routes/appRoute';

export type AppViewModel =
  | { kind: 'create' }
  | { kind: 'submitting' }
  | { kind: 'token_prompt'; tokenError: string; error?: FeedCreationError }
  | {
      kind: 'result';
      feed: FeedRecord;
      preview: FeedPreviewState;
      warnings: FeedPreviewWarning[];
    }
  | {
      kind: 'error';
      message: string;
      error?: FeedCreationError;
      errorKind?: FeedCreationError['kind'];
    };

export function deriveAppViewModel({
  conversionError,
  feedFieldErrors,
  isConverting,
  route,
  tokenError,
  tokenStateError,
  metadataError,
  result,
}: {
  conversionError?: FeedCreationError;
  feedFieldErrors: { url: string; form: string };
  isConverting: boolean;
  route: AppRoute;
  tokenError: string;
  tokenStateError?: string;
  metadataError?: string;
  result?: CreatedFeedResult;
}): AppViewModel {
  if (tokenStateError || metadataError) {
    return {
      kind: 'error',
      message: metadataError ?? tokenStateError ?? 'Instance unavailable.',
    };
  }

  if (route.kind === 'result' && result && result.feed.feed_token === route.feedToken) {
    return {
      kind: 'result',
      feed: result.feed,
      preview: result.preview,
      warnings: result.warnings,
    };
  }

  if (route.kind === 'token' || tokenError) {
    return { kind: 'token_prompt', tokenError, error: conversionError };
  }

  if (conversionError?.nextAction === 'enter_token' || conversionError?.kind === 'auth') {
    return { kind: 'token_prompt', tokenError, error: conversionError };
  }

  if (isConverting) return { kind: 'submitting' };

  if (feedFieldErrors.url || feedFieldErrors.form || conversionError?.nextAction === 'correct_input') {
    return {
      kind: 'error',
      message: conversionError?.message || feedFieldErrors.form,
      error: conversionError,
      errorKind: conversionError?.kind,
    };
  }

  if (conversionError) {
    return {
      kind: 'error',
      message: conversionError.message,
      error: conversionError,
      errorKind: conversionError.kind,
    };
  }

  return { kind: 'create' };
}

export interface PanelViewState {
  isTokenPrompt: boolean;
  isConverting: boolean;
  tokenError: string;
  errorKind?: FeedCreationError['kind'];
  failureMessage: string;
  isShowRetryButton: boolean;
}

export function getPanelViewState(
  viewModel: AppViewModel,
  feedFieldErrors: { form: string }
): PanelViewState {
  const isTokenPrompt = viewModel.kind === 'token_prompt';
  const isConverting = viewModel.kind === 'submitting';
  const conversionError =
    viewModel.kind === 'error' || viewModel.kind === 'token_prompt' ? viewModel.error : undefined;
  const tokenError = viewModel.kind === 'token_prompt' ? viewModel.tokenError : '';
  const errorKind = viewModel.kind === 'error' ? viewModel.errorKind : conversionError?.kind;

  const failureMessage = isTokenPrompt
    ? ''
    : (viewModel.kind === 'error' ? viewModel.message : undefined) ||
      conversionError?.message ||
      feedFieldErrors.form;

  const isShowRetryButton = Boolean(
    conversionError && conversionError.nextAction === 'retry' && conversionError.retryAction !== 'none'
  );

  return {
    isTokenPrompt,
    isConverting,
    tokenError,
    errorKind,
    failureMessage,
    isShowRetryButton,
  };
}
