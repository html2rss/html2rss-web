import { useEffect, useState } from 'preact/hooks';
import type { ApiMetadataRecord } from '../api/contracts';

interface ApiMetadataState {
  metadata?: ApiMetadataRecord;
  isLoading: boolean;
  error?: string;
}

interface ApiMetadataPayload {
  success?: boolean;
  data?: unknown;
}

export function useApiMetadata() {
  const [state, setState] = useState<ApiMetadataState>({
    isLoading: true,
  });

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      setState((previous) => ({ ...previous, isLoading: true, error: undefined }));

      try {
        const response = await fetch('/api/v1', {
          headers: { Accept: 'application/json' },
        });
        const payload = await parseMetadataPayload(response);
        const metadata = payload.data as ApiMetadataRecord | undefined;

        if (!response.ok || !payload.success || !metadata?.instance) {
          throw new Error('Invalid response format from API metadata');
        }
        if (cancelled) return;

        setState({
          metadata,
          isLoading: false,
        });
      } catch (error) {
        if (cancelled) return;

        setState({
          isLoading: false,
          error: error instanceof Error ? error.message : 'Failed to load API metadata',
        });
      }
    };

    load();
    return () => {
      cancelled = true;
    };
  }, []);

  return state;
}

async function parseMetadataPayload(response: Response): Promise<ApiMetadataPayload> {
  const body = await response.text();
  if (!body.trim()) return {};

  try {
    return JSON.parse(body) as ApiMetadataPayload;
  } catch {
    return {};
  }
}
