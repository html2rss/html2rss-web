import { describe, expect, it } from 'vitest';
import { act, renderHook } from '@testing-library/preact';
import { buildAppRouteHref, readAppRoute, useAppRoute } from '../routes/appRoute';

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

  it('reads and builds the unresolved workspace hash without a feed token', () => {
    expect(
      readAppRoute({
        pathname: '/',
        search: '',
        hash: '#/result',
      })
    ).toEqual({ kind: 'result' });

    expect(buildAppRouteHref({ kind: 'result' }, 'http://localhost/')).toBe('http://localhost/#/result');
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

  it('reads hashbang create routes as create', () => {
    expect(
      readAppRoute({
        pathname: '/',
        search: '',
        hash: '#!/create',
      })
    ).toEqual({ kind: 'create' });

    expect(
      readAppRoute({
        pathname: '/',
        search: '',
        hash: '#!/create?url=https%3A%2F%2Fexample.com%2Farticles',
      })
    ).toEqual({ kind: 'create', prefillUrl: 'https://example.com/articles' });
  });

  it('canonicalizes hashbang create hashes, preserves prefill, and bumps createEntryKey', () => {
    history.replaceState({}, '', 'http://localhost:3000/#!/create?url=https%3A%2F%2Fexample.com%2Farticles');

    const { result, unmount } = renderHook(() => useAppRoute());

    expect(location.hash).toBe('#/create?url=https%3A%2F%2Fexample.com%2Farticles');
    expect(result.current.route).toEqual({
      kind: 'create',
      prefillUrl: 'https://example.com/articles',
    });
    expect(result.current.createEntryKey).toBeGreaterThan(0);
    unmount();
  });

  it('bumps createEntryKey when navigating to create while already on create', () => {
    history.replaceState({}, '', 'http://localhost:3000/#/create');

    const { result, unmount } = renderHook(() => useAppRoute());

    expect(result.current.createEntryKey).toBe(0);

    act(() => {
      result.current.navigate({ kind: 'create' });
    });

    expect(result.current.createEntryKey).toBeGreaterThan(0);
    unmount();
  });

  it('treats an unknown hash as create and canonicalizes onto #/create', () => {
    expect(
      readAppRoute({
        pathname: '/',
        search: '',
        hash: '#/unknown?url=https%3A%2F%2Fexample.com',
      })
    ).toEqual({ kind: 'create', prefillUrl: 'https://example.com' });

    history.replaceState({}, '', 'http://localhost:3000/#/unknown');

    const { result, unmount } = renderHook(() => useAppRoute());

    expect(location.hash).toBe('#/create');
    expect(result.current.route).toEqual({ kind: 'create' });
    unmount();
  });
});
