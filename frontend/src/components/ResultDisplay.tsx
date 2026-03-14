import { useState, useEffect } from 'preact/hooks';
import { renderFeedByToken } from '../api/generated';
import { apiClient } from '../api/client';
import type { FeedRecord } from '../api/contracts';
import styles from './ResultDisplay.module.css';

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
  const [isLoadingPreview, setIsLoadingPreview] = useState(true);

  const fullUrl = result.public_url.startsWith('http')
    ? result.public_url
    : `${window.location.origin}${result.public_url}`;
  const feedProtocolUrl = `feed:${fullUrl}`;

  useEffect(() => {
    const resultElement = document.getElementById('result-display');
    if (resultElement) {
      resultElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, []);

  useEffect(() => {
    const controller = new AbortController();

    const loadPreview = async () => {
      try {
        const token = extractFeedToken(result.public_url);
        if (!token) throw new Error('Missing feed token');

        const content = await renderFeedByToken({
          client: apiClient,
          path: { token },
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

    return () => {
      controller.abort();
    };
  }, [result.public_url]);

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopyNotice('Copied to clipboard.');
      window.setTimeout(() => setCopyNotice(''), 3000);
    } catch {
      setCopyNotice('Clipboard copy failed. Please copy the URL manually.');
    }
  };

  const shouldShowPreview = isLoadingPreview || Boolean(feedTitle) || feedItems.length > 0;

  return (
    <section id="result-display" class={styles.result} aria-live="polite">
      <div class="panel-meta">
        <span class="panel-meta__primary">{isAuthenticated ? (username ?? '') : ''}</span>
        <span class="panel-meta__actions">
          <button
            type="button"
            class="btn btn--link btn--meta"
            onClick={onClose}
            aria-label="Convert another website"
          >
            ← Convert another website
          </button>
          {isAuthenticated && onLogout && (
            <button type="button" class="btn btn--link btn--meta" onClick={onLogout}>
              Log out
            </button>
          )}
        </span>
      </div>

      <header class={styles.hero}>
        <h2 class={styles.heroTitle}>Feed created</h2>
        <p class={styles.heroName}>{result.name}</p>
      </header>

      <div class={styles.feedCard}>
        <input
          id="feed-url"
          name="feed-url"
          type="text"
          value={fullUrl}
          readOnly
          aria-label="Feed URL"
          class="input"
        />
      </div>

      <div class={styles.heroActions}>
        <button type="button" class="btn btn--accent" onClick={() => copyToClipboard(fullUrl)}>
          <span>Copy URL</span>
        </button>
        <a href={feedProtocolUrl} class="btn btn--ghost" target="_blank" rel="noopener">
          <span>Subscribe in reader</span>
        </a>
      </div>
      <p class={styles.actionHint}>Opens your default RSS reader if configured.</p>

      {!isAuthenticated && onRequestSignIn && (
        <p class={styles.guestCue}>
          Have credentials?{' '}
          <button type="button" class="btn btn--link btn--meta" onClick={onRequestSignIn}>
            Sign in
          </button>
        </p>
      )}

      {copyNotice && (
        <div class="notice" role="status">
          <p>{copyNotice}</p>
        </div>
      )}

      {shouldShowPreview && (
        <section class={styles.preview} aria-label="Feed item preview">
          {isLoadingPreview ? (
            <p class={styles.previewLoading}>Loading preview...</p>
          ) : (
            <>
              {feedTitle && <p class={styles.previewTitle}>{feedTitle}</p>}
              {feedItems.length > 0 && (
                <ul class={styles.previewList}>
                  {feedItems.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              )}
            </>
          )}
        </section>
      )}
    </section>
  );
}

const extractFeedToken = (publicUrl: string): string | null => {
  const path = publicUrl.startsWith('http')
    ? new URL(publicUrl).pathname
    : publicUrl;
  const segments = path.split('/').filter(Boolean);
  const feedIndex = segments.findIndex((segment) => segment === 'feeds');
  if (feedIndex < 0) return null;

  return segments[feedIndex + 1] ?? null;
};
