import { useEffect, useState } from 'preact/hooks';
import { getApiMetadata } from '../api/generated';
import { apiClient } from '../api/client';
import type { DemoRecord } from '../api/contracts';

interface ApiMetadataState {
  demo: DemoRecord | null;
  isLoading: boolean;
  error: string | null;
}

export function useApiMetadata() {
  const [state, setState] = useState<ApiMetadataState>({
    demo: null,
    isLoading: true,
    error: null,
  });

  useEffect(() => {
    const controller = new AbortController();

    const load = async () => {
      setState((prev) => ({ ...prev, isLoading: true, error: null }));

      try {
        const response = await getApiMetadata({
          client: apiClient,
          signal: controller.signal,
        });

        if (response.error || !response.data?.success || !response.data.data?.demo) {
          throw new Error('Invalid response format from API metadata');
        }

        setState({
          demo: response.data.data.demo,
          isLoading: false,
          error: null,
        });
      } catch (error) {
        if (controller.signal.aborted) return;

        setState({
          demo: null,
          isLoading: false,
          error: error instanceof Error ? error.message : 'Failed to load API metadata',
        });
      }
    };

    load();
    return () => controller.abort();
  }, []);

  return state;
}
