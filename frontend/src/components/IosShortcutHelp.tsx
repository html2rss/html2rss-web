import { useRef, useState } from 'preact/hooks';
import { COPY } from '../journey/copy';
import { DominantField } from './DominantField';

/** Body for the iOS Shortcut utility-help Notice: setup steps + DominantField Copy. */
export function IosShortcutHelp({ createPrefillPrefix }: { createPrefillPrefix: string }) {
  const [copied, setCopied] = useState(false);
  const copyResetReference = useRef<ReturnType<typeof globalThis.setTimeout> | undefined>(undefined);

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
    <>
      <ol>
        <li>
          Add <strong>{COPY.iosShortcutActionShareSheet}</strong>
        </li>
        <li>
          Add <strong>{COPY.iosShortcutActionUrlEncode}</strong>
        </li>
        <li>
          Add <strong>{COPY.iosShortcutActionOpen}</strong>
          {' — '}
          <span>{COPY.iosShortcutOpenDetail}</span>
        </li>
      </ol>
      <DominantField
        className="notice__prefix-field"
        id="ios-shortcut-create-prefix"
        label={COPY.prefix}
        value={createPrefillPrefix}
        readOnly
        actionLabel={COPY.copyCreatePrefillPrefix}
        actionText={copied ? COPY.copied : COPY.copy}
        actionVariant={copied ? 'soft' : 'default'}
        onAction={() => void copyToClipboard(createPrefillPrefix)}
      />
      <p class="notice__meta">
        <a href="shortcuts://create-shortcut" class="notice__secondary-link">
          {COPY.iosShortcutOpenEditor}
        </a>
      </p>
    </>
  );
}
