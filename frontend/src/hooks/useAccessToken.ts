import { useEffect, useState } from 'preact/hooks';

const ACCESS_TOKEN_KEY = 'html2rss_access_token';
let inMemoryToken = '';

interface AccessTokenState {
  token?: string;
  isLoading: boolean;
  error?: string;
}

const readSessionToken = (): string => {
  if (globalThis.window === undefined) return inMemoryToken;

  try {
    return globalThis.sessionStorage?.getItem(ACCESS_TOKEN_KEY)?.trim() ?? '';
  } catch {
    return inMemoryToken;
  }
};

const writeSessionToken = (token: string) => {
  inMemoryToken = token;
  if (globalThis.window === undefined) return;

  try {
    if (token) {
      globalThis.sessionStorage?.setItem(ACCESS_TOKEN_KEY, token);
    } else {
      globalThis.sessionStorage?.removeItem(ACCESS_TOKEN_KEY);
    }
  } catch {
    // Keep in-memory fallback only when sessionStorage is unavailable.
  }
};

export function useAccessToken() {
  const [state, setState] = useState<AccessTokenState>({
    isLoading: true,
  });

  useEffect(() => {
    try {
      const token = readSessionToken();

      setState({
        token: token || undefined,
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

    writeSessionToken(normalized);

    setState({
      token: normalized,
      isLoading: false,
    });
  };

  const clearToken = () => {
    writeSessionToken('');

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
