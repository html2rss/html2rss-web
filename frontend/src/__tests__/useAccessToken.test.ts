import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { useAccessToken } from '../hooks/useAccessToken';

describe('useAccessToken', () => {
  beforeEach(() => {
    globalThis.localStorage.clear();
    globalThis.sessionStorage.clear();
  });

  it('loads the persisted token from localStorage', async () => {
    globalThis.localStorage.setItem('html2rss_access_token', 'persisted-token');

    const { result } = renderHook(() => useAccessToken());

    expect(result.current.isLoading).toBe(false);
    expect(result.current.token).toBe('persisted-token');
    expect(result.current.hasToken).toBe(true);
    expect(result.current.error).toBeUndefined();
  });

  it('migrates a legacy session token into localStorage', async () => {
    globalThis.sessionStorage.setItem('html2rss_access_token', 'legacy-token');

    const { result } = renderHook(() => useAccessToken());

    expect(result.current.isLoading).toBe(false);
    expect(result.current.token).toBe('legacy-token');
    expect(globalThis.localStorage.getItem('html2rss_access_token')).toBe('legacy-token');
    expect(globalThis.sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });

  it('saves new tokens to the persistent storage path', async () => {
    const { result } = renderHook(() => useAccessToken());

    await act(async () => {
      await result.current.saveToken('new-token');
    });

    expect(result.current.token).toBe('new-token');
    expect(result.current.hasToken).toBe(true);
    expect(globalThis.localStorage.getItem('html2rss_access_token')).toBe('new-token');
    expect(globalThis.sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });

  it('clears both persistent and legacy token copies', async () => {
    globalThis.localStorage.setItem('html2rss_access_token', 'persisted-token');
    globalThis.sessionStorage.setItem('html2rss_access_token', 'legacy-token');

    const { result } = renderHook(() => useAccessToken());

    act(() => {
      result.current.clearToken();
    });

    expect(result.current.token).toBeUndefined();
    expect(result.current.hasToken).toBe(false);
    expect(globalThis.localStorage.getItem('html2rss_access_token')).toBeNull();
    expect(globalThis.sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });
});
