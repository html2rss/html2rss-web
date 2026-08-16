import { describe, expect, it } from 'vitest';
import { buildAppRouteHref, readAppRoute } from '../routes/appRoute';

describe('appRoute', () => {
  it('reads result routes without attaching a prefillUrl husk', () => {
    expect(
      readAppRoute({
        pathname: '/',
        search: '',
        hash: '#/result/example-token?url=https%3A%2F%2Fexample.com',
      })
    ).toEqual({ kind: 'result', feedToken: 'example-token' });
  });

  it('builds result hrefs without url prefill query', () => {
    expect(buildAppRouteHref({ kind: 'result', feedToken: 'example-token' }, 'http://localhost/')).toBe(
      'http://localhost/#/result/example-token'
    );
  });

  it('keeps create and token prefill on their own variants only', () => {
    expect(
      readAppRoute({
        pathname: '/',
        search: '',
        hash: '#/create?url=https%3A%2F%2Fexample.com%2Farticles',
      })
    ).toEqual({ kind: 'create', prefillUrl: 'https://example.com/articles' });

    expect(
      buildAppRouteHref({ kind: 'token', prefillUrl: 'https://example.com/articles' }, 'http://localhost/')
    ).toBe('http://localhost/#/token?url=https%3A%2F%2Fexample.com%2Farticles');
  });
});
