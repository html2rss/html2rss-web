import { describe, expect, it } from 'vitest';
import { deriveAppViewModel } from '../appViewModel';

const emptyErrors = { url: '', form: '' };

describe('deriveAppViewModel', () => {
  it('returns create by default', () => {
    expect(
      deriveAppViewModel({
        feedFieldErrors: emptyErrors,
        isConverting: false,
        routeKind: 'create',
        tokenError: '',
      })
    ).toEqual({ kind: 'create' });
  });

  it('nests preview under the result variant', () => {
    const viewModel = deriveAppViewModel({
      feedFieldErrors: emptyErrors,
      isConverting: false,
      routeKind: 'result',
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

  it('maps auth conversion failures to token_prompt', () => {
    expect(
      deriveAppViewModel({
        feedFieldErrors: emptyErrors,
        isConverting: false,
        routeKind: 'create',
        tokenError: '',
        conversionError: {
          kind: 'auth',
          code: 'UNAUTHORIZED',
          retryable: false,
          nextAction: 'enter_token',
          retryAction: 'none',
          message: 'Access denied',
        },
      })
    ).toMatchObject({
      kind: 'token_prompt',
      error: { code: 'UNAUTHORIZED' },
    });
  });

  it('maps submitting and corrective input failures', () => {
    expect(
      deriveAppViewModel({
        feedFieldErrors: emptyErrors,
        isConverting: true,
        routeKind: 'create',
        tokenError: '',
      })
    ).toEqual({ kind: 'submitting' });

    expect(
      deriveAppViewModel({
        feedFieldErrors: { url: '', form: 'Bad url' },
        isConverting: false,
        routeKind: 'create',
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

  it('returns submitting on token route while converting', () => {
    expect(
      deriveAppViewModel({
        feedFieldErrors: emptyErrors,
        isConverting: true,
        routeKind: 'token',
        tokenError: '',
      })
    ).toEqual({ kind: 'submitting' });
  });
});
