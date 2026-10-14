import { useEffect, useState } from 'preact/hooks';
import type { ApiMetadataRecord } from '../api/contracts';
import { requestConfigCatalog } from '../api/http/catalog';
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
  const isCatalogEnabled = metadata?.instance.catalog?.enabled === true;

  useEffect(() => {
    if (!isCatalogEnabled) {
      setSnapshot(EMPTY);
      return;
    }

    let isCancelled = false;

    const load = async () => {
      try {
        const payload = await requestConfigCatalog();
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
  }, [isCatalogEnabled]);

  return snapshot;
}
