import { describe, expect, it } from 'vitest';
import { decideJourney } from '../feed/decideJourney';
import { getPanelViewState } from '../appViewModel';

const emptyErrors = { url: '', form: '' };

describe('decideJourney', () => {
  it('returns create by default', () => {
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

describe('getPanelViewState', () => {
  it('derives values for create state', () => {
    const state = getPanelViewState({ kind: 'create' }, emptyErrors);
    expect(state).toEqual({
      isTokenPrompt: false,
      isConverting: false,
      tokenError: '',
      errorKind: undefined,
      failureMessage: '',
      isShowRetryButton: false,
    });
  });

  it('derives values for submitting state', () => {
    const state = getPanelViewState({ kind: 'submitting' }, emptyErrors);
    expect(state).toEqual({
      isTokenPrompt: false,
      isConverting: true,
      tokenError: '',
      errorKind: undefined,
      failureMessage: '',
      isShowRetryButton: false,
    });
  });

  it('derives values for token_prompt state', () => {
    const state = getPanelViewState(
      {
        kind: 'token_prompt',
        tokenError: 'Invalid token',
        error: {
          kind: 'auth',
          code: 'UNAUTHORIZED',
          retryable: false,
          nextAction: 'enter_token',
          retryAction: 'none',
          message: 'Access denied',
        },
      },
      emptyErrors
    );
    expect(state).toEqual({
      isTokenPrompt: true,
      isConverting: false,
      tokenError: 'Invalid token',
      errorKind: 'auth',
      failureMessage: '',
      isShowRetryButton: false,
    });
  });

  it('derives values for error state', () => {
    const state = getPanelViewState(
      {
        kind: 'error',
        message: 'Something went wrong',
        errorKind: 'network',
        error: {
          kind: 'network',
          code: 'TIMEOUT',
          retryable: true,
          nextAction: 'retry',
          retryAction: 'recreate',
          message: 'Something went wrong',
        },
      },
      emptyErrors
    );
    expect(state).toEqual({
      isTokenPrompt: false,
      isConverting: false,
      tokenError: '',
      errorKind: 'network',
      failureMessage: 'Something went wrong',
      isShowRetryButton: true,
    });
  });
});
