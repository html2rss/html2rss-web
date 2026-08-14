import type { FeedPreviewItem } from '../api/contracts';

export function normalizeString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

// eslint-disable-next-line unicorn/consistent-boolean-name
export function normalizeBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

export function normalizePreviewItems(items: unknown[] | undefined): FeedPreviewItem[] {
  if (!Array.isArray(items)) return [];

  return items
    .map((item) => normalizePreviewItem(item))
    .filter((item): item is FeedPreviewItem => item !== undefined)
    .slice(0, 5);
}

export function normalizePreviewItem(value: unknown): FeedPreviewItem | undefined {
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
