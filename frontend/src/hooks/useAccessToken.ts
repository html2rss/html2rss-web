import { useEffect, useState } from 'preact/hooks';

const ACCESS_TOKEN_KEY = 'html2rss_access_token';

interface AccessTokenState {
  token: string | null;
  isLoading: boolean;
  error: string | null;
}

const memoryStorage = (() => {
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
  if (typeof window === 'undefined') return memoryStorage;

  try {
    return window.sessionStorage ?? memoryStorage;
  } catch {
    return memoryStorage;
  }
};

export function useAccessToken() {
  const [state, setState] = useState<AccessTokenState>({
    token: null,
    isLoading: true,
    error: null,
  });

  useEffect(() => {
    const storage = resolveStorage();

    try {
      const token = storage.getItem(ACCESS_TOKEN_KEY)?.trim() ?? '';

      setState({
        token: token || null,
        isLoading: false,
        error: null,
      });
    } catch {
      setState({
        token: null,
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

    setState({
      token: normalized,
      isLoading: false,
      error: null,
    });
  };

  const clearToken = () => {
    const storage = resolveStorage();
    storage.removeItem(ACCESS_TOKEN_KEY);

    setState({
      token: null,
      isLoading: false,
      error: null,
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
