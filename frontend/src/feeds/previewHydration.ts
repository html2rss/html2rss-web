import type {
  CreatedFeedResult,
  FeedPreviewItem,
  FeedPreviewStatus,
  FeedPreviewWarning,
  FeedNextAction,
  FeedRecord,
} from '../api/contracts';
import { isAbortError, isTransientHttpStatus, normalizeString, resolveFetchUrl, wait } from './shared';

export const PREVIEW_RETRY_DELAYS_MS = [260, 620, 1180, 1800] as const;
export const PREVIEW_UNAVAILABLE_MESSAGE = 'Preview unavailable right now.';
export const PREVIEW_DEGRADED_MESSAGE = 'Preview content is partially degraded right now.';

export interface PreviewLoadResult {
  items: FeedPreviewItem[];
  warnings: FeedPreviewWarning[];
  status: Extract<FeedPreviewStatus, 'preview_ready' | 'preview_failed'>;
}

interface JsonFeedResponse {
  items?: unknown[];
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

export function buildPreviewWarning(
  code: string,
  message: string,
  // eslint-disable-next-line unicorn/consistent-boolean-name
  retryable: boolean,
  nextAction: FeedNextAction
): FeedPreviewWarning {
  return { code, message, retryable, nextAction };
}

export function normalizePreviewItems(items: unknown[] | undefined): FeedPreviewItem[] {
  if (!Array.isArray(items)) return [];

  return items
    .map((item) => normalizePreviewItem(item))
    .filter((item): item is FeedPreviewItem => item !== undefined)
    .slice(0, 5);
}

function normalizePreviewItem(value: unknown): FeedPreviewItem | undefined {
  if (!value || typeof value !== 'object') return undefined;

  const candidate = value as {
    title?: unknown;
    excerpt?: unknown;
    description?: unknown;
    content_text?: unknown;
    contentText?: unknown;
    published_label?: unknown;
    publishedLabel?: unknown;
    date_published?: unknown;
    datePublished?: unknown;
    date_modified?: unknown;
    dateModified?: unknown;
    url?: unknown;
  };

  const title = normalizeString(candidate.title);
  if (!title) return undefined;

  const url = normalizeString(candidate.url);

  return {
    title,
    excerpt:
      normalizeString(
        candidate.excerpt ?? candidate.description ?? candidate.content_text ?? candidate.contentText
      ) || '',
    publishedLabel:
      normalizeString(
        candidate.published_label ??
          candidate.publishedLabel ??
          candidate.date_published ??
          candidate.datePublished ??
          candidate.date_modified ??
          candidate.dateModified
      ) || '',
    ...(url && { url }),
  };
}
