import type {
  CreatedFeedResult,
  FeedCreationError,
  FeedPreviewState,
  FeedPreviewWarning,
  FeedRecord,
} from '../api/contracts';
import type { AppRoute } from '../routes/appRoute';

/** Closed UI journey kinds owned by Feed Flow. */
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

/**
 * Pure projection of journey kind from Feed Flow state.
 * Does not navigate — Feed Flow owns navigate + this projection together.
 * Auth → token_prompt is driven by route/tokenError after Feed Flow navigates.
 */
export function decideJourney({
  conversionError,
  feedFieldErrors,
  isConverting,
  route,
  tokenError,
  result,
}: {
  conversionError?: FeedCreationError;
  feedFieldErrors: { url: string; form: string };
  isConverting: boolean;
  route: AppRoute;
  tokenError: string;
  result?: CreatedFeedResult;
}): AppViewModel {
  if (route.kind === 'result' && result && result.feed.feed_token === route.feedToken) {
    return {
      kind: 'result',
      feed: result.feed,
      preview: result.preview,
      warnings: result.warnings,
    };
  }

  // Token prompt: URL adapter kind and/or in-field token error after Feed Flow navigates.
  if (route.kind === 'token' || tokenError) {
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
