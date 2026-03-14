import { useEffect, useState } from 'preact/hooks';
import { getApiMetadata } from '../api/generated';
import { apiClient } from '../api/client';
import type { ApiMetadataRecord } from '../api/contracts';

interface ApiMetadataState {
  metadata: ApiMetadataRecord | null;
  isLoading: boolean;
  error: string | null;
}

export function useApiMetadata() {
  const [state, setState] = useState<ApiMetadataState>({
    metadata: null,
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
        const metadata = response.data?.data as unknown as ApiMetadataRecord | undefined;

        if (response.error || !response.data?.success || !metadata?.instance) {
          throw new Error('Invalid response format from API metadata');
        }

        setState({
          metadata,
          isLoading: false,
          error: null,
        });
      } catch (error) {
        if (controller.signal.aborted) return;

        setState({
          metadata: null,
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
