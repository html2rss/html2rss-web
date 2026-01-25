import { useState, useEffect } from 'preact/hooks';

const USERNAME_KEY = 'html2rss_username';
const TOKEN_KEY = 'html2rss_token';

interface AuthState {
  isAuthenticated: boolean;
  username: string | null;
  token: string | null;
  isLoading: boolean;
  error: string | null;
}

interface MemoryStorage extends Storage {}

const memoryStorage: MemoryStorage = (() => {
  const store = new Map<string, string>();

  return {
    get length() {
      return store.size;
    },
    clear: () => store.clear(),
    getItem: (key: string) => (store.has(key) ? store.get(key)! : null),
    key: (index: number) => Array.from(store.keys())[index] ?? null,
    removeItem: (key: string) => {
      store.delete(key);
    },
    setItem: (key: string, value: string) => {
      store.set(key, value);
    },
  } as Storage;
})();

const resolveStorage = (): Storage => {
  if (typeof window === 'undefined') {
    return memoryStorage;
  }

  try {
    return window.sessionStorage ?? memoryStorage;
  } catch (error) {
    return memoryStorage;
  }
};

export function useAuth() {
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    username: null,
    token: null,
    isLoading: true,
    error: null,
  });

  useEffect(() => {
    const storage = resolveStorage();

    try {
      const username = storage.getItem(USERNAME_KEY);
      const token = storage.getItem(TOKEN_KEY);

      if (username && token && username.trim() && token.trim()) {
        setAuthState({
          isAuthenticated: true,
          username: username.trim(),
          token: token.trim(),
          isLoading: false,
          error: null,
        });
      } else {
        setAuthState((prev) => ({ ...prev, isLoading: false }));
      }
    } catch (error) {
      setAuthState((prev) => ({
        ...prev,
        isLoading: false,
        error: 'Failed to load authentication state',
      }));
    }
  }, []);

  const login = async (username: string, token: string) => {
    if (!username?.trim()) {
      throw new Error('Username is required');
    }
    if (!token?.trim()) {
      throw new Error('Token is required');
    }

    const storage = resolveStorage();

    try {
      storage.setItem(USERNAME_KEY, username.trim());
      storage.setItem(TOKEN_KEY, token.trim());

      setAuthState({
        isAuthenticated: true,
        username: username.trim(),
        token: token.trim(),
        isLoading: false,
        error: null,
      });
    } catch (error) {
      throw new Error('Failed to save authentication data');
    }
  };

  const logout = () => {
    const storage = resolveStorage();

    try {
      storage.removeItem(USERNAME_KEY);
      storage.removeItem(TOKEN_KEY);

      setAuthState({
        isAuthenticated: false,
        username: null,
        token: null,
        isLoading: false,
        error: null,
      });
    } catch (error) {
      setAuthState((prev) => ({
        ...prev,
        error: 'Failed to clear authentication data',
      }));
    }
  };

  return {
    isAuthenticated: authState.isAuthenticated,
    username: authState.username,
    token: authState.token,
    isLoading: authState.isLoading,
    error: authState.error,
    login,
    logout,
  };
}
