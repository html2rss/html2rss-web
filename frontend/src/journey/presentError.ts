import { COPY } from './copy';

const TAILORED_ERROR_MESSAGES = {
  BLOCKED_SURFACE: COPY.previewBlockedSurface,
  SCRAPER_UNAVAILABLE: COPY.previewScraperUnavailable,
} as const;

export type TailoredErrorCode = keyof typeof TAILORED_ERROR_MESSAGES;

/**
 * Maps a classified error code to the single human sentence for that code.
 * Unknown codes keep the provided fallback (wire or local message).
 */
export function presentErrorMessage(code: string | undefined, fallback: string): string {
  if (code && isTailoredErrorCode(code)) return TAILORED_ERROR_MESSAGES[code];
  return fallback;
}

function isTailoredErrorCode(code: string): code is TailoredErrorCode {
  return Object.hasOwn(TAILORED_ERROR_MESSAGES, code);
}
