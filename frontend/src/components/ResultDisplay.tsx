import { useEffect, useRef, useState } from 'preact/hooks';
import type { FeedRecord } from '../api/contracts';

interface ResultDisplayProps {
  result: FeedRecord;
  onCreateAnother: () => void;
}

export function ResultDisplay({ result, onCreateAnother }: ResultDisplayProps) {
  const [copyNotice, setCopyNotice] = useState('');
  const [feedTitle, setFeedTitle] = useState('');
  const [feedItems, setFeedItems] = useState<string[]>([]);
  const [isLoadingPreview, setIsLoadingPreview] = useState(true);
  const copyResetRef = useRef<number | undefined>(undefined);

  const fullUrl = result.public_url.startsWith('http')
    ? result.public_url
    : `${window.location.origin}${result.public_url}`;

  useEffect(() => {
    const resultElement = document.getElementById('feed-result');
    resultElement?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, []);

  useEffect(() => {
    return () => {
      if (copyResetRef.current) window.clearTimeout(copyResetRef.current);
    };
  }, []);

  useEffect(() => {
    const controller = new AbortController();

    const loadPreview = async () => {
      try {
        setIsLoadingPreview(true);

        const response = await fetch(fullUrl, { signal: controller.signal });
        const content = await response.text();

        const xmlDoc = new DOMParser().parseFromString(content, 'text/xml');
        const parsedTitle =
          xmlDoc.querySelector('channel > title')?.textContent?.trim() ||
          xmlDoc.querySelector('feed > title')?.textContent?.trim() ||
          '';
        const rssItems = Array.from(xmlDoc.querySelectorAll('item > title'));
        const atomItems = Array.from(xmlDoc.querySelectorAll('entry > title'));
        const parsedItems = (rssItems.length > 0 ? rssItems : atomItems)
          .map((item) => item.textContent?.trim() ?? '')
          .filter((item) => item.length > 0)
          .slice(0, 7);

        setFeedTitle(parsedTitle);
        setFeedItems(parsedItems);
      } catch {
        setFeedTitle('');
        setFeedItems([]);
      } finally {
        if (!controller.signal.aborted) setIsLoadingPreview(false);
      }
    };

    loadPreview();
    return () => controller.abort();
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

  const displayTitle = feedTitle || result.name;
  const previewItems = feedItems.slice(0, 4);

  return (
    <section id="feed-result" class="surface surface--primary surface--result" aria-live="polite">
      <div class="surface__header">
        <p class="eyebrow">Result</p>
        <h2>{displayTitle}</h2>
        <p class="muted-copy">Your feed URL is ready to copy into a reader or automation.</p>
      </div>

      <div class="result-layout">
        <section class="surface__section surface__section--strong result-primary">
          <div class="result-summary">
            <p class="result-kicker">Primary action</p>
            <p class="result-summary__copy">
              Copy the feed URL, then drop it into the reader or workflow you use.
            </p>
          </div>

          <label class="field-block result-url" htmlFor="feed-url">
            <span class="field-label">Feed URL</span>
            <input
              id="feed-url"
              name="feed-url"
              type="text"
              value={fullUrl}
              readOnly
              class="input input--mono"
            />
          </label>

          <div class="result-actions">
            <button type="button" class="btn btn--primary" onClick={() => copyToClipboard(fullUrl)}>
              Copy feed URL
            </button>
            <a href={fullUrl} class="btn btn--secondary" target="_blank" rel="noopener noreferrer">
              Open feed
            </a>
          </div>

          {copyNotice && (
            <div class="notice notice--success" role="status">
              <p>{copyNotice}</p>
            </div>
          )}

          <div class="result-secondary">
            <p class="muted-copy">Need another one from a different page?</p>
            <button type="button" class="btn btn--ghost" onClick={onCreateAnother}>
              Create another feed
            </button>
          </div>
        </section>

        <aside class="surface__section surface__section--quiet feed-preview" aria-label="Feed preview">
          <div class="feed-preview__header">
            <p class="eyebrow">Quick check</p>
            <h3>Preview</h3>
          </div>
          {isLoadingPreview ? (
            <div class="preview-loading">
              <span class="status-card__spinner" aria-hidden="true" />
              <p>Loading sample entries</p>
            </div>
          ) : previewItems.length > 0 ? (
            <ol class="feed-preview__list">
              {previewItems.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ol>
          ) : (
            <p class="muted-copy">The feed is live even though preview entries were not available here.</p>
          )}
        </aside>
      </div>
    </section>
  );
}
