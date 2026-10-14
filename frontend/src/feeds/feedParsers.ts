import type { FeedPreviewItem, PreviewAudience } from '../api/contracts';

// Member cap matches Html2rss::Web::Api::V1::PreviewSamples::SAMPLE_LIMIT.
const PREVIEW_ITEM_LIMIT: Record<PreviewAudience, number> = {
  guest: 5,
  member: 10,
};

export function previewAudienceForToken(token: string): PreviewAudience {
  return token.trim() ? 'member' : 'guest';
}

export function normalizeString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

// eslint-disable-next-line unicorn/consistent-boolean-name
export function normalizeBoolean(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

export function normalizePreviewItems(
  items: unknown[] | undefined,
  audience: PreviewAudience = 'guest'
): FeedPreviewItem[] {
  if (!Array.isArray(items)) return [];

  return items
    .map((item) => normalizePreviewItem(item, audience))
    .filter((item): item is FeedPreviewItem => item !== undefined)
    .slice(0, PREVIEW_ITEM_LIMIT[audience]);
}

export function normalizePreviewItem(
  value: unknown,
  audience: PreviewAudience = 'guest'
): FeedPreviewItem | undefined {
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
    image?: unknown;
  };

  const title = normalizeString(candidate.title);
  if (!title) return undefined;

  const url = normalizeString(candidate.url);
  const imageUrl = audience === 'member' ? safePreviewImageUrl(candidate.image) : undefined;

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
    ...(imageUrl && { imageUrl }),
  };
}

function safePreviewImageUrl(value: unknown): string | undefined {
  if (typeof value !== 'string') return;
  const url = value.trim();
  if (!url.startsWith('https://') && !url.startsWith('http://')) return;
  if (/[\s"'<>]/.test(url)) return;
  return url;
}
