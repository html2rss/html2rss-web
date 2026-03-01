import { useState, useEffect } from 'preact/hooks';
import { listStrategies } from '../api/generated';
import { apiClient, bearerHeaders } from '../api/client';
import type { StrategyRecord } from '../api/contracts';

interface StrategiesState {
  strategies: StrategyRecord[];
  isLoading: boolean;
  error: string | null;
}

export function useStrategies(token: string | null) {
  const [state, setState] = useState<StrategiesState>({
    strategies: [],
    isLoading: !!token,
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

      if (response?.success && response.data?.strategies) {
        setState({
          strategies: response.data.strategies,
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
