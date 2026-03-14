import { useEffect, useRef, useState } from 'preact/hooks';
import { renderFeedByToken } from '../api/generated';
import { apiClient } from '../api/client';
import type { FeedRecord } from '../api/contracts';

interface ResultDisplayProps {
  result: FeedRecord;
  onClose: () => void;
  isAuthenticated?: boolean;
  username?: string;
  onLogout?: () => void;
  onRequestSignIn?: () => void;
}

export function ResultDisplay({
  result,
  onClose,
  isAuthenticated,
  username,
  onLogout,
  onRequestSignIn,
}: ResultDisplayProps) {
  const [copyNotice, setCopyNotice] = useState('');
  const [feedTitle, setFeedTitle] = useState('');
  const [feedItems, setFeedItems] = useState<string[]>([]);
  const [isLoadingPreview, setIsLoadingPreview] = useState(Boolean(isAuthenticated));
  const copyResetRef = useRef<number | undefined>(undefined);

  const fullUrl = result.public_url.startsWith('http')
    ? result.public_url
    : `${window.location.origin}${result.public_url}`;
  const feedProtocolUrl = `feed:${fullUrl}`;

  useEffect(() => {
    const resultElement = document.getElementById('result-display');
    resultElement?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, []);

  useEffect(() => {
    return () => {
      if (copyResetRef.current) window.clearTimeout(copyResetRef.current);
    };
  }, []);

  useEffect(() => {
    if (!isAuthenticated) {
      setFeedTitle('');
      setFeedItems([]);
      setIsLoadingPreview(false);
      return;
    }

    const controller = new AbortController();

    const loadPreview = async () => {
      try {
        if (!result.feed_token) throw new Error('Missing feed token');
        setIsLoadingPreview(true);

        const content = await renderFeedByToken({
          client: apiClient,
          path: { token: result.feed_token },
          parseAs: 'text',
          signal: controller.signal,
          responseStyle: 'data',
        });
        if (typeof content !== 'string') throw new Error('Invalid feed preview response');

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
        setIsLoadingPreview(false);
      }
    };

    loadPreview();
    return () => controller.abort();
  }, [isAuthenticated, result.feed_token]);

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

  const shouldShowPreview =
    Boolean(isAuthenticated) && (isLoadingPreview || Boolean(feedTitle) || feedItems.length > 0);

  return (
    <section id="result-display" class="result-shell" aria-live="polite">
      <div class="surface surface--result">
        <div class="surface__header surface__header--row">
          <div>
            <p class="eyebrow">result</p>
            <h2>Feed created</h2>
          </div>
          <div class="surface__toolbar">
            {isAuthenticated && username && <span class="surface__operator">operator:{username}</span>}
            <button type="button" class="btn btn--ghost" onClick={onClose}>
              Convert another website
            </button>
            {isAuthenticated && onLogout && (
              <button type="button" class="btn btn--secondary" onClick={onLogout}>
                Log out
              </button>
            )}
          </div>
        </div>

        <div class="result-grid">
          <section class="surface__section surface__section--strong">
            <p class="result-name">{result.name}</p>
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
                Copy URL
              </button>
              {isAuthenticated && (
                <a href={feedProtocolUrl} class="btn btn--secondary" target="_blank" rel="noopener">
                  Subscribe in reader
                </a>
              )}
            </div>
            {isAuthenticated && <p class="field-help">Opens your default RSS reader if configured.</p>}
            {copyNotice && (
              <div class="notice notice--success" role="status">
                <p>{copyNotice}</p>
              </div>
            )}
            {!isAuthenticated && onRequestSignIn && (
              <div class="result-guest-row">
                <span class="muted-copy">Sign in to convert another URL.</span>
                <button type="button" class="btn btn--ghost" onClick={onRequestSignIn}>
                  Sign in
                </button>
              </div>
            )}
          </section>

          {shouldShowPreview && (
            <aside class="surface__section feed-preview" aria-label="Feed preview">
              <div class="feed-preview__header">
                <p class="eyebrow">preview</p>
                <h3>{feedTitle || 'Fetching feed items'}</h3>
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
                  The feed endpoint is live. Preview items are not available for this response.
                </p>
              )}
            </aside>
          )}
        </div>
      </div>
    </section>
  );
}
