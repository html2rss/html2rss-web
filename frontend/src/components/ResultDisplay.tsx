import type { ComponentChildren } from 'preact';
import { useEffect, useRef } from 'preact/hooks';
import type { FeedPreviewState, FeedPreviewWarning } from '../api/contracts';
import type { AppViewModel } from '../feed';
import { useClipboard } from '../hooks/useClipboard';
import { COPY } from '../journey/copy';
import { ConfigStudio, type AuthenticatedStudioCapability } from '../studio';
import { DominantField } from './DominantField';
import { Notice } from './Notice';
import { PreviewFeedback } from './PreviewFeedback';
import { PreviewItem } from './PreviewItem';

interface ResultDisplayProperties {
  viewModel: Extract<AppViewModel, { kind: 'result' }>;
  onCreateAnother: () => void;
  onRetryPreview: () => void;
  studio?: AuthenticatedStudioCapability;
}

export function ResultDisplay({
  viewModel,
  onCreateAnother,
  onRetryPreview,
  studio,
}: ResultDisplayProperties) {
  if (viewModel.phase === 'unresolved') {
    return (
      <UnresolvedResult
        url={viewModel.url}
        notice={viewModel.notice}
        studio={studio}
        onCreateAnother={onCreateAnother}
      />
    );
  }

  return (
    <ReadyResult
      viewModel={viewModel}
      onCreateAnother={onCreateAnother}
      onRetryPreview={onRetryPreview}
      studio={studio}
    />
  );
}

function UnresolvedResult({
  url,
  notice,
  studio,
  onCreateAnother,
}: {
  readonly url: string;
  readonly notice: string;
  readonly studio?: AuthenticatedStudioCapability;
  readonly onCreateAnother: () => void;
}) {
  return (
    <section class="result-shell layout-stack" aria-live="polite" data-state="unresolved">
      <header class="result-header layout-rail-reading layout-stack layout-stack--tight">
        <p class="ui-eyebrow">{COPY.urlLabel}</p>
        <h1 class="result-title ui-display-title input--mono">{url}</h1>
      </header>

      <div class="layout-rail-reading">
        <Notice tone="error">
          <p>{notice}</p>
        </Notice>
      </div>

      {studio ? (
        <ConfigStudio
          url={studio.url}
          token={studio.token}
          mode="unresolved"
          decisionNotice={notice}
          onGenerate={studio.onGenerate}
        />
      ) : undefined}

      <div class="ui-actions layout-rail-reading">
        <button type="button" class="btn btn--quiet btn--linkish" onClick={onCreateAnother}>
          {COPY.createAnother}
        </button>
      </div>
    </section>
  );
}

function ReadyResult({
  viewModel,
  onCreateAnother,
  onRetryPreview,
  studio,
}: {
  readonly viewModel: Extract<AppViewModel, { kind: 'result'; phase: 'ready' }>;
  readonly onCreateAnother: () => void;
  readonly onRetryPreview: () => void;
  readonly studio?: AuthenticatedStudioCapability;
}) {
  const { feedback, copy } = useClipboard();
  const copyButtonReference = useRef<HTMLButtonElement>(null);
  const { feed, preview, warnings } = viewModel;
  const meadow = <ResultMeadow preview={preview} warnings={warnings} onRetryPreview={onRetryPreview} />;
  const fullUrl = absoluteUrl(feed.public_url);
  const jsonFeedUrl = absoluteUrl(feed.json_public_url);
  const subscribeUrl = /^https?:\/\//i.test(fullUrl) ? `feed:${fullUrl}` : undefined;

  useEffect(() => {
    copyButtonReference.current?.focus();
  }, [feed.feed_token]);

  return (
    <section
      class="result-shell layout-stack"
      aria-live="polite"
      data-state="ready"
      data-clipboard={feedback}
    >
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
        actionText={feedback === 'copied' ? COPY.copied : COPY.copy}
        actionVariant={feedback === 'copied' ? 'soft' : 'default'}
        onAction={() => {
          void copy(fullUrl);
        }}
      />

      <div class="ui-actions layout-rail-reading">
        <a href={fullUrl} class="btn btn--ghost" target="_blank" rel="noopener noreferrer">
          {COPY.openFeed}
        </a>
        <a href={jsonFeedUrl} class="btn btn--ghost" target="_blank" rel="noopener noreferrer">
          {COPY.openJsonFeed}
        </a>
        {subscribeUrl ? (
          <a href={subscribeUrl} class="btn btn--ghost">
            {COPY.openInFeedReader}
          </a>
        ) : undefined}
        <button type="button" class="btn btn--quiet btn--linkish" onClick={onCreateAnother}>
          {COPY.createAnother}
        </button>
      </div>

      {studio ? (
        <ConfigStudio
          key={feed.feed_token}
          url={studio.url}
          token={studio.token}
          mode="ready"
          onGenerate={studio.onGenerate}
          fallback={meadow}
          directoryHandoff
        />
      ) : (
        meadow
      )}
    </section>
  );
}

function ResultMeadow({
  preview,
  warnings,
  onRetryPreview,
}: {
  readonly preview: FeedPreviewState;
  readonly warnings: readonly FeedPreviewWarning[];
  readonly onRetryPreview: () => void;
}) {
  const previewMessage = warnings[0]?.message ?? '';
  const hasPreviewItems = preview.items.length > 0;
  const isShowError =
    preview.status === 'preview_failed' && !preview.isLoading && !hasPreviewItems && !!previewMessage;
  const canRetry = isShowError && warnings.some((warning) => warning.retryable);

  let body: ComponentChildren;
  if (preview.isLoading) {
    body = <PreviewFeedback tone="loading">{COPY.previewChecking}</PreviewFeedback>;
  } else if (hasPreviewItems) {
    body = (
      <ul class="ui-item-list ui-item-list--grid" role="list">
        {preview.items.map((item) => (
          <li key={`${item.title}-${item.publishedLabel || 'undated'}`} class="ui-item">
            <PreviewItem
              title={item.title}
              excerpt={item.excerpt}
              url={item.url}
              publishedLabel={item.publishedLabel}
              imageUrl={item.imageUrl}
            />
          </li>
        ))}
      </ul>
    );
  } else if (isShowError) {
    body = (
      <PreviewFeedback
        tone="error"
        onRetry={canRetry ? onRetryPreview : undefined}
        retryLabel={canRetry ? COPY.checkAgain : undefined}
      >
        {previewMessage}
      </PreviewFeedback>
    );
  } else {
    return;
  }

  return (
    <section
      class="layout-rail-reading layout-stack layout-section-divided"
      aria-label={hasPreviewItems && !preview.isLoading ? COPY.previewRegion : COPY.previewStatus}
    >
      {hasPreviewItems && !preview.isLoading ? (
        <p class="ui-eyebrow">{COPY.previewItemCount(preview.items.length)}</p>
      ) : undefined}
      {body}
    </section>
  );
}

function absoluteUrl(path: string): string {
  return path.startsWith('http') ? path : `${location.origin}${path}`;
}
