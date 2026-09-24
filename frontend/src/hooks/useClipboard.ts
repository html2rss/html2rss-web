import { useEffect, useRef, useState } from 'preact/hooks';

/** Closed clipboard UI feedback. Failure is non-destructive: content is unchanged. */
export type ClipboardFeedback = 'idle' | 'copied' | 'failed';

const RESET_MS = 2500;

/**
 * Shared clipboard copy with owned idle/copied/failed feedback and auto-reset.
 * Used by feed URL and YAML copy actions.
 */
export function useClipboard() {
  const [feedback, setFeedback] = useState<ClipboardFeedback>('idle');
  const resetReference = useRef<ReturnType<typeof globalThis.setTimeout> | undefined>(undefined);

  useEffect(() => {
    return () => {
      if (resetReference.current) clearTimeout(resetReference.current);
    };
  }, []);

  async function copy(text: string): Promise<void> {
    try {
      await navigator.clipboard.writeText(text);
      setFeedback('copied');
    } catch {
      setFeedback('failed');
    }
    if (resetReference.current) clearTimeout(resetReference.current);
    resetReference.current = setTimeout(() => setFeedback('idle'), RESET_MS);
  }

  return { feedback, copy } as const;
}
