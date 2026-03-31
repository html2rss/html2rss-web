import { useState, useEffect } from 'preact/hooks';
import { listStrategies } from '../api/generated';
import { apiClient } from '../api/client';
import type { StrategyRecord } from '../api/contracts';

interface StrategiesState {
  strategies: StrategyRecord[];
  isLoading: boolean;
  error?: string;
}

export function useStrategies() {
  const [state, setState] = useState<StrategiesState>({
    strategies: [],
    isLoading: true,
  });

  const fetchStrategies = async () => {
    setState((previous) => ({ ...previous, isLoading: true, error: undefined }));

    try {
      const response = await listStrategies({
        client: apiClient,
      });

      if (response.error || !response.data?.success || !response.data.data?.strategies) {
        throw new Error('Invalid response format from strategies API');
      }

      setState({
        strategies: response.data.data.strategies,
        isLoading: false,
      });
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
  }, []);

  return {
    strategies: state.strategies,
    isLoading: state.isLoading,
    error: state.error,
    refetch: fetchStrategies,
  };
}
