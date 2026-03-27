import { useState } from 'preact/hooks';
import { createFeed } from '../api/generated';
import { apiClient } from '../api/client';
import type { CreatedFeedResult, FeedPreviewItem, FeedRecord } from '../api/contracts';

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

export function useFeedConversion() {
  const [state, setState] = useState<ConversionState>({
    isConverting: false,
    result: null,
    error: null,
  });

  const convertFeed = async (url: string, strategy: string, token: string) => {
    if (!url?.trim()) throw new Error('URL is required');
    if (!strategy?.trim()) throw new Error('Strategy is required');

    try {
      new URL(url.trim());
    } catch {
      throw new Error('Invalid URL format');
    }

    setState((prev) => ({ ...prev, isConverting: true, error: null }));

    try {
      const response = await createFeed({
        client: apiClient,
        headers: {
          Authorization: `Bearer ${token}`,
        },
        body: {
          url: url.trim(),
          strategy: strategy.trim(),
        },
        throwOnError: true,
      });

      if (!response.data?.success || !response.data.data?.feed) {
        throw new Error('Invalid response format');
      }

      const feed = response.data.data.feed;
      const preview = await loadPreview(feed).catch((error: unknown) => ({
        items: [],
        error: toPreviewErrorMessage(error),
      }));
      const result = { feed, preview };

      setState((prev) => ({ ...prev, isConverting: false, result, error: null }));
      return result;
    } catch (error) {
      const message = toErrorMessage(error);
      setState((prev) => ({
        ...prev,
        isConverting: false,
        error: message,
        result: null,
      }));
      throw new Error(message);
    }
  };

  const clearResult = () => {
    window.document.body.scrollIntoView({ behavior: 'smooth', block: 'start' });

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
  };
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
