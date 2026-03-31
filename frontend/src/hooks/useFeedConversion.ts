import { useRef, useState } from 'preact/hooks';
import { createFeed } from '../api/generated';
import { apiClient } from '../api/client';
import type { CreatedFeedResult, FeedPreviewItem, FeedRecord } from '../api/contracts';
import { normalizeUserUrl } from '../utils/url';

interface JsonFeedItem {
  title?: string;
  content_text?: string;
  content_html?: string;
  url?: string;
  external_url?: string;
  date_published?: string;
}

interface JsonFeedResponse {
  items?: JsonFeedItem[];
}

interface ConversionState {
  isConverting: boolean;
  result?: CreatedFeedResult;
  error?: string;
}

interface ConversionError extends Error {
  manualRetryStrategy?: string;
}

const PREVIEW_UNAVAILABLE_MESSAGE = 'Preview unavailable right now.';
const NON_RETRYABLE_ERROR_CODES = new Set(['BAD_REQUEST', 'UNAUTHORIZED', 'FORBIDDEN']);

export function useFeedConversion() {
  const requestIdReference = useRef(0);
  const [state, setState] = useState<ConversionState>({
    isConverting: false,
  });

  const convertFeed = async (url: string, strategy: string, token: string) => {
    const normalizedUrl = normalizeUserUrl(url);
    const requestedStrategy = strategy.trim();
    const fallbackStrategy = requestedStrategy === 'faraday' ? 'browserless' : undefined;

    if (!normalizedUrl) throw new Error('URL is required');
    if (!requestedStrategy) throw new Error('Strategy is required');

    if (!isValidHttpUrl(normalizedUrl)) {
      throw new Error('Invalid URL format');
    }

    const requestId = requestIdReference.current + 1;
    requestIdReference.current = requestId;
    markConversionStarted(setState);

    try {
      const feed = await requestFeedCreation(normalizedUrl, requestedStrategy, token);
      return publishCreatedFeed(feed, undefined, requestId, setState, requestIdReference);
    } catch (firstError) {
      if (shouldAutoRetry(requestedStrategy, fallbackStrategy, firstError)) {
        try {
          const feed = await requestFeedCreation(normalizedUrl, fallbackStrategy, token);
          return publishCreatedFeed(
            feed,
            { automatic: true, from: requestedStrategy, to: fallbackStrategy },
            requestId,
            setState,
            requestIdReference
          );
        } catch (secondError) {
          const message = buildRetryFailureMessage(
            firstError,
            secondError,
            requestedStrategy,
            fallbackStrategy
          );
          failConversion(setState, message, { manualRetryStrategy: undefined });
        }
      }

      const message = toErrorMessage(firstError);
      failConversion(setState, message, { manualRetryStrategy: alternateStrategy(requestedStrategy) });
    }
  };

  const clearResult = () => {
    globalThis.document.body.scrollIntoView({ behavior: 'smooth', block: 'start' });
    requestIdReference.current += 1;

    setState({
      isConverting: false,
    });
  };

  const clearError = () => {
    setState((previous) => ({ ...previous, error: undefined }));
  };

  return {
    isConverting: state.isConverting,
    result: state.result,
    error: state.error,
    convertFeed,
    clearError,
    clearResult,
  };
}

async function loadPreview(feed: FeedRecord): Promise<CreatedFeedResult['preview']> {
  const response = await globalThis.fetch(feed.json_public_url, {
    headers: { Accept: 'application/feed+json' },
  });

  if (!response.ok) throw new Error(PREVIEW_UNAVAILABLE_MESSAGE);

  const payload = (await response.json()) as JsonFeedResponse;
  const items =
    payload.items
      ?.map((item) => normalizePreviewItem(item))
      .filter((item): item is FeedPreviewItem => item !== undefined)
      .slice(0, 5) || [];

  return {
    items,
    error: items.length > 0 ? undefined : PREVIEW_UNAVAILABLE_MESSAGE,
    isLoading: false,
  };
}

function buildLoadingPreviewState(): CreatedFeedResult['preview'] {
  return {
    items: [],
    error: undefined,
    isLoading: true,
  };
}

