import { useEffect, useState } from 'preact/hooks';
import type { ApiMetadataRecord } from '../api/contracts';

export interface StarterFeed {
  path: string;
  title: string;
  description: string;
}

interface CatalogEnvelope {
  success?: boolean;
  data?: {
    configs?: Array<{
      id: string;
      path: string;
      directory?: {
        title?: string;
        summary?: string;
      };
    }>;
  };
}

const STARTER_FEED_IDS = ['microsoft.com/azure-products', 'phys.org/weekly', 'softwareleadweekly.com/issues'];

/**
 * Loads starter feeds from the public catalog when feed creation is disabled.
 */
export function useStarterFeeds(metadata?: ApiMetadataRecord, feedCreationEnabled = true) {
  const [starterFeeds, setStarterFeeds] = useState<StarterFeed[]>([]);
  const catalog = metadata?.instance.catalog;

  useEffect(() => {
    if (feedCreationEnabled || !catalog?.enabled || !catalog.url) {
      setStarterFeeds([]);
      return;
    }

    let cancelled = false;

    const load = async () => {
      try {
        const response = await fetch(catalog.url, { headers: { Accept: 'application/json' } });
        if (!response.ok) return;

        const payload = (await response.json()) as CatalogEnvelope;
        const configs = payload.data?.configs ?? [];
        const selected = STARTER_FEED_IDS.map((id) => configs.find((entry) => entry.id === id)).filter(
          (entry): entry is NonNullable<typeof entry> => Boolean(entry)
        );
        const entries = selected.length > 0 ? selected : configs.slice(0, 3);

        if (cancelled) return;

        setStarterFeeds(
          entries.map((entry) => ({
            path: entry.path,
            title: entry.directory?.title ?? entry.id,
            description: entry.directory?.summary ?? '',
          }))
        );
      } catch {
        if (!cancelled) setStarterFeeds([]);
      }
    };

    load();
    return () => {
      cancelled = true;
    };
  }, [catalog?.enabled, catalog?.url, feedCreationEnabled]);

  return starterFeeds;
}
