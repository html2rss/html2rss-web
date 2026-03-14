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

  return (
    <section id="feed-result" class="surface surface--primary surface--result" aria-live="polite">
      <div class="surface__header">
        <p class="eyebrow">Feed ready</p>
        <h2>{displayTitle}</h2>
        <p class="muted-copy">
          Copy the generated feed URL immediately, or open the endpoint to inspect the rendered output.
        </p>
      </div>

      <div class="result-layout">
        <section class="surface__section surface__section--strong">
          <label class="field-block" htmlFor="feed-url">
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
            <button type="button" class="btn btn--ghost" onClick={onCreateAnother}>
              Create another feed
            </button>
          </div>

          {copyNotice && (
            <div class="notice notice--success" role="status">
              <p>{copyNotice}</p>
            </div>
          )}
        </section>

        <aside class="surface__section feed-preview" aria-label="Feed preview">
          <div class="feed-preview__header">
            <p class="eyebrow">Preview</p>
            <h3>{feedTitle || 'Previewing feed items'}</h3>
          </div>
          {isLoadingPreview ? (
            <div class="preview-loading">
              <span class="status-card__spinner" aria-hidden="true" />
              <p>Loading recent entries</p>
            </div>
          ) : feedItems.length > 0 ? (
            <ol class="feed-preview__list">
              {feedItems.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ol>
          ) : (
            <p class="muted-copy">
              The feed endpoint is live. Preview items were not available for this response.
            </p>
          )}
        </aside>
      </div>
    </section>
  );
}
