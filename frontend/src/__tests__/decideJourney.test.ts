import { describe, expect, it } from 'vitest';
import { decideJourney } from '../feed/decideJourney';

const emptyErrors = { url: '', form: '' };

describe('decideJourney', () => {
  it('keeps create idle when there is no conversion failure', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isConverting: false,
        route: { kind: 'create' },
        tokenError: '',
      })
    ).toEqual({ kind: 'create' });
  });

  it('nests preview under the result variant when tokens match', () => {
    const viewModel = decideJourney({
      feedFieldErrors: emptyErrors,
      isConverting: false,
      route: { kind: 'result', feedToken: 'token' },
      tokenError: '',
      result: {
        feed: {
          id: 'feed-1',
          name: 'Example',
          url: 'https://example.com',
          feed_token: 'token',
          public_url: '/feed',
          json_public_url: '/feed.json',
          created_at: '2024-01-01T00:00:00Z',
          updated_at: '2024-01-01T00:00:00Z',
        },
        preview: { status: 'preview_ready', items: [], isLoading: false },
        warnings: [],
      },
    });

    expect(viewModel).toMatchObject({
      kind: 'result',
      preview: { status: 'preview_ready' },
    });
  });

  it('does not treat a mismatched or missing result as the result kind', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isConverting: false,
        route: { kind: 'result', feedToken: 'route-token' },
        tokenError: '',
        result: {
          feed: {
            id: 'feed-1',
            name: 'Example',
            url: 'https://example.com',
            feed_token: 'other-token',
            public_url: '/feed',
            json_public_url: '/feed.json',
            created_at: '2024-01-01T00:00:00Z',
            updated_at: '2024-01-01T00:00:00Z',
          },
          preview: { status: 'preview_ready', items: [], isLoading: false },
          warnings: [],
        },
      })
    ).toEqual({ kind: 'create' });

    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isConverting: false,
        route: { kind: 'result', feedToken: 'route-token' },
        tokenError: '',
      })
    ).toEqual({ kind: 'create' });
  });

  it('maps submitting and corrective input failures', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isConverting: true,
        route: { kind: 'create' },
        tokenError: '',
      })
    ).toEqual({ kind: 'submitting' });

    expect(
      decideJourney({
        feedFieldErrors: { url: '', form: 'Bad url' },
        isConverting: false,
        route: { kind: 'create' },
        tokenError: '',
        conversionError: {
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

  it('keeps token_prompt while converting on the token route', () => {
    expect(
      decideJourney({
        feedFieldErrors: emptyErrors,
        isConverting: true,
        route: { kind: 'token' },
        tokenError: '',
      })
    ).toEqual({ kind: 'token_prompt', tokenError: '' });
  });
});
