import { useEffect, useRef, useState } from 'preact/hooks';
import type { CreatedFeedResult } from '../api/contracts';
import { DominantField } from './DominantField';

interface ResultDisplayProps {
  result: CreatedFeedResult;
  onCreateAnother: () => void;
}

export function ResultDisplay({ result, onCreateAnother }: ResultDisplayProps) {
  const [copyNotice, setCopyNotice] = useState('');
  const copyResetRef = useRef<number | undefined>(undefined);
  const { feed, preview } = result;

  const fullUrl = feed.public_url.startsWith('http')
    ? feed.public_url
    : `${window.location.origin}${feed.public_url}`;
  const jsonFeedUrl = feed.json_public_url.startsWith('http')
    ? feed.json_public_url
    : `${window.location.origin}${feed.json_public_url}`;

  useEffect(() => {
    return () => {
      if (copyResetRef.current) window.clearTimeout(copyResetRef.current);
    };
  }, []);

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
        <p class="result-meta layout-rail-copy">{feed.name}</p>
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

      {preview.items.length > 0 && (
        <section class="result-preview layout-rail-reading layout-stack" aria-label="Feed preview">
          <div class="result-preview__header layout-stack layout-stack--tight">
            <p class="result-preview__label ui-eyebrow">Preview</p>
            <p class="result-preview__intro">Latest items from this feed</p>
          </div>
          <ul class="result-preview__list" role="list">
            {preview.items.map((item) => (
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

      {preview.error && (
        <section class="result-preview layout-rail-reading layout-stack" aria-label="Feed preview status">
          <div class="result-preview__header layout-stack layout-stack--tight">
            <p class="result-preview__label ui-eyebrow">Preview</p>
            <p class="result-preview__intro">Latest items from this feed</p>
          </div>
          <p class="field-help">{preview.error}</p>
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
