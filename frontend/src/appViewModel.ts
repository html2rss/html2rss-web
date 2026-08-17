import type { FeedCreationError } from './api/contracts';
import type { AppViewModel } from './feed/decideJourney';

export type { AppViewModel } from './feed/decideJourney';

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
