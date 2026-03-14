import { useEffect, useRef, useState } from 'preact/hooks';
import type { FeedRecord } from '../api/contracts';
import { DominantField } from './DominantField';

interface JsonFeedItem {
  title?: string;
  content_text?: string;
}

interface JsonFeedResponse {
  items?: JsonFeedItem[];
}

interface ResultDisplayProps {
  result: FeedRecord;
  onCreateAnother: () => void;
}

export function ResultDisplay({ result, onCreateAnother }: ResultDisplayProps) {
  const [copyNotice, setCopyNotice] = useState('');
  const [previewItems, setPreviewItems] = useState<string[]>([]);
  const copyResetRef = useRef<number | undefined>(undefined);

  const fullUrl = result.public_url.startsWith('http')
    ? result.public_url
    : `${window.location.origin}${result.public_url}`;

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
        const itemTitles =
          payload.items
            ?.map((item) => normalizePreviewText(item.title || item.content_text))
            .filter((title): title is string => Boolean(title))
            .slice(0, 3) || [];

        if (!isCancelled) setPreviewItems(itemTitles);
      } catch {
        if (!isCancelled) setPreviewItems([]);
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
    <section class="result-shell" aria-live="polite">
      <div class="result-copy">
        <p class="result-meta">{result.name}</p>
      </div>

      <DominantField
        id="feed-url"
        label="Feed URL"
        value={fullUrl}
        readOnly
        actionLabel="Copy feed URL"
        actionText="Copy"
        actionVariant="soft"
        onAction={() => void copyToClipboard(fullUrl)}
      />

      <div class="result-actions result-actions--quiet">
        <a href={fullUrl} class="btn btn--ghost btn--linkish" target="_blank" rel="noopener noreferrer">
          Open feed
        </a>
        <button type="button" class="btn btn--quiet btn--linkish" onClick={onCreateAnother}>
          Create another feed
        </button>
      </div>

      {previewItems.length > 0 && (
        <section class="result-preview" aria-label="Feed preview">
          <p class="result-preview__label">Latest items</p>
          <ul class="result-preview__list">
            {previewItems.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </section>
      )}

      {copyNotice && (
        <div class="notice notice--success" role="status">
          <p>{copyNotice}</p>
        </div>
      )}
    </section>
  );
}

function normalizePreviewText(value?: string): string | null {
  if (!value) return null;

  const normalized = value
    .replace(/\s+/g, ' ')
    .replace(/^\d+\.\s+/, '')
    .replace(/\s+\([^)]*\)\s*$/, '')
    .trim();

  return normalized || null;
}
