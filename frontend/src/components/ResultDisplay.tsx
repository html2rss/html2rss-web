import type { ComponentChildren } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';
import type { CreatedFeedResult } from '../api/contracts';
import type { WorkflowState } from './AppPanels';
import { DominantField } from './DominantField';

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
  const [copied, setCopied] = useState(false);
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
  const statusTitle = {
    created: 'Feed created',
    preview_loading: 'Checking preview',
    preview_ready: 'Feed ready',
    preview_failed: 'Feed link created',
  }[previewWorkflowState];
  const previewMessage = warnings[0]?.message ?? '';
  const hasPreviewItems = preview.items.length > 0;
  const showPreviewError =
    previewWorkflowState === 'preview_failed' && !preview.isLoading && !hasPreviewItems && !!previewMessage;

  useEffect(() => {
    return () => {
      if (copyResetReference.current) globalThis.clearTimeout(copyResetReference.current);
    };
  }, []);

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      if (copyResetReference.current) globalThis.clearTimeout(copyResetReference.current);
      copyResetReference.current = globalThis.setTimeout(() => setCopied(false), 2500);
    } catch {
      // Fallback
    }
  };

  return (
    <section class="result-shell layout-stack" aria-live="polite" data-state={workflowState}>
      <header class="result-header layout-rail-reading layout-stack layout-stack--tight">
        <p class="ui-eyebrow">{statusTitle}</p>
        <h1 class="result-title ui-display-title">{feed.name}</h1>
      </header>

      <DominantField
        className="layout-rail-reading"
        id="feed-url"
        label="Feed URL"
        value={fullUrl}
        readOnly
        actionLabel="Copy feed URL"
        actionText={copied ? 'Copied!' : 'Copy'}
        actionVariant={copied ? 'default' : 'soft'}
        onAction={() => void copyToClipboard(fullUrl)}
      />

      <div class="result-actions layout-rail-reading">
        {canUseFeed && (
          <>
            <a href={fullUrl} class="btn btn--primary" target="_blank" rel="noopener noreferrer">
              Open feed
            </a>
            <a href={jsonFeedUrl} class="btn btn--ghost" target="_blank" rel="noopener noreferrer">
              Open JSON Feed
            </a>
            {subscribeUrl && (
              <a href={subscribeUrl} class="btn btn--ghost">
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
          <div class="preview-feedback preview-feedback--loading">
            <span class="preview-feedback__spinner" aria-hidden="true" />
            <span>Checking preview...</span>
          </div>
        </PreviewSection>
      )}

      {!preview.isLoading && hasPreviewItems && (
        <PreviewSection ariaLabel="Feed preview" intro="Latest items from this feed">
          <ul class="result-preview__list editorial-list" role="list">
            {preview.items.map((item) => (
              <li key={`${item.title}-${item.publishedLabel || 'undated'}`} class="preview-item">
                <article class="layout-stack layout-stack--tight">
                  <div class="preview-item__metadata">
                    {item.publishedLabel && <span class="preview-item__date">{item.publishedLabel}</span>}
                  </div>
                  <h2 class="preview-item__title">{item.title}</h2>
                  {item.excerpt && <p class="preview-item__excerpt">{item.excerpt}</p>}
                  {item.url && (
                    <p class="preview-item__actions">
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

      {showPreviewError && (
        <PreviewSection ariaLabel="Feed preview status">
          <div class="preview-feedback preview-feedback--error">
            <span>{previewMessage}</span>
            {canManuallyRetryPreview && (
              <button
                type="button"
                class="btn btn--quiet btn--linkish"
                style="margin-left: var(--space-2); display: inline-flex;"
                onClick={onRetryPreview}
              >
                Check again
              </button>
            )}
          </div>
        </PreviewSection>
      )}
    </section>
  );
}
