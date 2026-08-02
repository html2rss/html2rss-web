import { useAccessToken } from './useAccessToken';
import { useApiMetadata } from './useApiMetadata';

export function useSession() {
  const {
    token,
    hasToken,
    saveToken,
    clearToken,
    isLoading: tokenLoading,
    error: tokenStateError,
  } = useAccessToken();

  const { metadata, isLoading: metadataLoading, error: metadataError } = useApiMetadata();

  const isLoading = tokenLoading || metadataLoading;
  const featuredFeeds = metadata?.instance.featured_feeds ?? [];

  return {
    token,
    hasToken,
    metadata,
    featuredFeeds,
    isLoading,
    metadataError,
    tokenStateError,
    saveToken,
    clearToken,
  };
}
