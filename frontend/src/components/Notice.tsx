import type { ComponentChildren, JSX, Ref } from 'preact';
import { COPY } from '../journey/copy';

interface NoticeProperties {
  title?: string;
  children?: ComponentChildren;
  tone?: 'error' | 'success' | 'neutral';
  state?: 'loading';
  actions?: ComponentChildren;
  onDismiss?: () => void;
  dismissRef?: Ref<HTMLButtonElement>;
  role?: JSX.IntrinsicElements['div']['role'];
  className?: string;
  ariaLabel?: string;
  ariaLive?: 'polite' | 'assertive' | 'off';
}

export function Notice({
  title,
  children,
  tone,
  state,
  actions,
  onDismiss,
  dismissRef,
  role,
  className = '',
  ariaLabel,
  ariaLive,
}: NoticeProperties) {
  const isError = tone === 'error';
  const isLoading = state === 'loading';

  let assignedRole = role;
  if (assignedRole === undefined) {
    if (isError) {
      assignedRole = 'alert';
    } else if (isLoading) {
      assignedRole = 'status';
    }
  }

  const hasHeader = Boolean(title || onDismiss);

  return (
    <div
      class={`ui-card ui-card--notice ui-card--padded notice ${className}`}
      data-tone={tone}
      data-state={state}
      role={assignedRole}
      aria-label={ariaLabel}
      aria-live={ariaLive}
    >
      {isLoading && <div class="notice__spinner" aria-hidden="true" />}
      {hasHeader && (
        <div class="notice__header">
          {title ? <div class="notice__title">{title}</div> : <span class="notice__title-spacer" />}
          {onDismiss && (
            <button
              ref={dismissRef}
              type="button"
              class="notice__dismiss"
              aria-label={COPY.close}
              onClick={onDismiss}
            >
              <span aria-hidden="true">×</span>
            </button>
          )}
        </div>
      )}
      <div class="notice__content">{children}</div>
      {actions && <div class="notice__actions">{actions}</div>}
    </div>
  );
}
