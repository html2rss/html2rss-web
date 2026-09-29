import { useEffect, useRef, useState } from 'preact/hooks';
import type { CreatedFeedResult, FeedCreationError, PreviewAudience } from '../api/contracts';
import type { StudioSelectors } from '../studio/selectorDraft';
import { isAbortError } from '../api/http/client';
import {
  normalizeFeedCreationError,
  requestFeedCreation,
  buildCreatedFeedResult,
  buildPreviewLoadingResult,
  buildPreviewWarning,
  loadPreviewItemsWithRetry,
  PREVIEW_UNAVAILABLE_MESSAGE,
  previewAudienceForToken,
} from '../feeds/feedsService';

interface CreationState {
  isCreating: boolean;
  result?: CreatedFeedResult;
  error?: FeedCreationError;
}

/**
 * Feed creation IO only. Callers must pass an already-expanded http(s) URL
 * from `expandCreateUrl` — this module does not re-normalize or validate emptiness.
 */
export function useFeedCreation() {
  const requestIdReference = useRef(0);
  const previewAbortControllerReference = useRef<AbortController | undefined>(undefined);
  const previewAudienceReference = useRef<PreviewAudience>('guest');
  const [state, setState] = useState<CreationState>({ isCreating: false });

  const cancelPreview = () => {
    previewAbortControllerReference.current?.abort();
    previewAbortControllerReference.current = undefined;
  };

  useEffect(
    () => () => {
      requestIdReference.current += 1;
      cancelPreview();
    },
    []
  );

  async function createFeed(normalizedUrl: string, token: string, selectors?: StudioSelectors) {
    const requestId = requestIdReference.current + 1;
    requestIdReference.current = requestId;
    cancelPreview();
    setState((previous) => ({ ...previous, isCreating: true, error: undefined }));

    try {
      const feed = await requestFeedCreation(normalizedUrl, token, selectors);
      const audience = previewAudienceForToken(token);
      if (requestIdReference.current === requestId) {
        previewAudienceReference.current = audience;
      }
      const result = buildCreatedFeedResult(feed);
      commitResult(result, requestId, setState, requestIdReference);
      void hydrateFeedPreview(
        feed,
        audience,
        requestId,
        setState,
        requestIdReference,
        previewAbortControllerReference
      );
      return result;
    } catch (error) {
      const structuredError = normalizeFeedCreationError(error);
      failCreation(setState, structuredError);
      throw structuredError;
    }
  }

  const clearResult = () => {
    globalThis.document?.body?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    requestIdReference.current += 1;
    cancelPreview();
    setState((previous) => ({
      ...previous,
      isCreating: false,
      result: undefined,
    }));
  };

  const clearError = () => {
    setState((previous) => ({ ...previous, error: undefined }));
  };

  const retryPreviewFetch = () => {
    const currentResult = state.result;
    if (!currentResult) return;

    const requestId = requestIdReference.current + 1;
    requestIdReference.current = requestId;
    cancelPreview();

    void hydrateFeedPreview(
      currentResult.feed,
      previewAudienceReference.current,
      requestId,
      setState,
      requestIdReference,
      previewAbortControllerReference
    );
  };

  return {
    isCreating: state.isCreating,
    result: state.result,
    error: state.error,
    createFeed,
    clearError,
    clearResult,
    retryPreviewFetch,
  };
}

async function hydrateFeedPreview(
  feed: CreatedFeedResult['feed'],
  audience: PreviewAudience,
  requestId: number,
  setState: (value: CreationState | ((previous: CreationState) => CreationState)) => void,
  requestIdReference: { current: number },
  previewAbortControllerReference: { current: AbortController | undefined }
) {
  previewAbortControllerReference.current?.abort();
  const controller = new AbortController();
  previewAbortControllerReference.current = controller;

  commitResult(buildPreviewLoadingResult(feed), requestId, setState, requestIdReference);

  try {
    const previewResult = await loadPreviewItemsWithRetry(feed.json_public_url, controller.signal, audience);
    if (requestIdReference.current !== requestId) return;

    commitResult(
      {
        feed,
        preview: {
          status: previewResult.status,
          items: previewResult.items,
          isLoading: false,
        },
        warnings: previewResult.warnings,
      },
      requestId,
      setState,
      requestIdReference
    );
  } catch (error) {
    if (isAbortError(error)) return;

    commitResult(
      {
        feed,
        preview: {
          status: 'preview_failed',
          items: [],
          isLoading: false,
        },
        warnings: [buildPreviewWarning('PREVIEW_FAILED', PREVIEW_UNAVAILABLE_MESSAGE, true, 'retry')],
      },
      requestId,
      setState,
      requestIdReference
    );
  } finally {
    if (previewAbortControllerReference.current === controller) {
      previewAbortControllerReference.current = undefined;
    }
  }
}

function commitResult(
  result: CreatedFeedResult,
  requestId: number,
  setState: (value: CreationState | ((previous: CreationState) => CreationState)) => void,
  requestIdReference: { current: number }
) {
  setState((previous) => {
    if (requestIdReference.current !== requestId) {
      return previous;
    }

    return {
      ...previous,
      isCreating: false,
      error: undefined,
      result,
    };
  });
}

function failCreation(
  setState: (value: CreationState | ((previous: CreationState) => CreationState)) => void,
  error: FeedCreationError
) {
  setState((previous) => ({
    ...previous,
    isCreating: false,
    error,
  }));
}
