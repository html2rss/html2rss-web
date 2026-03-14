import type { JSX, Ref } from 'preact';

interface DominantFieldProps {
  id: string;
  label: string;
  value: string;
  placeholder?: string;
  type?: string;
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
  id,
  label,
  value,
  placeholder,
  type = 'text',
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
}: DominantFieldProps) {
  return (
    <div class="dominant-field">
      <label class="field-block field-block--primary field-block--hero" htmlFor={id}>
        <span class="field-label field-label--ghost">{label}</span>
        <input
          id={id}
          name={id}
          type={type}
          class="input input--mono input--hero"
          placeholder={placeholder}
          autocomplete={type === 'url' ? 'url' : 'off'}
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
