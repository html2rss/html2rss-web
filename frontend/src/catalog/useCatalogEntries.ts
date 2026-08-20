import { useEffect, useState } from 'preact/hooks';
import type { ApiMetadataRecord } from '../api/contracts';
import { parseCatalogEntries } from './parseCatalog';
import type { CatalogEntry } from './types';

/**
 * Loads catalog entries when the instance catalog is enabled.
 */
export function useCatalogEntries(metadata?: ApiMetadataRecord): CatalogEntry[] {
  const [entries, setEntries] = useState<CatalogEntry[]>([]);
  const catalog = metadata?.instance.catalog;

  useEffect(() => {
    if (!catalog?.enabled || !catalog.url) {
      setEntries([]);
      return;
    }

    let isCancelled = false;

    const load = async () => {
      try {
        const response = await fetch(catalog.url, { headers: { Accept: 'application/json' } });
        if (!response.ok) {
          if (!isCancelled) setEntries([]);
          return;
        }

        const payload: unknown = await response.json();
        if (isCancelled) return;
        setEntries(parseCatalogEntries(payload));
      } catch {
        if (!isCancelled) setEntries([]);
      }
    };

    load();
    return () => {
      isCancelled = true;
    };
  }, [catalog?.enabled, catalog?.url]);

  return entries;
}
