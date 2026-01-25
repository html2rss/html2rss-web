import { describe, it, expect, beforeEach, vi } from 'vitest';
import { renderHook, act } from '@testing-library/preact';
import { useAuth } from '../hooks/useAuth';

type MockedStorage = Storage & {
  getItem: ReturnType<typeof vi.fn>;
  setItem: ReturnType<typeof vi.fn>;
  removeItem: ReturnType<typeof vi.fn>;
  clear: ReturnType<typeof vi.fn>;
};

const createStorageMock = (): MockedStorage => {
  return {
    length: 0,
    clear: vi.fn(),
    getItem: vi.fn(),
    key: vi.fn(),
    removeItem: vi.fn(),
    setItem: vi.fn(),
  } as unknown as MockedStorage;
};

let sessionStorageMock: MockedStorage;

describe('useAuth', () => {
  beforeEach(() => {
    sessionStorageMock = createStorageMock();
    Object.defineProperty(window, 'sessionStorage', {
      value: sessionStorageMock,
      configurable: true,
      writable: true,
    });
    vi.clearAllMocks();
  });

  it('should initialize with unauthenticated state', () => {
    sessionStorageMock.getItem.mockReturnValue(null);

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.username).toBeNull();
    expect(result.current.token).toBeNull();
  });

  it('should load auth state from sessionStorage on mount', () => {
    sessionStorageMock.getItem
      .mockReturnValueOnce('testuser') // username
      .mockReturnValueOnce('testtoken'); // token

    const { result } = renderHook(() => useAuth());

    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.username).toBe('testuser');
    expect(result.current.token).toBe('testtoken');
    expect(sessionStorageMock.getItem).toHaveBeenCalledWith('html2rss_username');
    expect(sessionStorageMock.getItem).toHaveBeenCalledWith('html2rss_token');
  });

  it('should login and store credentials', async () => {
    sessionStorageMock.getItem.mockReturnValue(null);

    const { result } = renderHook(() => useAuth());

    await act(async () => {
      result.current.login('newuser', 'newtoken');
    });

    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.username).toBe('newuser');
    expect(result.current.token).toBe('newtoken');
    expect(sessionStorageMock.setItem).toHaveBeenCalledWith('html2rss_username', 'newuser');
    expect(sessionStorageMock.setItem).toHaveBeenCalledWith('html2rss_token', 'newtoken');
  });

  it('should logout and clear credentials', () => {
    sessionStorageMock.getItem.mockReturnValueOnce('testuser').mockReturnValueOnce('testtoken');

    const { result } = renderHook(() => useAuth());

    act(() => {
      result.current.logout();
    });

    expect(result.current.isAuthenticated).toBe(false);
    expect(result.current.username).toBeNull();
    expect(result.current.token).toBeNull();
    expect(sessionStorageMock.removeItem).toHaveBeenCalledWith('html2rss_username');
    expect(sessionStorageMock.removeItem).toHaveBeenCalledWith('html2rss_token');
  });
});
