import { useState, useEffect } from 'preact/hooks';

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
      const response = await fetch('/api/v1/strategies', {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch strategies: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();

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
