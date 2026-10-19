import type { JSX, Ref } from 'preact';

type InputProperties = JSX.IntrinsicElements['input'];

interface DominantFieldProperties {
  className?: string;
  id: string;
  label: string;
  value: string;
  placeholder?: string;
  type?: 'text' | 'url';
  inputMode?: InputProperties['inputMode'];
  autoCapitalize?: InputProperties['autoCapitalize'];
  spellcheck?: boolean;
  readOnly?: boolean;
  autoFocus?: boolean;
  disabled?: boolean;
  actionLabel: string;
  actionText: string;
  actionVariant?: 'default' | 'soft';
  onAction?: () => void;
  onInput?: InputProperties['onInput'];
  onKeyDown?: InputProperties['onKeyDown'];
  inputRef?: Ref<HTMLInputElement>;
  actionRef?: Ref<HTMLButtonElement>;
  error?: string;
  'aria-controls'?: string;
  'aria-expanded'?: boolean | 'true' | 'false';
  'aria-activedescendant'?: string;
}

const ArrowIcon = () => (
  <svg
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    aria-hidden="true"
  >
    <path
      d="M6 12L10 8L6 4"
      stroke="currentColor"
      strokeWidth="2.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export function DominantField({
  className,
  id,
  label,
  value,
  placeholder,
  type = 'text',
  inputMode,
  autoCapitalize,
  spellcheck,
  readOnly = false,
  autoFocus = false,
  disabled = false,
  actionLabel,
  actionText,
  actionVariant = 'default',
  onAction,
  onInput,
  onKeyDown,
  inputRef,
  actionRef,
  error,
  'aria-controls': ariaControls,
  'aria-expanded': ariaExpanded,
  'aria-activedescendant': ariaActivedescendant,
}: DominantFieldProperties) {
  const handleKeyDown: NonNullable<InputProperties['onKeyDown']> = (event) => {
    onKeyDown?.(event);
    if (event.defaultPrevented) return;
    if (onAction || event.key !== 'Enter' || event.isComposing || event.repeat) return;

    event.preventDefault();
    event.currentTarget.form?.requestSubmit();
  };
  const inputProperties = {
    id,
    name: id,
    class: 'input input--mono input--lg',
    placeholder,
    inputMode,
    autoCapitalize,
    spellcheck,
    autoFocus,
    ref: inputRef,
    value,
    readOnly,
    disabled,
    'aria-controls': ariaControls,
    'aria-expanded': ariaExpanded,
    'aria-activedescendant': ariaActivedescendant,
    onInput,
    onKeyDown: handleKeyDown,
  };

  return (
    <div class={className ? `dominant-field ${className}` : 'dominant-field'}>
      <label class="field-block field-block--centered" htmlFor={id}>
        <span class="ui-eyebrow ui-eyebrow--ghost">{label}</span>
        {type === 'url' ? (
          <input type="url" autoComplete="url" {...inputProperties} />
        ) : (
          <input type="text" autoComplete="off" {...inputProperties} />
        )}
        {error ? <span class="field-error">{error}</span> : undefined}
      </label>
      <button
        type={onAction ? 'button' : 'submit'}
        class={`dominant-field__action${actionText.length > 1 ? ' dominant-field__action--text' : ''}${
          actionVariant === 'soft' ? ' dominant-field__action--soft' : ''
        }`}
        disabled={disabled}
        aria-label={actionLabel}
        onClick={onAction}
        ref={actionRef}
      >
        {actionText === '>' ? <ArrowIcon /> : actionText}
      </button>
    </div>
  );
}
