import { useEffect, useState } from 'preact/hooks';
import type { ApiMetadataRecord } from '../api/contracts';
import { requestApiMetadata } from '../api/http/metadata';
import { COPY } from '../journey/copy';

interface ApiMetadataState {
  metadata?: ApiMetadataRecord;
  isLoading: boolean;
  error?: string;
}

export function useApiMetadata() {
  const [state, setState] = useState<ApiMetadataState>({
    isLoading: true,
  });

  useEffect(() => {
    let isCancelled = false;

    const load = async () => {
      setState((previous) => ({ ...previous, isLoading: true, error: undefined }));

      try {
        const payload = await requestApiMetadata();
        const metadata = payload?.data;
        if (!metadata?.instance) {
          throw new Error(COPY.instanceUnavailable);
        }
        if (isCancelled) return;

        setState({
          metadata,
          isLoading: false,
        });
      } catch (error) {
        if (isCancelled) return;

        setState({
          isLoading: false,
          error: error instanceof Error ? error.message : COPY.instanceUnavailable,
        });
      }
    };

    load();
    return () => {
      isCancelled = true;
    };
  }, []);

  return state;
}
