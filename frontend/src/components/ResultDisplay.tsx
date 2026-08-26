import type { ComponentChildren } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';
import type { AppViewModel } from '../feed';
import { COPY } from '../journey/copy';
import { DominantField } from './DominantField';

interface ResultDisplayProperties {
  viewModel: Extract<AppViewModel, { kind: 'result' }>;
  onCreateAnother: () => void;
  onRetryPreview: () => void;
}

interface PreviewSectionProperties {
  ariaLabel: string;
  eyebrow?: string;
  children: ComponentChildren;
}

function PreviewSection({ ariaLabel, eyebrow, children }: PreviewSectionProperties) {
  return (
    <section class="layout-rail-reading layout-stack layout-section-divided" aria-label={ariaLabel}>
      {eyebrow && <p class="ui-eyebrow">{eyebrow}</p>}
      {children}
    </section>
  );
}

export function ResultDisplay({ viewModel, onCreateAnother, onRetryPreview }: ResultDisplayProperties) {
  const [copied, setCopied] = useState(false);
  const copyResetReference = useRef<ReturnType<typeof globalThis.setTimeout> | undefined>(undefined);
  const copyButtonReference = useRef<HTMLButtonElement>(null);
  const { feed, preview, warnings } = viewModel;

  const fullUrl = feed.public_url.startsWith('http')
    ? feed.public_url
    : `${location.origin}${feed.public_url}`;
  const jsonFeedUrl = feed.json_public_url.startsWith('http')
    ? feed.json_public_url
    : `${location.origin}${feed.json_public_url}`;
  const subscribeUrl = /^https?:\/\//i.test(fullUrl) ? `feed:${fullUrl}` : undefined;
  const canManuallyRetryPreview =
    preview.status === 'preview_failed' && warnings.some((warning) => warning.retryable);
  const previewMessage = warnings[0]?.message ?? '';
  const hasPreviewItems = preview.items.length > 0;
  const isShowPreviewError =
    preview.status === 'preview_failed' && !preview.isLoading && !hasPreviewItems && !!previewMessage;

  useEffect(() => {
    copyButtonReference.current?.focus();
    return () => {
      if (copyResetReference.current) clearTimeout(copyResetReference.current);
    };
  }, []);

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      if (copyResetReference.current) clearTimeout(copyResetReference.current);
      copyResetReference.current = setTimeout(() => setCopied(false), 2500);
    } catch {
      // Clipboard may be unavailable in restricted contexts.
    }
  };

  return (
    <section class="result-shell layout-stack" aria-live="polite" data-state={viewModel.kind}>
      <header class="result-header layout-rail-reading layout-stack layout-stack--tight">
        <p class="ui-eyebrow">{COPY.feedReady}</p>
        <h1 class="result-title ui-display-title">{feed.name}</h1>
      </header>

      <DominantField
        className="layout-rail-reading"
        id="feed-url"
        label={COPY.feedUrl}
        value={fullUrl}
        readOnly
        actionRef={copyButtonReference}
        actionLabel={COPY.copyFeedUrl}
        actionText={copied ? COPY.copied : COPY.copy}
        actionVariant={copied ? 'soft' : 'default'}
        onAction={() => void copyToClipboard(fullUrl)}
      />

      <div class="ui-actions layout-rail-reading">
        <a href={fullUrl} class="btn btn--ghost" target="_blank" rel="noopener noreferrer">
          {COPY.openFeed}
        </a>
        <a href={jsonFeedUrl} class="btn btn--ghost" target="_blank" rel="noopener noreferrer">
          {COPY.openJsonFeed}
        </a>
        {subscribeUrl && (
          <a href={subscribeUrl} class="btn btn--ghost">
            {COPY.openInFeedReader}
          </a>
        )}
        <button type="button" class="btn btn--quiet btn--linkish" onClick={onCreateAnother}>
          {COPY.createAnother}
        </button>
      </div>

      {preview.isLoading && (
        <PreviewSection ariaLabel={COPY.previewStatus}>
          <div class="preview-feedback preview-feedback--loading">
            <span class="preview-feedback__spinner" aria-hidden="true" />
            <span>{COPY.previewChecking}</span>
          </div>
        </PreviewSection>
      )}

      {!preview.isLoading && hasPreviewItems && (
        <PreviewSection ariaLabel={COPY.previewRegion} eyebrow={COPY.previewItemCount(preview.items.length)}>
          <ul class="ui-item-list" role="list">
            {preview.items.map((item) => (
              <li key={`${item.title}-${item.publishedLabel || 'undated'}`} class="ui-item">
                {item.publishedLabel && (
                  <div class="ui-item__meta">
                    <span>{item.publishedLabel}</span>
                  </div>
                )}
                <h2 class="ui-item__title">
                  {item.url ? (
                    <a href={item.url} target="_blank" rel="noopener noreferrer">
                      {item.title}
                    </a>
                  ) : (
                    item.title
                  )}
                </h2>
                {item.title && item.excerpt && <p class="ui-item__excerpt">{item.excerpt}</p>}
              </li>
            ))}
          </ul>
        </PreviewSection>
      )}

      {isShowPreviewError && (
        <PreviewSection ariaLabel={COPY.previewStatus}>
          <div class="preview-feedback preview-feedback--error">
            <span>{previewMessage}</span>
            {canManuallyRetryPreview && (
              <button type="button" class="btn btn--quiet btn--linkish" onClick={onRetryPreview}>
                {COPY.checkAgain}
              </button>
            )}
          </div>
        </PreviewSection>
      )}
    </section>
  );
}
