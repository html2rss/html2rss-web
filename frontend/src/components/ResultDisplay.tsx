import { useEffect, useRef, useState } from 'preact/hooks';
import type { FeedRecord } from '../api/contracts';
import { DominantField } from './DominantField';

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
        const response = await window.fetch(fullUrl);
        const xml = await response.text();
        const document = new DOMParser().parseFromString(xml, 'application/xml');
        const explicitTitles = Array.from(document.querySelectorAll('item > title, entry > title')).map(
          (node) => node.textContent?.trim()
        );
        const derivedDescriptions = Array.from(document.querySelectorAll('item > description'))
          .map((node) => node.textContent?.trim())
          .filter((description): description is string => Boolean(description))
          .filter((description) => /^\d+\.\s+/.test(description))
          .map((description) =>
            description
              .replace(/^\d+\.\s+/, '')
              .replace(/\s+\([^)]*\)\s*$/, '')
              .trim()
          );
        const itemTitles = [...explicitTitles, ...derivedDescriptions]
          .filter((title): title is string => Boolean(title))
          .slice(0, 3);

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
        onAction={() => void copyToClipboard(fullUrl)}
      />

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

      <div class="result-actions result-actions--quiet">
        <a href={fullUrl} class="btn btn--ghost btn--linkish" target="_blank" rel="noopener noreferrer">
          Open feed
        </a>
        <button type="button" class="btn btn--quiet btn--linkish" onClick={onCreateAnother}>
          Create another feed
        </button>
      </div>

      {copyNotice && (
        <div class="notice notice--success" role="status">
          <p>{copyNotice}</p>
        </div>
      )}
    </section>
  );
}
