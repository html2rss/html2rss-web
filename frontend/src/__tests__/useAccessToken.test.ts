import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { resetAccessTokenMemory, useAccessToken } from '../hooks/useAccessToken';
import { getPersistentStorage } from '../utils/persistentStorage';

const ACCESS_TOKEN_KEY = 'html2rss_access_token';

describe('useAccessToken', () => {
  beforeEach(() => {
    getPersistentStorage().clear();
    sessionStorage.clear();
    resetAccessTokenMemory();
  });

  afterEach(() => {
    resetAccessTokenMemory();
    getPersistentStorage().clear();
    sessionStorage.clear();
  });

  it('loads the persisted token from persistent storage', async () => {
    getPersistentStorage().setItem(ACCESS_TOKEN_KEY, 'persisted-token');

    const { result } = renderHook(() => useAccessToken());

    expect(result.current.isLoading).toBe(false);
    expect(result.current.token).toBe('persisted-token');
    expect(result.current.hasToken).toBe(true);
    expect(result.current.error).toBeUndefined();
    expect(sessionStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull();
  });

  it('saves new tokens to persistent storage and does not write sessionStorage', async () => {
    const { result } = renderHook(() => useAccessToken());

    await act(async () => {
      await result.current.saveToken('new-token');
    });

    expect(result.current.token).toBe('new-token');
    expect(result.current.hasToken).toBe(true);
    expect(getPersistentStorage().getItem(ACCESS_TOKEN_KEY)).toBe('new-token');
    expect(localStorage.getItem(ACCESS_TOKEN_KEY)).toBe('new-token');
    expect(sessionStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull();
  });

  it('clears the canonical persistent token copy', async () => {
    getPersistentStorage().setItem(ACCESS_TOKEN_KEY, 'persisted-token');

    const { result } = renderHook(() => useAccessToken());

    act(() => {
      result.current.clearToken();
    });

    expect(result.current.token).toBeUndefined();
    expect(result.current.hasToken).toBe(false);
    expect(getPersistentStorage().getItem(ACCESS_TOKEN_KEY)).toBeNull();
    expect(sessionStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull();
  });

  it('falls back to in-memory token when persistent storage write is unavailable', async () => {
    localStorage.setItem.mockImplementationOnce(() => {
      throw new Error('blocked');
    });

    const { result } = renderHook(() => useAccessToken());

    await act(async () => {
      await result.current.saveToken('memory-token');
    });

    expect(result.current.token).toBe('memory-token');
    expect(result.current.hasToken).toBe(true);
    expect(sessionStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull();
  });

  it('loads from in-memory fallback when persistent storage read is unavailable', async () => {
    localStorage.setItem.mockImplementationOnce(() => {
      throw new Error('blocked');
    });

    const seeded = renderHook(() => useAccessToken());
    await act(async () => {
      await seeded.result.current.saveToken('memory-only');
    });
    seeded.unmount();

    localStorage.getItem.mockImplementationOnce(() => {
      throw new Error('blocked');
    });

    const { result } = renderHook(() => useAccessToken());

    expect(result.current.isLoading).toBe(false);
    expect(result.current.token).toBe('memory-only');
    expect(result.current.hasToken).toBe(true);
    expect(result.current.error).toBeUndefined();
    expect(sessionStorage.getItem(ACCESS_TOKEN_KEY)).toBeNull();
    act(() => {
      result.current.clearToken();
    });
  });
});
