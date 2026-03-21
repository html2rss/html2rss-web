import { useEffect, useRef, useState } from 'preact/hooks';
import type { FeedRecord } from '../api/contracts';
import { DominantField } from './DominantField';

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

interface PreviewItem {
  title: string;
  excerpt: string;
  publishedLabel: string;
  url?: string;
}

interface ResultDisplayProps {
  result: FeedRecord;
  onCreateAnother: () => void;
}

export function ResultDisplay({ result, onCreateAnother }: ResultDisplayProps) {
  const [copyNotice, setCopyNotice] = useState('');
  const [previewItems, setPreviewItems] = useState<PreviewItem[]>([]);
  const [previewError, setPreviewError] = useState('');
  const copyResetRef = useRef<number | undefined>(undefined);

  const fullUrl = result.public_url.startsWith('http')
    ? result.public_url
    : `${window.location.origin}${result.public_url}`;
  const jsonFeedUrl = result.json_public_url.startsWith('http')
    ? result.json_public_url
    : `${window.location.origin}${result.json_public_url}`;

  useEffect(() => {
    return () => {
      if (copyResetRef.current) window.clearTimeout(copyResetRef.current);
    };
  }, []);

  useEffect(() => {
    let isCancelled = false;

    const loadPreview = async () => {
      try {
        const response = await window.fetch(fullUrl, {
          headers: { Accept: 'application/feed+json' },
        });
        if (!response.ok) throw new Error('Preview request failed');
        const payload = (await response.json()) as JsonFeedResponse;
        const items =
          payload.items
            ?.map((item) => normalizePreviewItem(item))
            .filter((item): item is PreviewItem => Boolean(item))
            .slice(0, 5) || [];

        if (!isCancelled) {
          setPreviewItems(items);
          setPreviewError('');
        }
      } catch {
        if (!isCancelled) {
          setPreviewItems([]);
          setPreviewError('Preview unavailable right now.');
        }
      }
    };

    void loadPreview();

    return () => {
      isCancelled = true;
    };
  }, [fullUrl]);

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopyNotice('Feed URL copied to clipboard.');
      if (copyResetRef.current) window.clearTimeout(copyResetRef.current);
      copyResetRef.current = window.setTimeout(() => setCopyNotice(''), 2500);
    } catch {
      setCopyNotice('Clipboard copy failed. Copy the feed URL manually.');
    }
  };

  return (
    <section class="result-shell layout-stack" aria-live="polite">
      <header
        class="result-hero layout-rail-reading layout-stack"
        style={{ '--stack-gap': 'var(--space-3)' }}
      >
        <p class="result-kicker ui-eyebrow">Feed created</p>
        <h1 class="result-title">Your feed is ready</h1>
        <p class="result-meta layout-rail-copy">{result.name}</p>
        <p class="result-lede layout-rail-copy">Subscribe to this URL in your RSS reader.</p>
      </header>

      <DominantField
        className="layout-rail-reading"
        id="feed-url"
        label="Feed URL"
        value={fullUrl}
        readOnly
        actionLabel="Copy feed URL"
        actionText="Copy"
        actionVariant="soft"
        onAction={() => void copyToClipboard(fullUrl)}
      />

      <div class="result-actions result-actions--quiet layout-rail-reading">
        <a href={fullUrl} class="btn btn--ghost" target="_blank" rel="noopener noreferrer">
          Open feed
        </a>
        <a href={jsonFeedUrl} class="btn btn--ghost" target="_blank" rel="noopener noreferrer">
          Open JSON Feed
        </a>
        <button type="button" class="btn btn--quiet btn--linkish" onClick={onCreateAnother}>
          Create another feed
        </button>
      </div>

      {previewItems.length > 0 && (
        <section class="result-preview layout-rail-reading layout-stack" aria-label="Feed preview">
          <div class="result-preview__header layout-stack layout-stack--tight">
            <p class="result-preview__label ui-eyebrow">Preview</p>
            <p class="result-preview__intro">Latest items from this feed</p>
          </div>
          <ul class="result-preview__list" role="list">
            {previewItems.map((item) => (
              <li key={`${item.title}-${item.publishedLabel || 'undated'}`}>
                <article class="preview-card ui-card layout-stack layout-stack--tight">
                  <h2 class="preview-card__title">{item.title}</h2>
                  {item.publishedLabel && <p class="preview-card__date">{item.publishedLabel}</p>}
                  {item.excerpt && <p class="preview-card__excerpt">{item.excerpt}</p>}
                  {item.url && (
                    <p class="preview-card__actions">
                      <a href={item.url} target="_blank" rel="noopener noreferrer">
                        Open original
                      </a>
                    </p>
                  )}
                </article>
              </li>
            ))}
          </ul>
        </section>
      )}

      {previewError && (
        <section class="result-preview layout-rail-reading layout-stack" aria-label="Feed preview status">
          <div class="result-preview__header layout-stack layout-stack--tight">
            <p class="result-preview__label ui-eyebrow">Preview</p>
            <p class="result-preview__intro">Latest items from this feed</p>
          </div>
          <p class="field-help">{previewError}</p>
        </section>
      )}

      {copyNotice && (
        <div class="ui-card ui-card--notice ui-card--padded notice" data-tone="success" role="status">
          <p>{copyNotice}</p>
        </div>
      )}
    </section>
  );
}

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

function normalizePreviewItem(item: JsonFeedItem): PreviewItem | null {
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
