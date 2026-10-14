import type { ComponentChildren } from 'preact';

interface PreviewFeedbackProperties {
  readonly tone: 'loading' | 'error';
  readonly children: ComponentChildren;
  readonly onRetry?: () => void;
  readonly retryLabel?: string;
}

/** Shared loading / error / retry chrome for preview and suggestion surfaces. */
export function PreviewFeedback({ tone, children, onRetry, retryLabel }: PreviewFeedbackProperties) {
  if (tone === 'loading') {
    return (
      <div class="preview-feedback preview-feedback--loading">
        <span class="preview-feedback__spinner" aria-hidden="true" />
        <span>{children}</span>
      </div>
    );
  }

  return (
    <div class="preview-feedback preview-feedback--error">
      <span>{children}</span>
      {onRetry && retryLabel ? (
        <button type="button" class="btn btn--quiet btn--linkish" onClick={onRetry}>
          {retryLabel}
        </button>
      ) : undefined}
    </div>
  );
}
