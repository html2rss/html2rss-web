import type {
  CreatedFeedResult,
  FeedPreviewItem,
  FeedPreviewStatus,
  FeedPreviewWarning,
  FeedRecord,
} from '../api/contracts';
import { COPY } from '../journey/copy';
import { buildPreviewWarning } from './feedErrors';
import { normalizePreviewItems } from './feedParsers';

export const PREVIEW_RETRY_DELAYS_MS = [260, 620, 1180, 1800] as const;
export const PREVIEW_UNAVAILABLE_MESSAGE = COPY.previewUnavailable;
export const PREVIEW_DEGRADED_MESSAGE = COPY.previewDegraded;

export interface PreviewLoadResult {
  items: FeedPreviewItem[];
  warnings: FeedPreviewWarning[];
  status: Extract<FeedPreviewStatus, 'preview_ready' | 'preview_failed'>;
}

interface JsonFeedResponse {
  items?: unknown[];
}

export function isTransientHttpStatus(status: number): boolean {
  return [408, 409, 425, 429, 500, 502, 503, 504].includes(status);
}

export function isAbortError(error: unknown): boolean {
  return (
    (error instanceof DOMException && error.name === 'AbortError') ||
    (error instanceof Error && error.name === 'AbortError')
  );
}

export async function wait(delayMs: number, signal?: AbortSignal): Promise<void> {
  if (delayMs <= 0) return;

  await new Promise<void>((resolve, reject) => {
    const timeoutHandle = setTimeout(() => {
      signal?.removeEventListener('abort', onAbort);
      resolve();
    }, delayMs);

    const onAbort = () => {
      clearTimeout(timeoutHandle);
      reject(new DOMException('Aborted', 'AbortError'));
    };

    if (signal) {
      if (signal.aborted) {
        clearTimeout(timeoutHandle);
        reject(new DOMException('Aborted', 'AbortError'));
        return;
      }

      signal.addEventListener('abort', onAbort, { once: true });
    }
  });
}

export function resolveFetchUrl(url: string): string {
  if (/^https?:\/\//i.test(url)) return url;
  const origin = globalThis.location?.origin ?? 'http://localhost';
  return new URL(url, origin).href;
}

export async function readJsonResponse<T>(response: Response): Promise<T | undefined> {
  const bodyText = await response.text();
  if (!bodyText.trim()) return undefined;

  try {
    return JSON.parse(bodyText) as T;
  } catch {
    return undefined;
  }
}

export function buildCreatedFeedResult(feed: FeedRecord): CreatedFeedResult {
  return {
    feed,
    preview: {
      status: 'created',
      items: [],
      isLoading: false,
    },
    warnings: [],
  };
}

export function buildPreviewLoadingResult(feed: FeedRecord): CreatedFeedResult {
  return {
    feed,
    preview: {
      status: 'preview_loading',
      items: [],
      isLoading: true,
    },
    warnings: [],
  };
}

export async function loadPreviewItemsWithRetry(
  previewUrl: string,
  signal?: AbortSignal
): Promise<PreviewLoadResult> {
  const delays = [0, ...PREVIEW_RETRY_DELAYS_MS];
  let latestRetryableFailure: PreviewLoadResult | undefined;

  for (const [index, delayMs] of delays.entries()) {
    if (delayMs > 0) await wait(delayMs, signal);

    const result = await loadPreviewItems(previewUrl, signal);
    if (result.status === 'preview_ready') return result;
    if (result.warnings.every((warning) => !warning.retryable)) return result;

    latestRetryableFailure = result;
    if (index === delays.length - 1) return result;
  }

  return (
    latestRetryableFailure ?? {
      items: [],
      warnings: [buildPreviewWarning('PREVIEW_FAILED', PREVIEW_UNAVAILABLE_MESSAGE, true, 'retry')],
      status: 'preview_failed',
    }
  );
}

export async function loadPreviewItems(previewUrl: string, signal?: AbortSignal): Promise<PreviewLoadResult> {
  let response: Response;

  try {
    response = await fetch(resolveFetchUrl(previewUrl), {
      headers: { Accept: 'application/feed+json' },
      signal,
    });
  } catch (error) {
    if (isAbortError(error)) throw error;

    return {
      items: [],
      warnings: [buildPreviewWarning('PREVIEW_NETWORK_ERROR', PREVIEW_UNAVAILABLE_MESSAGE, true, 'retry')],
      status: 'preview_failed',
    };
  }

  if (!response.ok) {
    return {
      items: [],
      warnings: [
        buildPreviewWarning(
          `PREVIEW_HTTP_${response.status}`,
          isTransientHttpStatus(response.status) ? PREVIEW_DEGRADED_MESSAGE : PREVIEW_UNAVAILABLE_MESSAGE,
          isTransientHttpStatus(response.status),
          isTransientHttpStatus(response.status) ? 'retry' : 'wait'
        ),
      ],
      status: 'preview_failed',
    };
  }

  try {
    const payload = (await response.json()) as JsonFeedResponse;
    return {
      items: normalizePreviewItems(payload.items),
      warnings: [],
      status: 'preview_ready',
    };
  } catch {
    return {
      items: [],
      warnings: [buildPreviewWarning('PREVIEW_INVALID_JSON', PREVIEW_UNAVAILABLE_MESSAGE, false, 'wait')],
      status: 'preview_failed',
    };
  }
}