async function hydratePreview(
  feed: FeedRecord,
  requestId: number,
  retry: CreatedFeedResult['retry'],
  setState: (value: ConversionState | ((previous: ConversionState) => ConversionState)) => void,
  requestIdReference: { current: number }
) {
  const preview = await loadPreview(feed).catch((error: unknown) => ({
    items: [],
    error: toPreviewErrorMessage(error),
    isLoading: false,
  }));

  if (requestIdReference.current !== requestId) return;

  setState((previous) => {
    if (
      requestIdReference.current !== requestId ||
      !previous.result ||
      previous.result.feed.feed_token !== feed.feed_token
    ) {
      return previous;
    }

    return {
      ...previous,
      result: {
        feed,
        preview,
        retry,
      },
    };
  });
}

async function requestFeedCreation(url: string, strategy: string, token: string): Promise<FeedRecord> {
  const response = await createFeed({
    client: apiClient,
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: {
      url,
      strategy,
    },
    throwOnError: true,
  });

  if (!response.data?.success || !response.data.data?.feed) {
    throw new Error('Invalid response format');
  }

  return response.data.data.feed;
}

function isValidHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

function alternateStrategy(strategy: string): string | undefined {
  if (strategy === 'faraday') return 'browserless';
  if (strategy === 'browserless') return 'faraday';
  return undefined;
}

function shouldAutoRetry(
  strategy: string,
  fallbackStrategy: string | undefined,
  error: unknown
): fallbackStrategy is string {
  if (strategy !== 'faraday' || !fallbackStrategy) return false;
  return retryableForFallback(error);
}

function buildRetryFailureMessage(
  firstError: unknown,
  secondError: unknown,
  requestedStrategy: string,
  fallbackStrategy: string
): string {
  const secondMessage = toErrorMessage(secondError);
  const firstMessage = toErrorMessage(firstError);

  if (firstMessage === secondMessage) {
    return `Tried ${requestedStrategy} first, then ${fallbackStrategy}. ${secondMessage}`;
  }

  return `Tried ${requestedStrategy} first, then ${fallbackStrategy}. First attempt failed with: ${firstMessage}. Second attempt failed with: ${secondMessage}`;
}

function buildConversionError(message: string, metadata: Partial<ConversionError>): ConversionError {
  return Object.assign(new Error(message), metadata);
}

const toErrorMessage = (error: unknown): string => {
  const details = extractErrorDetails(error);
  const detailsMessage = details?.message?.toLowerCase();
  if (
    detailsMessage &&
    (detailsMessage.includes('not valid json') || detailsMessage.includes('unexpected token'))
  ) {
    return 'Invalid response format from feed creation API';
  }
  if (details?.message) return details.message;
  if (error instanceof SyntaxError) return 'Invalid response format from feed creation API';
  if (error instanceof Error) {
    const normalizedMessage = error.message.toLowerCase();
    if (normalizedMessage.includes('not valid json') || normalizedMessage.includes('unexpected token')) {
      return 'Invalid response format from feed creation API';
    }

    return error.message;
  }
  if (typeof error === 'string' && error.trim()) return error;
  return 'An unexpected error occurred';
};

const toPreviewErrorMessage = (error: unknown): string => {
  if (error instanceof SyntaxError) return PREVIEW_UNAVAILABLE_MESSAGE;
  if (error instanceof Error && error.message.trim()) return error.message;
  return PREVIEW_UNAVAILABLE_MESSAGE;
};

function markConversionStarted(
  setState: (value: ConversionState | ((previous: ConversionState) => ConversionState)) => void
) {
  setState((previous) => ({ ...previous, isConverting: true, error: undefined }));
}

function publishCreatedFeed(
  feed: FeedRecord,
  retry: CreatedFeedResult['retry'],
  requestId: number,
  setState: (value: ConversionState | ((previous: ConversionState) => ConversionState)) => void,
  requestIdReference: { current: number }
): CreatedFeedResult {
  const result: CreatedFeedResult = {
    feed,
    preview: buildLoadingPreviewState(),
    retry,
  };

  setState((previous) => ({ ...previous, isConverting: false, result, error: undefined }));
  void hydratePreview(feed, requestId, retry, setState, requestIdReference);
  return result;
}

