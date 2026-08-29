import { useEffect, useState } from 'preact/hooks';
import type { ApiMetadataRecord } from '../api/contracts';
import { parseCatalog } from './parseCatalog';
import type { CatalogEntry } from './types';

export type CatalogHookState = {
  entries: CatalogEntry[];
  starters: readonly string[];
};

const EMPTY: CatalogHookState = { entries: [], starters: [] };

/**
 * Loads catalog entries and meta.starters when the instance catalog is enabled.
 */
export function useCatalogEntries(metadata?: ApiMetadataRecord): CatalogHookState {
  const [snapshot, setSnapshot] = useState<CatalogHookState>(EMPTY);
  const catalog = metadata?.instance.catalog;

  useEffect(() => {
    if (!catalog?.enabled || !catalog.url) {
      setSnapshot(EMPTY);
      return;
    }

    let isCancelled = false;

    const load = async () => {
      try {
        const response = await fetch(catalog.url, { headers: { Accept: 'application/json' } });
        if (!response.ok) {
          if (!isCancelled) setSnapshot(EMPTY);
          return;
        }

        const payload: unknown = await response.json();
        if (isCancelled) return;
        const parsed = parseCatalog(payload);
        setSnapshot({ entries: parsed.entries, starters: parsed.starters });
      } catch {
        if (!isCancelled) setSnapshot(EMPTY);
      }
    };

    load();
    return () => {
      isCancelled = true;
    };
  }, [catalog?.enabled, catalog?.url]);

  return snapshot;
}
