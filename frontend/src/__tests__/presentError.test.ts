import { describe, expect, it } from 'vitest';
import { COPY } from '../journey/copy';
import { presentErrorMessage } from '../journey/presentError';

describe('presentErrorMessage', () => {
  it('returns COPY for known classified codes', () => {
    expect(presentErrorMessage('BLOCKED_SURFACE', 'wire')).toBe(COPY.previewBlockedSurface);
    expect(presentErrorMessage('SCRAPER_UNAVAILABLE', 'wire')).toBe(COPY.previewScraperUnavailable);
  });

  it('returns the fallback for unknown or missing codes', () => {
    expect(presentErrorMessage('EXTRACTION_EMPTY', 'Check the URL.')).toBe('Check the URL.');
    expect(presentErrorMessage(undefined, 'Unable to complete feed creation.')).toBe(
      'Unable to complete feed creation.'
    );
  });
});
