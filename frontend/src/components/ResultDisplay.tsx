import { useEffect, useRef, useState } from 'preact/hooks';
import type { FeedRecord } from '../api/contracts';

interface ResultDisplayProps {
  result: FeedRecord;
  onCreateAnother: () => void;
}

export function ResultDisplay({ result, onCreateAnother }: ResultDisplayProps) {
  const [copyNotice, setCopyNotice] = useState('');
  const copyResetRef = useRef<number | undefined>(undefined);

  const fullUrl = result.public_url.startsWith('http')
    ? result.public_url
    : `${window.location.origin}${result.public_url}`;

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
    <section class="result-shell" aria-live="polite">
      <div class="result-copy">
        <p class="result-title">Feed URL ready</p>
        <p class="result-meta">{result.name}</p>
      </div>

      <label class="field-block field-block--primary field-block--hero result-url" htmlFor="feed-url">
        <span class="field-label field-label--ghost">Feed URL</span>
        <input
          id="feed-url"
          name="feed-url"
          type="text"
          value={fullUrl}
          readOnly
          class="input input--mono input--hero"
        />
      </label>

      <div class="result-actions">
        <button type="button" class="btn btn--primary btn--hero" onClick={() => copyToClipboard(fullUrl)}>
          Copy feed URL
        </button>
        <a href={fullUrl} class="btn btn--ghost btn--linkish" target="_blank" rel="noopener noreferrer">
          Open feed
        </a>
      </div>

      {copyNotice && (
        <div class="notice notice--success" role="status">
          <p>{copyNotice}</p>
        </div>
      )}

      <button type="button" class="btn btn--quiet btn--linkish" onClick={onCreateAnother}>
        Create another feed
      </button>
    </section>
  );
}
