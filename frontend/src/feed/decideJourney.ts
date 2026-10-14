import type {
  CreatedFeedResult,
  FeedCreationError,
  FeedPreviewState,
  FeedPreviewWarning,
  FeedRecord,
} from '../api/contracts';
import type { AppRoute } from '../routes/appRoute';

/** In-memory unresolved result workspace (empty extraction + studio recovery). */
export interface UnresolvedWorkspace {
  readonly url: string;
  readonly notice: string;
}

/** Closed UI journey kinds owned by Feed Flow. */
export type AppViewModel =
  | { kind: 'create' }
  | { kind: 'submitting' }
  | { kind: 'token_prompt'; tokenError: string; error?: FeedCreationError }
  | {
      kind: 'result';
      phase: 'ready';
      feed: FeedRecord;
      preview: FeedPreviewState;
      warnings: FeedPreviewWarning[];
    }
  | {
      kind: 'result';
      phase: 'unresolved';
      url: string;
      notice: string;
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
  creationError,
  feedFieldErrors,
  isCreating,
  route,
  tokenError,
  result,
  unresolved,
}: {
  creationError?: FeedCreationError;
  feedFieldErrors: { url: string; form: string };
  isCreating: boolean;
  route: AppRoute;
  tokenError: string;
  result?: CreatedFeedResult;
  unresolved?: UnresolvedWorkspace;
}): AppViewModel {
  // Ready result: keep the panel mounted even when studio re-generate advances
  // the token before the hash catches up.
  if (route.kind === 'result' && result) {
    return {
      kind: 'result',
      phase: 'ready',
      feed: result.feed,
      preview: result.preview,
      warnings: result.warnings,
    };
  }

  // Unresolved workspace: in-memory only; cold `#/result` without unresolved recovers to create.
  if (route.kind === 'result' && unresolved) {
    return {
      kind: 'result',
      phase: 'unresolved',
      url: unresolved.url,
      notice: unresolved.notice,
    };
  }

  // Unmatched / cold result hash without in-memory workspace — Feed Flow recovers to create.
  if (route.kind === 'result') {
    return { kind: 'create' };
  }

  // Token prompt: URL adapter kind and/or in-field token error after Feed Flow navigates.
  if (route.kind === 'token' || tokenError) {
    return { kind: 'token_prompt', tokenError, error: creationError };
  }

  if (isCreating) return { kind: 'submitting' };

  if (feedFieldErrors.url || feedFieldErrors.form || creationError?.nextAction === 'correct_input') {
    return {
      kind: 'error',
      message: creationError?.message || feedFieldErrors.form,
      error: creationError,
      errorKind: creationError?.kind,
    };
  }

  if (creationError) {
    return {
      kind: 'error',
      message: creationError.message,
      error: creationError,
      errorKind: creationError.kind,
    };
  }

  return { kind: 'create' };
}
