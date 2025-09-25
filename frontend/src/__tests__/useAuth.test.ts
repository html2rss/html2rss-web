import { describe, it, expect, beforeEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { useAuth } from '../hooks/useAuth';

type MockedStorage = Storage & {
  getItem: ReturnType<typeof vi.fn>;
  setItem: ReturnType<typeof vi.fn>;
  removeItem: ReturnType<typeof vi.fn>;
  clear: ReturnType<typeof vi.fn>;
};

const localStorageMock = window.localStorage as MockedStorage;

describe('useAuth', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should initialize with unauthenticated state', () => {
    localStorageMock.getItem.mockReturnValue(null);

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.username).toBeNull();
    expect(result.current.token).toBeNull();
  });

  it('should load auth state from localStorage on mount', () => {
    localStorageMock.getItem
      .mockReturnValueOnce('testuser') // username
      .mockReturnValueOnce('testtoken'); // token

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.username).toBe('testuser');
    expect(result.current.token).toBe('testtoken');
    expect(localStorageMock.getItem).toHaveBeenCalledWith('html2rss_username');
    expect(localStorageMock.getItem).toHaveBeenCalledWith('html2rss_token');
  });

  it('should login and store credentials', async () => {
    localStorageMock.getItem.mockReturnValue(null);

    const { result } = renderHook(() => useAuth());

    await act(async () => {
      result.current.login('newuser', 'newtoken');
    });

    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.username).toBe('newuser');
    expect(result.current.token).toBe('newtoken');
    expect(localStorageMock.setItem).toHaveBeenCalledWith('html2rss_username', 'newuser');
    expect(localStorageMock.setItem).toHaveBeenCalledWith('html2rss_token', 'newtoken');
  });

  it('should logout and clear credentials', () => {
    localStorageMock.getItem.mockReturnValueOnce('testuser').mockReturnValueOnce('testtoken');

    const { result } = renderHook(() => useAuth());

    act(() => {
      result.current.logout();
    });

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.username).toBeNull();
    expect(result.current.token).toBeNull();
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('html2rss_username');
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('html2rss_token');
  });

});
