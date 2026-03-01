import { useState, useEffect } from 'preact/hooks';
import styles from './ResultDisplay.module.css';

interface ConversionResult {
  id: string;
  name: string;
  url: string;
  username: string;
  strategy: string;
  public_url: string;
}

interface ResultDisplayProps {
  result: ConversionResult;
  onClose: () => void;
  isAuthenticated?: boolean;
  username?: string;
  onLogout?: () => void;
}

export function ResultDisplay({ result, onClose, isAuthenticated, username, onLogout }: ResultDisplayProps) {
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
        setIsLoadingPreview(false);
      }
    };

    loadPreview();

    return () => {
      controller.abort();
    };
  }, [fullUrl]);

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
    <section id="result-display" class={`surface ${styles.result}`} aria-live="polite">
      <div class="panel-meta">
        <span>{isAuthenticated ? (username ?? '') : ''}</span>
        {isAuthenticated && onLogout ? (
          <button type="button" class="btn btn--link btn--meta" onClick={onLogout}>
            Log out
          </button>
        ) : (
          <span />
        )}
      </div>

      <header class={styles.hero}>
        <h2 class={styles.heroTitle}>Feed created</h2>
      </header>

      <div class={styles.feedCard}>
        <input type="text" value={fullUrl} readOnly aria-label="Feed URL" class="input" />
      </div>

      <div class={styles.heroActions}>
        <button type="button" class="btn btn--accent" onClick={() => copyToClipboard(fullUrl)}>
          <span>Copy URL</span>
        </button>
        <a href={feedProtocolUrl} class="btn btn--ghost" target="_blank" rel="noopener">
          <span>Subscribe in reader</span>
        </a>
      </div>

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

      <div class={styles.footer}>
        <button type="button" class="btn btn--accent" onClick={onClose}>
          Convert another website
        </button>
      </div>
    </section>
  );
}
