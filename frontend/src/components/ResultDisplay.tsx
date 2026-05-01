import type { ComponentChildren } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';
import type { CreatedFeedResult } from '../api/contracts';
import type { WorkflowState } from './AppPanels';
import { DominantField } from './DominantField';
import { ResultHero } from './ResultHero';

interface ResultDisplayProperties {
  result: CreatedFeedResult;
  workflowState: WorkflowState;
  onCreateAnother: () => void;
  onRetryPreview: () => void;
}

interface PreviewSectionProperties {
  ariaLabel: string;
  intro?: string;
  children: ComponentChildren;
}

function PreviewSection({ ariaLabel, intro, children }: PreviewSectionProperties) {
  return (
    <section class="result-preview layout-rail-reading layout-stack" aria-label={ariaLabel}>
      <div class="result-preview__header layout-stack layout-stack--tight">
        <p class="result-preview__label ui-eyebrow">Preview</p>
        {intro && <p class="result-preview__intro">{intro}</p>}
      </div>
      {children}
    </section>
  );
}

export function ResultDisplay({
  result,
  workflowState,
  onCreateAnother,
  onRetryPreview,
}: ResultDisplayProperties) {
  const [copyNotice, setCopyNotice] = useState('');
  const copyResetReference = useRef<ReturnType<typeof globalThis.setTimeout> | undefined>(undefined);
  const { feed, preview, workflowState: previewWorkflowState, warnings } = result;

  const fullUrl = feed.public_url.startsWith('http')
    ? feed.public_url
    : `${globalThis.location.origin}${feed.public_url}`;
  const jsonFeedUrl = feed.json_public_url.startsWith('http')
    ? feed.json_public_url
    : `${globalThis.location.origin}${feed.json_public_url}`;
  const subscribeUrl = /^https?:\/\//i.test(fullUrl) ? `feed:${fullUrl}` : undefined;
  const canUseFeed = previewWorkflowState !== 'preview_loading';
  const canManuallyRetryPreview =
    previewWorkflowState === 'preview_failed' && warnings.some((warning) => warning.retryable);
  const isPreviewCheckInProgress = preview.isLoading;
  const statusTitle = {
    created: 'Feed created',
    preview_loading: 'Checking preview',
    preview_ready: 'Feed ready',
    preview_failed: 'Feed link created',
  }[previewWorkflowState];
  const statusMessage = {
    created: 'Preparing preview.',
    preview_loading: 'Checking preview...',
    preview_ready: '',
    preview_failed: '',
  }[previewWorkflowState];
  const previewMessage = warnings[0]?.message ?? '';
  const hasPreviewItems = preview.items.length > 0;
  const showResultStatusNote =
    previewWorkflowState === 'preview_failed' && !preview.isLoading && !hasPreviewItems && !!previewMessage;
  const showPreviewStatusOnly =
    !showResultStatusNote &&
    !preview.isLoading &&
    !hasPreviewItems &&
    !!previewMessage &&
    previewWorkflowState === 'preview_failed';

  useEffect(() => {
    return () => {
      if (copyResetReference.current) globalThis.clearTimeout(copyResetReference.current);
    };
  }, []);

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
    <section class="result-shell layout-stack" aria-live="polite" data-state={workflowState}>
      <ResultHero
        title={statusTitle}
        body={
          <>
            <p class="result-meta layout-rail-copy">{feed.name}</p>
            {statusMessage && <p class="field-help">{statusMessage}</p>}
            {showResultStatusNote && (
              <p class="result-status-note field-help field-help--warning">{previewMessage}</p>
            )}
          </>
        }
        actions={
          canManuallyRetryPreview && (
            <button
              type="button"
              class="btn btn--primary"
              onClick={onRetryPreview}
              disabled={isPreviewCheckInProgress}
              aria-busy={isPreviewCheckInProgress}
            >
              {isPreviewCheckInProgress ? 'Checking...' : 'Check preview again'}
            </button>
          )
        }
      />

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
        {canUseFeed && (
          <>
            <a href={fullUrl} class="btn btn--primary" target="_blank" rel="noopener noreferrer">
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
        <PreviewSection ariaLabel="Feed preview status">
          <p class="field-help">{previewMessage}</p>
        </PreviewSection>
      )}

      {!preview.isLoading && hasPreviewItems && (
        <PreviewSection ariaLabel="Feed preview" intro="Latest items from this feed">
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
        </PreviewSection>
      )}

      {showPreviewStatusOnly && (
        <PreviewSection ariaLabel="Feed preview status">
          <p class="field-help field-help--warning">{previewMessage}</p>
        </PreviewSection>
      )}

      {copyNotice && (
        <div class="ui-card ui-card--notice ui-card--padded notice" data-tone="success" role="status">
          <p>{copyNotice}</p>
        </div>
      )}
    </section>
  );
}
