import { useState, useEffect } from 'preact/hooks';

interface AuthState {
  isAuthenticated: boolean;
  username: string | null;
  token: string | null;
  isLoading: boolean;
  error: string | null;
}

export function useAuth() {
  const [authState, setAuthState] = useState<AuthState>({
    isAuthenticated: false,
    username: null,
    token: null,
    isLoading: true,
    error: null,
  });

  useEffect(() => {
    try {
      const username = localStorage.getItem('html2rss_username');
      const token = localStorage.getItem('html2rss_token');

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

    try {
      localStorage.setItem('html2rss_username', username.trim());
      localStorage.setItem('html2rss_token', token.trim());

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
    try {
      localStorage.removeItem('html2rss_username');
      localStorage.removeItem('html2rss_token');

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
