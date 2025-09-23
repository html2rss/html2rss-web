import { useState } from 'preact/hooks';

interface ConversionResult {
  id: string;
  name: string;
  url: string;
  username: string;
  strategy: string;
  public_url: string;
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

  const convertFeed = async (url: string, name: string, strategy: string, token: string) => {
    // Validate inputs
    if (!url?.trim()) {
      throw new Error('URL is required');
    }
    if (!name?.trim()) {
      throw new Error('Feed name is required');
    }
    if (!strategy?.trim()) {
      throw new Error('Strategy is required');
    }

    // Validate URL format
    try {
      new URL(url.trim());
    } catch {
      throw new Error('Invalid URL format');
    }

    setState((prev) => ({ ...prev, isConverting: true, error: null }));

    try {
      const response = await fetch('/auto_source/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: `Bearer ${token}`,
        },
        body: new URLSearchParams({
          url: url.trim(),
          name: name.trim(),
          strategy: strategy.trim(),
        }),
      });

      if (!response.ok) {
        let errorMessage = `Request failed with status ${response.status}`;
        try {
          const errorText = await response.text();
          errorMessage = errorText || errorMessage;
        } catch {
          // Use default error message if response text can't be read
        }
        throw new Error(errorMessage);
      }

      const result = await response.json();

      // Validate response structure
      if (!result || typeof result !== 'object') {
        throw new Error('Invalid response format');
      }

      setState((prev) => ({
        ...prev,
        isConverting: false,
        result,
        error: null,
      }));
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
