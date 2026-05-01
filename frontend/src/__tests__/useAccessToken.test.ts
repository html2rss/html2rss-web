import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { useAccessToken } from '../hooks/useAccessToken';

describe('useAccessToken', () => {
  beforeEach(() => {
    globalThis.sessionStorage.clear();
  });

  it('loads the persisted token from sessionStorage', async () => {
    globalThis.sessionStorage.setItem('html2rss_access_token', 'persisted-token');

    const { result } = renderHook(() => useAccessToken());

    expect(result.current.isLoading).toBe(false);
    expect(result.current.token).toBe('persisted-token');
    expect(result.current.hasToken).toBe(true);
    expect(result.current.error).toBeUndefined();
  });

  it('saves new tokens to sessionStorage only', async () => {
    const { result } = renderHook(() => useAccessToken());

    await act(async () => {
      await result.current.saveToken('new-token');
    });

    expect(result.current.token).toBe('new-token');
    expect(result.current.hasToken).toBe(true);
    expect(globalThis.sessionStorage.getItem('html2rss_access_token')).toBe('new-token');
  });

  it('clears the canonical session token copy', async () => {
    globalThis.sessionStorage.setItem('html2rss_access_token', 'persisted-token');

    const { result } = renderHook(() => useAccessToken());

    act(() => {
      result.current.clearToken();
    });

    expect(result.current.token).toBeUndefined();
    expect(result.current.hasToken).toBe(false);
    expect(globalThis.sessionStorage.getItem('html2rss_access_token')).toBeNull();
  });

  it('falls back to in-memory token when sessionStorage write is unavailable', async () => {
    globalThis.sessionStorage.setItem.mockImplementationOnce(() => {
      throw new Error('blocked');
    });

    const { result } = renderHook(() => useAccessToken());

    await act(async () => {
      await result.current.saveToken('memory-token');
    });

    expect(result.current.token).toBe('memory-token');
    expect(result.current.hasToken).toBe(true);
  });

  it('loads from in-memory fallback when sessionStorage read is unavailable', async () => {
    globalThis.sessionStorage.setItem.mockImplementationOnce(() => {
      throw new Error('blocked');
    });

    const seeded = renderHook(() => useAccessToken());
    await act(async () => {
      await seeded.result.current.saveToken('memory-only');
    });
    seeded.unmount();

    globalThis.sessionStorage.getItem.mockImplementationOnce(() => {
      throw new Error('blocked');
    });

    const { result } = renderHook(() => useAccessToken());

    expect(result.current.isLoading).toBe(false);
    expect(result.current.token).toBe('memory-only');
    expect(result.current.hasToken).toBe(true);
    expect(result.current.error).toBeUndefined();
    act(() => {
      result.current.clearToken();
    });
  });
});
