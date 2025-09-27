import { useState } from 'preact/hooks';

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
      const response = await fetch('/api/v1/feeds', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          url: url.trim(),
          strategy: strategy.trim(),
        }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        const errorMessage = errorData?.error?.message || `Request failed with status ${response.status}`;
        throw new Error(errorMessage);
      }

      const responseData = await response.json();
      if (!responseData?.success || !responseData?.data?.feed) {
        throw new Error('Invalid response format');
      }

      const result = responseData.data.feed;
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
