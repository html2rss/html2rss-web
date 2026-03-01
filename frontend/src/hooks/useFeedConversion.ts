import { useState } from 'preact/hooks';
import { createFeed } from '../api/generated';
import { apiClient, bearerHeaders } from '../api/client';

interface ConversionResult {
  id: string;
  name: string;
  url: string;
  strategy: string;
  public_url: string;
  created_at: string;
  updated_at: string;
}

interface ConversionState {
  isConverting: boolean;
  result: ConversionResult | null;
  error: string | null;
}

export function useFeedConversion() {
  const [state, setState] = useState<ConversionState>({
    isConverting: false,
    result: null,
    error: null,
  });

  const convertFeed = async (url: string, strategy: string, token: string) => {
    if (!url?.trim()) throw new Error('URL is required');
    if (!strategy?.trim()) throw new Error('Strategy is required');

    try {
      new URL(url.trim());
    } catch {
      throw new Error('Invalid URL format');
    }

    setState((prev) => ({ ...prev, isConverting: true, error: null }));

    try {
      const response = await createFeed({
        client: apiClient,
        headers: {
          'Content-Type': 'application/json',
          ...bearerHeaders(token),
        },
        body: {
          url: url.trim(),
          strategy: strategy.trim(),
        },
      });

      const errorPayload = response.error as { error?: { message?: string } } | undefined;
      if (response.error) {
        const networkMessage = response.error instanceof Error ? response.error.message : undefined;
        throw new Error(networkMessage || errorPayload?.error?.message || 'Request failed');
      }

      const typed = response.data as {
        success?: boolean;
        data?: { feed?: ConversionResult };
      };

      if (!typed?.success || !typed?.data?.feed) {
        throw new Error('Invalid response format');
      }

      const result = typed.data.feed;
      setState((prev) => ({ ...prev, isConverting: false, result, error: null }));
    } catch (error) {
      setState((prev) => ({
        ...prev,
        isConverting: false,
        error: error instanceof Error ? error.message : 'An unexpected error occurred',
        result: null,
      }));
    }
  };

  const clearResult = () => {
    window.document.body.scrollIntoView({ behavior: 'smooth', block: 'start' });

    setState({
      isConverting: false,
      result: null,
      error: null,
    });
  };

  return {
    isConverting: state.isConverting,
    result: state.result,
    error: state.error,
    convertFeed,
    clearResult,
  };
}
