import { useState } from 'preact/hooks';
import { createFeed } from '../api/generated';
import { apiClient } from '../api/client';
import type { FeedRecord } from '../api/contracts';

interface ConversionState {
  isConverting: boolean;
  result: FeedRecord | null;
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
          Authorization: `Bearer ${token}`,
        },
        body: {
          url: url.trim(),
          strategy: strategy.trim(),
        },
        throwOnError: true,
      });

      if (!response.data?.success || !response.data.data?.feed) {
        throw new Error('Invalid response format');
      }

      const result = response.data.data.feed;
      setState((prev) => ({ ...prev, isConverting: false, result, error: null }));
      return result;
    } catch (error) {
      const message = toErrorMessage(error);
      setState((prev) => ({
        ...prev,
        isConverting: false,
        error: message,
        result: null,
      }));
      throw new Error(message);
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

  const clearError = () => {
    setState((prev) => ({ ...prev, error: null }));
  };

  return {
    isConverting: state.isConverting,
    result: state.result,
    error: state.error,
    convertFeed,
    clearError,
    clearResult,
  };
}

const toErrorMessage = (error: unknown): string => {
  if (error instanceof SyntaxError) return 'Invalid response format from feed creation API';
  if (error instanceof Error) return error.message;
  if (typeof error === 'string' && error.trim()) return error;

  const message = extractMessage(error);
  return message ?? 'An unexpected error occurred';
};

const extractMessage = (error: unknown): string | null => {
  if (!error || typeof error !== 'object') return null;

  const candidate =
    (error as { error?: { message?: unknown }; message?: unknown }).error?.message ??
    (error as { message?: unknown }).message;

  return typeof candidate === 'string' && candidate.trim() ? candidate : null;
};
