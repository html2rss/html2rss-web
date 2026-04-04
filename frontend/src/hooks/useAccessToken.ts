import { useEffect, useState } from 'preact/hooks';

const ACCESS_TOKEN_KEY = 'html2rss_access_token';

interface AccessTokenState {
  token?: string;
  isLoading: boolean;
  error?: string;
}

const memoryStorage = (() => {
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
  if (globalThis.window === undefined) return memoryStorage;

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

const clearLegacySessionToken = () => {
  if (globalThis.window === undefined) return;

  try {
    globalThis.sessionStorage?.removeItem(ACCESS_TOKEN_KEY);
  } catch {
    // Ignore restricted sessionStorage access (privacy mode, sandboxed contexts).
  }
};

export function useAccessToken() {
  const [state, setState] = useState<AccessTokenState>({
    isLoading: true,
  });

  useEffect(() => {
    const storage = resolveStorage();

    try {
      const token = storage.getItem(ACCESS_TOKEN_KEY)?.trim() ?? '';
      let legacyToken = '';
      if (!token && globalThis.window !== undefined) {
        try {
          legacyToken = globalThis.sessionStorage?.getItem(ACCESS_TOKEN_KEY)?.trim() ?? '';
        } catch {
          // Treat restricted sessionStorage access as no legacy token.
          legacyToken = '';
        }
      }

      if (!token && legacyToken) {
        storage.setItem(ACCESS_TOKEN_KEY, legacyToken);
        clearLegacySessionToken();
      }

      setState({
        token: token || legacyToken || undefined,
        isLoading: false,
      });
    } catch {
      setState({
        isLoading: false,
        error: 'Failed to load access token state',
      });
    }
  }, []);

  const saveToken = async (token: string) => {
    const normalized = token.trim();
    if (!normalized) throw new Error('Access token is required');

    const storage = resolveStorage();
    storage.setItem(ACCESS_TOKEN_KEY, normalized);
    clearLegacySessionToken();

    setState({
      token: normalized,
      isLoading: false,
    });
  };

  const clearToken = () => {
    const storage = resolveStorage();
    storage.removeItem(ACCESS_TOKEN_KEY);
    clearLegacySessionToken();

    setState({
      isLoading: false,
    });
  };

  return {
    token: state.token,
    hasToken: Boolean(state.token),
    isLoading: state.isLoading,
    error: state.error,
    saveToken,
    clearToken,
  };
}
