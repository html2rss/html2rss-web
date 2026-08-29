/** Closed set mirroring RenderResult status plus never-scraped. */
export type LastResultState = 'ok' | 'empty' | 'error' | 'unknown';

/** Wire/domain last-known scrape projection for a catalog row. */
export interface LastResult {
  state: LastResultState;
  code?: string;
  at?: string;
}

/** Domain catalog entry used for find and starter selection. */
export interface CatalogEntry {
  id: string;
  path: string;
  title: string;
  description: string;
  channelUrl: string;
  /** String defaults from wire `parameters.defaults` (empty when none). */
  parameterDefaults: Readonly<Record<string, string>>;
  lastResult: LastResult;
}

/** Parsed catalog API envelope (catalog_version 2 only). */
export interface CatalogSnapshot {
  entries: CatalogEntry[];
  starters: readonly string[];
}

export const UNKNOWN_LAST_RESULT: LastResult = { state: 'unknown' };
