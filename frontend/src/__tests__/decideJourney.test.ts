import { describe, expect, it } from 'vitest';
import { decideJourney } from '../feed/decideJourney';

const emptyErrors = { url: '', form: '' };

const readyFeed = {
  id: 'feed-1',
  name: 'Example',
  url: 'https://example.com',
  feed_token: 'token',
  public_url: '/feed',
  json_public_url: '/feed.json',
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-01-01T00:00:00Z',
};

describe('decideJourney', () => {
  it('keeps create idle when there is no creation failure', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isCreating: false,
        route: { kind: 'create' },
        tokenError: '',
      })
    ).toEqual({ kind: 'create' });
  });

  it('projects a ready result when tokens match', () => {
    const viewModel = decideJourney({
      feedFieldErrors: emptyErrors,
      isCreating: false,
      route: { kind: 'result', feedToken: 'token' },
      tokenError: '',
      result: {
        feed: readyFeed,
        preview: { status: 'preview_ready', items: [], isLoading: false },
        warnings: [],
      },
    });

    expect(viewModel).toMatchObject({
      kind: 'result',
      phase: 'ready',
      preview: { status: 'preview_ready' },
    });
  });

  it('keeps the ready panel when the in-memory token leads the hash', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isCreating: false,
        route: { kind: 'result', feedToken: 'route-token' },
        tokenError: '',
        result: {
          feed: { ...readyFeed, feed_token: 'other-token' },
          preview: { status: 'preview_ready', items: [], isLoading: false },
          warnings: [],
        },
      })
    ).toMatchObject({ kind: 'result', phase: 'ready', feed: { feed_token: 'other-token' } });

    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isCreating: false,
        route: { kind: 'result', feedToken: 'route-token' },
        tokenError: '',
      })
    ).toEqual({ kind: 'create' });
  });

  it('projects unresolved workspace on #/result without a feed token', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isCreating: false,
        route: { kind: 'result' },
        tokenError: '',
        unresolved: {
          url: 'https://example.com/articles',
          notice: 'We could not extract feed items from this page yet.',
        },
      })
    ).toEqual({
      kind: 'result',
      phase: 'unresolved',
      url: 'https://example.com/articles',
      notice: 'We could not extract feed items from this page yet.',
    });
  });

  it('does not recover empty extraction onto result without unresolved memory', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isCreating: false,
        route: { kind: 'result' },
        tokenError: '',
        creationError: {
          kind: 'input',
          code: 'EXTRACTION_EMPTY',
          retryable: false,
          nextAction: 'correct_input',
          retryAction: 'none',
          message: 'Empty.',
        },
      })
    ).toEqual({ kind: 'create' });
  });

  it('keeps EXTRACTION_EMPTY as a create error when unresolved is absent', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isCreating: false,
        route: { kind: 'create' },
        tokenError: '',
        creationError: {
          kind: 'input',
          code: 'EXTRACTION_EMPTY',
          retryable: false,
          nextAction: 'correct_input',
          retryAction: 'none',
          message: 'Empty.',
        },
      })
    ).toMatchObject({ kind: 'error', message: 'Empty.', errorKind: 'input' });
  });

  it('maps submitting and corrective input failures', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isCreating: true,
        route: { kind: 'create' },
        tokenError: '',
      })
    ).toEqual({ kind: 'submitting' });

    expect(
      decideJourney({
        feedFieldErrors: { url: '', form: 'Bad url' },
        isCreating: false,
        route: { kind: 'create' },
        tokenError: '',
        creationError: {
          kind: 'input',
          code: 'INVALID_INPUT',
          retryable: false,
          nextAction: 'correct_input',
          retryAction: 'none',
          message: 'Bad url',
        },
      })
    ).toMatchObject({ kind: 'error', message: 'Bad url', errorKind: 'input' });
  });

  it('keeps token_prompt while creating on the token route', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isCreating: true,
        route: { kind: 'token' },
        tokenError: '',
      })
    ).toEqual({ kind: 'token_prompt', tokenError: '' });
  });
});
