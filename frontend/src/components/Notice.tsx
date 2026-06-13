import type { ComponentChildren, JSX } from 'preact';

interface NoticeProperties {
  title?: string;
  children: ComponentChildren;
  tone?: 'error' | 'success' | 'neutral';
  state?: 'loading';
  actions?: ComponentChildren;
  role?: JSX.HTMLAttributes<HTMLDivElement>['role'];
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
      <div class="notice__content">
        {title && <div class="notice__title">{title}</div>}
        {children}
      </div>
      {actions && <div class="notice__actions">{actions}</div>}
    </div>
  );
}
