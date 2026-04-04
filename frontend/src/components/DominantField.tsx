import type { JSX, Ref } from 'preact';

interface DominantFieldProperties {
  className?: string;
  id: string;
  label: string;
  value: string;
  placeholder?: string;
  type?: string;
  inputMode?: JSX.HTMLAttributes<HTMLInputElement>['inputMode'];
  autoCapitalize?: JSX.HTMLAttributes<HTMLInputElement>['autoCapitalize'];
  spellcheck?: boolean;
  readOnly?: boolean;
  autoFocus?: boolean;
  disabled?: boolean;
  actionLabel: string;
  actionText: string;
  actionVariant?: 'default' | 'soft';
  onAction?: () => void;
  onInput?: JSX.GenericEventHandler<HTMLInputElement>;
  inputRef?: Ref<HTMLInputElement>;
  error?: string;
}

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
  inputRef,
  error,
}: DominantFieldProperties) {
  return (
    <div class={className ? `dominant-field ${className}` : 'dominant-field'}>
      <label class="field-block field-block--centered" htmlFor={id}>
        <span class="field-label field-label--ghost">{label}</span>
        <input
          id={id}
          name={id}
          type={type}
          class="input input--mono input--lg"
          placeholder={placeholder}
          autoComplete={type === 'url' ? 'url' : 'off'}
          inputMode={inputMode}
          autoCapitalize={autoCapitalize}
          spellcheck={spellcheck}
          autoFocus={autoFocus}
          ref={inputRef}
          value={value}
          readOnly={readOnly}
          disabled={disabled}
          onInput={onInput}
        />
        <span class="field-error">{error ?? ''}</span>
      </label>
      <button
        type={onAction ? 'button' : 'submit'}
        class={`dominant-field__action${actionText.length > 1 ? ' dominant-field__action--text' : ''}${
          actionVariant === 'soft' ? ' dominant-field__action--soft' : ''
        }`}
        disabled={disabled}
        aria-label={actionLabel}
        onClick={onAction}
      >
        {actionText}
      </button>
    </div>
  );
}
