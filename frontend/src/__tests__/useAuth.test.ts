import { describe, it, expect, beforeEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { useAuth } from '../hooks/useAuth';

describe('useAuth', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should initialize with unauthenticated state', () => {
    (global as any).localStorageMock.getItem.mockReturnValue(null);

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.username).toBeNull();
    expect(result.current.token).toBeNull();
  });

  it('should load auth state from localStorage on mount', () => {
    (global as any).localStorageMock.getItem
      .mockReturnValueOnce('testuser') // username
      .mockReturnValueOnce('testtoken'); // token

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.username).toBe('testuser');
    expect(result.current.token).toBe('testtoken');
    expect((global as any).localStorageMock.getItem).toHaveBeenCalledWith('html2rss_username');
    expect((global as any).localStorageMock.getItem).toHaveBeenCalledWith('html2rss_token');
  });

  it('should login and store credentials', async () => {
    (global as any).localStorageMock.getItem.mockReturnValue(null);

    const { result } = renderHook(() => useAuth());

    await act(async () => {
      result.current.login('newuser', 'newtoken');
    });

    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.username).toBe('newuser');
    expect(result.current.token).toBe('newtoken');
    expect((global as any).localStorageMock.setItem).toHaveBeenCalledWith('html2rss_username', 'newuser');
    expect((global as any).localStorageMock.setItem).toHaveBeenCalledWith('html2rss_token', 'newtoken');
  });

  it('should logout and clear credentials', () => {
    (global as any).localStorageMock.getItem.mockReturnValueOnce('testuser').mockReturnValueOnce('testtoken');

    const { result } = renderHook(() => useAuth());

    act(() => {
      result.current.logout();
    });

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.username).toBeNull();
    expect(result.current.token).toBeNull();
    expect((global as any).localStorageMock.removeItem).toHaveBeenCalledWith('html2rss_username');
    expect((global as any).localStorageMock.removeItem).toHaveBeenCalledWith('html2rss_token');
  });

  it('should not authenticate if only username is present', () => {
    (global as any).localStorageMock.getItem
      .mockReturnValueOnce('testuser') // username
      .mockReturnValueOnce(null); // token

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.username).toBeNull();
    expect(result.current.token).toBeNull();
  });

  it('should not authenticate if only token is present', () => {
    (global as any).localStorageMock.getItem
      .mockReturnValueOnce(null) // username
      .mockReturnValueOnce('testtoken'); // token

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.username).toBeNull();
    expect(result.current.token).toBeNull();
  });
});
