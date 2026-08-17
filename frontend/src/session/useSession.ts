import { useApiMetadata } from '../hooks/useApiMetadata';
import { useAccessToken } from './accessToken';

const DEFAULT_FEED_CREATION = { enabled: true, access_token_required: true };

/** Closed gate outcome for attempting feed creation with an optional token. */
export type MayCreateResult = 'proceed' | 'needToken' | 'disabled';

/**
 * Deep Session: Access Token persistence + feed-creation gate from API metadata.
 * Does not own route transitions — App clears token and navigates on logout.
 */
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
  const feedCreation = metadata?.instance.feed_creation ?? DEFAULT_FEED_CREATION;
  const feedCreationEnabled = feedCreation.enabled;

  const mayCreate = (accessToken?: string): MayCreateResult => {
    if (!feedCreation.enabled) return 'disabled';
    const candidate = (accessToken ?? token ?? '').trim();
    if (feedCreation.access_token_required && !candidate) return 'needToken';
    return 'proceed';
  };

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
    feedCreationEnabled,
    mayCreate,
  };
}
