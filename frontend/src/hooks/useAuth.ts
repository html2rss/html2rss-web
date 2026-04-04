import { useState, useEffect } from 'preact/hooks';

const USERNAME_KEY = 'html2rss_username';
const TOKEN_KEY = 'html2rss_token';

interface AuthState {
  isAuthenticated: boolean;
  username?: string;
  token?: string;
  isLoading: boolean;
  error?: string;
}

const memoryStorage: Storage = (() => {
  const store = new Map<string, string>();

  return {
    get length() {
      return store.size;
    },
    clear: () => store.clear(),
    getItem: (key: string) => store.get(key),
    key: (index: number) => [...store.keys()][index],
    removeItem: (key: string) => {
      store.delete(key);
    },
    setItem: (key: string, value: string) => {
      store.set(key, value);
    },
  } as Storage;
})();

const resolveStorage = (): Storage => {
  if (globalThis.window === undefined) {
    return memoryStorage;
  }

  try {
    return globalThis.localStorage ?? globalThis.sessionStorage ?? memoryStorage;
  } catch {
    try {
      return globalThis.sessionStorage ?? memoryStorage;
    } catch {
      return memoryStorage;
    }
  }
};

export function useAuth() {
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    isLoading: true,
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
        });
      } else {
        setAuthState((previous) => ({ ...previous, isLoading: false }));
      }
    } catch {
      setAuthState((previous) => ({
        ...previous,
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
      });
    } catch {
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
        isLoading: false,
      });
    } catch {
      setAuthState((previous) => ({
        ...previous,
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
