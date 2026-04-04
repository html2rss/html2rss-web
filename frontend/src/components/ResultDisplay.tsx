import { useEffect, useRef, useState } from 'preact/hooks';
import type { CreatedFeedResult } from '../api/contracts';
import { DominantField } from './DominantField';

interface ResultDisplayProperties {
  result: CreatedFeedResult;
  onCreateAnother: () => void;
  onRetryReadiness: () => void;
}

export function ResultDisplay({ result, onCreateAnother, onRetryReadiness }: ResultDisplayProperties) {
  const [copyNotice, setCopyNotice] = useState('');
  const [showAllPreviewItems, setShowAllPreviewItems] = useState(false);
  const copyResetReference = useRef<number | undefined>(undefined);
  const { feed, preview, readinessPhase } = result;

  const fullUrl = feed.public_url.startsWith('http')
    ? feed.public_url
    : `${globalThis.location.origin}${feed.public_url}`;
  const jsonFeedUrl = feed.json_public_url.startsWith('http')
    ? feed.json_public_url
    : `${globalThis.location.origin}${feed.json_public_url}`;
  const subscribeUrl = /^https?:\/\//i.test(fullUrl) ? `feed:${fullUrl}` : undefined;
  const isFeedReady = readinessPhase === 'feed_ready';
  const canManuallyRetryReadiness =
    readinessPhase === 'feed_not_ready_yet' || readinessPhase === 'preview_unavailable';
  const isReadinessCheckInProgress = readinessPhase === 'link_created' && preview.isLoading;
  const showReadinessAction = canManuallyRetryReadiness || isReadinessCheckInProgress;
  const previewItems = showAllPreviewItems ? preview.items : preview.items.slice(0, 3);
  const hasMorePreviewItems = preview.items.length > 3;
  const statusTitle = {
    link_created: 'Feed created',
    feed_ready: 'Feed ready',
    feed_not_ready_yet: 'Feed still warming up',
    preview_unavailable: 'Readiness check unavailable',
  }[readinessPhase];
  const statusMessage = {
    link_created: 'Checking readiness now.',
    feed_ready: 'This feed has been verified and is ready to use.',
    feed_not_ready_yet: 'The feed endpoint is still warming up. Try checking again in a few seconds.',
    preview_unavailable: 'We could not verify readiness right now. Try checking again.',
  }[readinessPhase];

  useEffect(() => {
    return () => {
      if (copyResetReference.current) globalThis.clearTimeout(copyResetReference.current);
    };
  }, []);

  useEffect(() => {
    setShowAllPreviewItems(false);
  }, [feed.feed_token]);

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopyNotice('Feed URL copied to clipboard.');
      if (copyResetReference.current) globalThis.clearTimeout(copyResetReference.current);
      copyResetReference.current = globalThis.setTimeout(() => setCopyNotice(''), 2500);
    } catch {
      setCopyNotice('Clipboard copy failed. Copy the feed URL manually.');
    }
  };

  return (
    <section class="result-shell layout-stack" aria-live="polite">
      <header
        class="result-hero ui-card ui-card--roomy ui-hero layout-rail-reading layout-stack"
        style={{ '--stack-gap': 'var(--space-3)' }}
      >
        <div class="result-hero__masthead ui-hero__masthead">
          <div class="result-hero__icon-wrap ui-hero__icon-wrap" aria-hidden="true">
            <img class="result-hero__icon ui-hero__icon" src="/feed.svg" alt="" />
          </div>
          <div class="layout-stack layout-stack--tight">
            <h1 class="result-title ui-display-title">{statusTitle}</h1>
            <p class="result-meta layout-rail-copy">{feed.name}</p>
            <p class="field-help">{statusMessage}</p>
          </div>
        </div>
        <div class="result-hero__actions ui-hero__actions">
          {showReadinessAction && (
            <button
              type="button"
              class="btn btn--primary"
              onClick={onRetryReadiness}
              disabled={isReadinessCheckInProgress}
              aria-busy={isReadinessCheckInProgress}
            >
              {isReadinessCheckInProgress ? 'Checking readiness…' : 'Try readiness check again'}
            </button>
          )}
        </div>
        {result.retry && (
          <p class="field-help">
            {`Retried automatically with ${result.retry.to} after ${result.retry.from} could not finish the page.`}
          </p>
        )}
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
        {isFeedReady && (
          <>
            <a href={fullUrl} class="btn btn--ghost" target="_blank" rel="noopener noreferrer">
              Open feed
            </a>
            <a href={jsonFeedUrl} class="btn btn--ghost" target="_blank" rel="noopener noreferrer">
              Open JSON Feed
            </a>
            {subscribeUrl && (
              <a href={subscribeUrl} class="btn btn--ghost result-hero__reader">
                Open in feed reader
              </a>
            )}
          </>
        )}
        <button type="button" class="btn btn--quiet btn--linkish" onClick={onCreateAnother}>
          Create another feed
        </button>
      </div>

      {preview.isLoading && (
        <section class="result-preview layout-rail-reading layout-stack" aria-label="Feed preview status">
          <div class="result-preview__header layout-stack layout-stack--tight">
            <p class="result-preview__label ui-eyebrow">Preview</p>
            <p class="result-preview__intro">Latest items from this feed</p>
          </div>
          <p class="field-help">Verifying feed readiness…</p>
        </section>
      )}

      {isFeedReady && preview.items.length > 0 && (
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
          {hasMorePreviewItems && (
            <button
              type="button"
              class="btn btn--quiet btn--linkish"
              onClick={() => setShowAllPreviewItems((current) => !current)}
            >
              {showAllPreviewItems ? 'Show fewer items' : `Show all ${preview.items.length} items`}
            </button>
          )}
        </section>
      )}

      {isFeedReady && !preview.isLoading && preview.items.length === 0 && !preview.error && (
        <section class="result-preview layout-rail-reading layout-stack" aria-label="Feed preview status">
          <div class="result-preview__header layout-stack layout-stack--tight">
            <p class="result-preview__label ui-eyebrow">Preview</p>
            <p class="result-preview__intro">Latest items from this feed</p>
          </div>
          <p class="field-help">
            Feed is ready. Preview items will appear once the source publishes entries.
          </p>
        </section>
      )}

      {!preview.isLoading && preview.error && (
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