function failConversion(
  setState: (value: ConversionState | ((previous: ConversionState) => ConversionState)) => void,
  message: string,
  metadata: Partial<ConversionError>
): never {
  setState((previous) => ({
    ...previous,
    isConverting: false,
    error: message,
    result: undefined,
  }));

  throw buildConversionError(message, metadata);
}

const extractErrorDetails = (
  error: unknown
): { message?: string; code?: string; status?: number } | undefined => {
  if (!error || typeof error !== 'object') return undefined;

  const candidate = error as {
    error?: { message?: unknown; code?: unknown; status?: unknown };
    message?: unknown;
    code?: unknown;
    status?: unknown;
  };

  const message = normalizeString(candidate.error?.message ?? candidate.message);
  const code = normalizeString(candidate.error?.code ?? candidate.code);
  const status = normalizeStatus(candidate.error?.status ?? candidate.status);
  return { message, code, status };
};

function retryableForFallback(error: unknown): boolean {
  const details = extractErrorDetails(error);
  const errorCode = details?.code?.toUpperCase();
  const status = details?.status;
  if (errorCode && NON_RETRYABLE_ERROR_CODES.has(errorCode)) return false;
  if (status && status < 500) return false;

  const message = (details?.message ?? toErrorMessage(error)).toLowerCase();
  if (!details?.code && (message.includes('unauthorized') || message.includes('forbidden'))) return false;
  if (!details?.code && message.includes('bad request')) return false;
  if (message.includes('access token') || message.includes('authentication')) return false;
  if (message.includes('unsupported strategy')) return false;
  if (message.includes('invalid response format')) return false;
  if (message.includes('not valid json') || message.includes('unexpected token')) return false;
  if (message === 'network error') return false;
  if (error instanceof SyntaxError) return false;

  if (status && status >= 500) return true;
  if (message.includes('failed to fetch http')) return true;
  return message.includes('internal server error') || message.includes('upstream timeout');
}

function normalizeString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value : undefined;
}

function normalizeStatus(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function normalizePreviewText(value?: string): string | undefined {
  if (!value) return undefined;

  const normalized = decodeHtmlEntities(value)
    .replaceAll(/<[^>]*>/g, ' ')
    .replaceAll(/\s+/g, ' ')
    .replaceAll(/\s+([!,.:;?])/g, '$1')
    .replace(/^\d+\.\s+/, '')
    .replace(/\s+\([^)]*\)\s*$/, '')
    .trim();

  return normalized || undefined;
}

function normalizePreviewItem(item: JsonFeedItem): FeedPreviewItem | undefined {
  const excerptSource = item.content_text || item.content_html;
  const title = normalizePreviewText(item.title) || normalizePreviewText(excerptSource) || 'Untitled item';
  const excerpt = normalizePreviewExcerpt(excerptSource, title);

  return {
    title,
    excerpt,
    publishedLabel: formatPublishedDate(item.date_published),
    url: normalizePreviewUrl(item.url || item.external_url),
  };
}

function normalizePreviewExcerpt(value: string | undefined, title: string): string {
  const excerpt = normalizePreviewText(value);
  if (!excerpt || excerpt === title) return '';
  return truncateText(excerpt, 220);
}

function normalizePreviewUrl(value?: string): string | undefined {
  if (!value) return undefined;
  if (!/^https?:\/\//i.test(value)) return undefined;
  return value;
}

function formatPublishedDate(value?: string): string {
  if (!value) return '';

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '';

  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(parsed);
}

function truncateText(value: string, maxLength: number): string {
  if (value.length <= maxLength) return value;

  const clipped = value.slice(0, maxLength).trimEnd();
  const safeBoundary = clipped.lastIndexOf(' ');

  return `${(safeBoundary > maxLength * 0.6 ? clipped.slice(0, safeBoundary) : clipped).trimEnd()}...`;
}

function decodeHtmlEntities(value: string): string {
  if (typeof document === 'undefined') return value;

  const textarea = document.createElement('textarea');
  textarea.innerHTML = value;
  return textarea.value;
}
