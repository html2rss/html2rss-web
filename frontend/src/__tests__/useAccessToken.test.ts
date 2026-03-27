import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { useAccessToken } from '../hooks/useAccessToken';

describe('useAccessToken', () => {
  beforeEach(() => {
    window.localStorage.clear();
    window.sessionStorage.clear();
  });

  it('loads the persisted token from localStorage', async () => {
    window.localStorage.setItem('html2rss_access_token', 'persisted-token');

    const { result } = renderHook(() => useAccessToken());

    expect(result.current.isLoading).toBe(false);
    expect(result.current.token).toBe('persisted-token');
    expect(result.current.hasToken).toBe(true);
    expect(result.current.error).toBeNull();
  });

  it('migrates a legacy session token into localStorage', async () => {
    window.sessionStorage.setItem('html2rss_access_token', 'legacy-token');

    const { result } = renderHook(() => useAccessToken());

    expect(result.current.isLoading).toBe(false);
    expect(result.current.token).toBe('legacy-token');
    expect(window.localStorage.getItem('html2rss_access_token')).toBe('legacy-token');
    expect(window.sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });

  it('saves new tokens to the persistent storage path', async () => {
    const { result } = renderHook(() => useAccessToken());

    await act(async () => {
      await result.current.saveToken('new-token');
    });

    expect(result.current.token).toBe('new-token');
    expect(result.current.hasToken).toBe(true);
    expect(window.localStorage.getItem('html2rss_access_token')).toBe('new-token');
    expect(window.sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });

  it('clears both persistent and legacy token copies', async () => {
    window.localStorage.setItem('html2rss_access_token', 'persisted-token');
    window.sessionStorage.setItem('html2rss_access_token', 'legacy-token');

    const { result } = renderHook(() => useAccessToken());

    act(() => {
      result.current.clearToken();
    });

    expect(result.current.token).toBeNull();
    expect(result.current.hasToken).toBe(false);
    expect(window.localStorage.getItem('html2rss_access_token')).toBeNull();
    expect(window.sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });
});
