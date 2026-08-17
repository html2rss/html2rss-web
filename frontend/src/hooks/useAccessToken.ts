import { useEffect, useState } from 'preact/hooks';
import { getPersistentStorage } from '../utils/persistentStorage';

const ACCESS_TOKEN_KEY = 'html2rss_access_token';
let inMemoryToken = '';

interface AccessTokenState {
  token?: string;
  isLoading: boolean;
  error?: string;
}

const readPersistedToken = (): string => {
  if (globalThis.window === undefined) return inMemoryToken;

  try {
    return getPersistentStorage().getItem(ACCESS_TOKEN_KEY)?.trim() ?? '';
  } catch {
    return inMemoryToken;
  }
};

const writePersistedToken = (token: string) => {
  // eslint-disable-next-line unicorn/no-top-level-assignment-in-function
  inMemoryToken = token;
  if (globalThis.window === undefined) return;

  try {
    const storage = getPersistentStorage();
    if (token) {
      storage.setItem(ACCESS_TOKEN_KEY, token);
    } else {
      storage.removeItem(ACCESS_TOKEN_KEY);
    }
  } catch {
    // Keep in-memory fallback only when persistent storage is unavailable.
  }
};

export function resetAccessTokenMemory() {
  writePersistedToken('');
}

export function useAccessToken() {
  const [state, setState] = useState<AccessTokenState>({
    isLoading: true,
  });

  useEffect(() => {
    try {
      const token = readPersistedToken();

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

    writePersistedToken(normalized);

    setState({
      token: normalized,
      isLoading: false,
    });
  };

  const clearToken = () => {
    writePersistedToken('');

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
