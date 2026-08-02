import { describe, expect, it } from 'vitest';
import {
  buildLocalError,
  normalizeFeedCreationError,
  normalizeFeedCreationErrorFromResponse,
} from '../feeds/feedCreationError';

describe('feedCreationError', () => {
  it('normalizes structured response envelopes without parsing message text', () => {
    const error = normalizeFeedCreationErrorFromResponse(401, {
      kind: 'auth',
      code: 'UNAUTHORIZED',
      retryable: false,
      next_action: 'enter_token',
      retry_action: 'none',
      message: 'Authentication required',
    });

    expect(error).toMatchObject({
      kind: 'auth',
      code: 'UNAUTHORIZED',
      retryable: false,
      nextAction: 'enter_token',
      retryAction: 'none',
      message: 'Authentication required',
      status: 401,
    });
  });

  it('derives fallbacks from HTTP status when envelope fields are missing', () => {
    const error = normalizeFeedCreationErrorFromResponse(503, undefined);

    expect(error).toMatchObject({
      kind: 'network',
      code: 'TRANSIENT_ERROR',
      retryable: true,
      nextAction: 'retry',
      retryAction: 'primary',
      status: 503,
    });
  });

  it('maps extraction-empty envelopes to corrective input errors', () => {
    const error = normalizeFeedCreationErrorFromResponse(422, {
      kind: 'input',
      code: 'NO_FEED_ITEMS_EXTRACTED',
      retryable: false,
      next_action: 'correct_input',
      retry_action: 'none',
      message: 'Could not extract feed items.',
    });

    expect(error).toMatchObject({
      kind: 'input',
      code: 'NO_FEED_ITEMS_EXTRACTED',
      nextAction: 'correct_input',
      retryAction: 'none',
      retryable: false,
    });
  });

  it('passes through FeedCreationError instances and wraps unknown errors', () => {
    const local = buildLocalError('Invalid URL format.', 'input', 'correct_input');
    expect(normalizeFeedCreationError(local)).toBe(local);

    expect(normalizeFeedCreationError(new Error('offline'))).toMatchObject({
      kind: 'network',
      code: 'NETWORK_ERROR',
      message: 'offline',
      nextAction: 'retry',
    });

    expect(normalizeFeedCreationError('boom')).toMatchObject({
      kind: 'server',
      code: 'UNKNOWN_ERROR',
    });
  });
});
