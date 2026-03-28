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
  result: CreatedFeedResult | null;
  error: string | null;
}

interface ConversionError extends Error {
  manualRetryStrategy?: string;
  autoRetryAttempted?: boolean;
}

export function useFeedConversion() {
  const requestIdRef = useRef(0);
  const [state, setState] = useState<ConversionState>({
    isConverting: false,
    result: null,
    error: null,
  });

  const convertFeed = async (url: string, strategy: string, token: string) => {
    const normalizedUrl = normalizeUserUrl(url);
    const requestedStrategy = strategy.trim();
    const fallbackStrategy = requestedStrategy === 'faraday' ? 'browserless' : null;

    if (!normalizedUrl) throw new Error('URL is required');
    if (!requestedStrategy) throw new Error('Strategy is required');

    if (!isValidHttpUrl(normalizedUrl)) {
      throw new Error('Invalid URL format');
    }

    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;
    setState((prev) => ({ ...prev, isConverting: true, error: null }));

    try {
      const feed = await requestFeedCreation(normalizedUrl, requestedStrategy, token);
      const result = {
        feed,
        preview: buildLoadingPreviewState(),
        retry: null,
      };

      setState((prev) => ({ ...prev, isConverting: false, result, error: null }));
      void hydratePreview(feed, requestId, null, setState, requestIdRef);
      return result;
    } catch (firstError) {
      if (shouldAutoRetry(requestedStrategy, fallbackStrategy, firstError)) {
        try {
          const feed = await requestFeedCreation(normalizedUrl, fallbackStrategy, token);
          const result = {
            feed,
            preview: buildLoadingPreviewState(),
            retry: { automatic: true, from: requestedStrategy, to: fallbackStrategy },
          };

          setState((prev) => ({ ...prev, isConverting: false, result, error: null }));
          void hydratePreview(feed, requestId, result.retry, setState, requestIdRef);
          return result;
        } catch (secondError) {
          const message = buildRetryFailureMessage(
            firstError,
            secondError,
            requestedStrategy,
            fallbackStrategy
          );
          const retryError = buildConversionError(message, {
            manualRetryStrategy: undefined,
            autoRetryAttempted: true,
          });

          setState((prev) => ({
            ...prev,
            isConverting: false,
            error: message,
            result: null,
          }));
          throw retryError;
        }
      }

      const message = toErrorMessage(firstError);
      const retryError = buildConversionError(message, {
        manualRetryStrategy: alternateStrategy(requestedStrategy),
      });

      setState((prev) => ({
        ...prev,
        isConverting: false,
        error: message,
        result: null,
      }));
      throw retryError;
    }
  };

  const clearResult = () => {
    window.document.body.scrollIntoView({ behavior: 'smooth', block: 'start' });
    requestIdRef.current += 1;

    setState({
      isConverting: false,
      result: null,
      error: null,
    });
  };

  const clearError = () => {
    setState((prev) => ({ ...prev, error: null }));
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
  const response = await window.fetch(feed.json_public_url, {
    headers: { Accept: 'application/feed+json' },
  });

  if (!response.ok) throw new Error('Preview unavailable right now.');

  const payload = (await response.json()) as JsonFeedResponse;
  const items =
    payload.items
      ?.map((item) => normalizePreviewItem(item))
      .filter((item): item is FeedPreviewItem => Boolean(item))
      .slice(0, 5) || [];

  return {
    items,
    error: items.length > 0 ? null : 'Preview unavailable right now.',
    isLoading: false,
  };
}

function buildLoadingPreviewState(): CreatedFeedResult['preview'] {
  return {
    items: [],
    error: null,
    isLoading: true,
  };
}

async function hydratePreview(
  feed: FeedRecord,
  requestId: number,
  retry: CreatedFeedResult['retry'],
  setState: (value: ConversionState | ((prev: ConversionState) => ConversionState)) => void,
  requestIdRef: { current: number }
) {
  const preview = await loadPreview(feed).catch((error: unknown) => ({
    items: [],
    error: toPreviewErrorMessage(error),
    isLoading: false,
  }));

  if (requestIdRef.current !== requestId) return;

  setState((prev) => {
    if (
      requestIdRef.current !== requestId ||
      !prev.result ||
      prev.result.feed.feed_token !== feed.feed_token
    ) {
      return prev;
    }

    return {
      ...prev,
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
  fallbackStrategy: string | null,
  error: unknown
): fallbackStrategy is string {
  if (strategy !== 'faraday' || !fallbackStrategy) return false;

  const normalized = toErrorMessage(error).toLowerCase();
  return !(
    normalized.includes('unauthorized') ||
    normalized.includes('bad request') ||
    normalized.includes('forbidden') ||
    normalized.includes('access token') ||
    normalized.includes('authentication') ||
    normalized.includes('invalid response format') ||
    normalized.includes('network error') ||
    normalized.includes('url') ||
    normalized.includes('unsupported strategy')
  );
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
  if (error instanceof SyntaxError) return 'Invalid response format from feed creation API';
  if (error instanceof Error) return error.message;
  if (typeof error === 'string' && error.trim()) return error;

  const message = extractMessage(error);
  return message ?? 'An unexpected error occurred';
};

const toPreviewErrorMessage = (error: unknown): string => {
  if (error instanceof SyntaxError) return 'Preview unavailable right now.';
  if (error instanceof Error && error.message.trim()) return error.message;
  return 'Preview unavailable right now.';
};

const extractMessage = (error: unknown): string | null => {
  if (!error || typeof error !== 'object') return null;

  const candidate =
    (error as { error?: { message?: unknown }; message?: unknown }).error?.message ??
    (error as { message?: unknown }).message;

  return typeof candidate === 'string' && candidate.trim() ? candidate : null;
};

function normalizePreviewText(value?: string): string | null {
  if (!value) return null;

  const normalized = decodeHtmlEntities(value)
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/\s+([.,!?;:])/g, '$1')
    .replace(/^\d+\.\s+/, '')
    .replace(/\s+\([^)]*\)\s*$/, '')
    .trim();

  return normalized || null;
}

function normalizePreviewItem(item: JsonFeedItem): FeedPreviewItem | null {
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
