import { useState, useEffect } from 'preact/hooks';
import { listStrategies } from '../api/generated';
import { apiClient, bearerHeaders } from '../api/client';

interface Strategy {
  id: string;
  name: string;
  display_name: string;
}

interface StrategiesState {
  strategies: Strategy[];
  isLoading: boolean;
  error: string | null;
}

export function useStrategies(token: string | null) {
  const [state, setState] = useState<StrategiesState>({
    strategies: [],
    isLoading: false,
    error: null,
  });

  const fetchStrategies = async () => {
    if (!token) {
      setState({ strategies: [], isLoading: false, error: null });
      return;
    }

    setState((prev) => ({ ...prev, isLoading: true, error: null }));

    try {
      const response = await listStrategies({
        client: apiClient,
        headers: {
          ...bearerHeaders(token),
          'Content-Type': 'application/json',
        },
        responseStyle: 'data',
      });

      const data = response as { success?: boolean; data?: { strategies?: Strategy[] } };

      if (data.success && data.data?.strategies) {
        setState({
          strategies: data.data.strategies,
          isLoading: false,
          error: null,
        });
      } else {
        throw new Error('Invalid response format from strategies API');
      }
    } catch (error) {
      setState({
        strategies: [],
        isLoading: false,
        error: error instanceof Error ? error.message : 'Failed to fetch strategies',
      });
    }
  };

  useEffect(() => {
    fetchStrategies();
  }, [token]);

  return {
    strategies: state.strategies,
    isLoading: state.isLoading,
    error: state.error,
    refetch: fetchStrategies,
  };
}
