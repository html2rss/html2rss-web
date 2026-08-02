import type {
  CreatedFeedResult,
  FeedCreationError,
  FeedPreviewState,
  FeedPreviewWarning,
  FeedRecord,
} from './api/contracts';

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
  routeKind,
  tokenError,
  tokenStateError,
  metadataError,
  result,
}: {
  conversionError?: FeedCreationError;
  feedFieldErrors: { url: string; form: string };
  isConverting: boolean;
  routeKind: 'create' | 'token' | 'result';
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

  if (routeKind === 'result' && result) {
    return {
      kind: 'result',
      feed: result.feed,
      preview: result.preview,
      warnings: result.warnings,
    };
  }

  if (isConverting) return { kind: 'submitting' };

  if (routeKind === 'token' || tokenError) {
    return { kind: 'token_prompt', tokenError, error: conversionError };
  }

  if (conversionError?.nextAction === 'enter_token' || conversionError?.kind === 'auth') {
    return { kind: 'token_prompt', tokenError, error: conversionError };
  }

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
