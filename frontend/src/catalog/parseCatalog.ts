import type { CatalogEntry, CatalogSnapshot, LastResult, LastResultState } from './types';

const SUPPORTED_CATALOG_VERSION = 2;
const STARTER_LIMIT = 3;

interface CatalogWireEntry {
  id?: unknown;
  path?: unknown;
  channel?: { url?: unknown };
  directory?: { title?: unknown; summary?: unknown };
  parameters?: { defaults?: unknown };
  last_result?: unknown;
}

interface CatalogEnvelope {
  data?: { configs?: unknown };
  meta?: { catalog_version?: unknown; starters?: unknown };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function asString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value : undefined;
}

function parseParameterDefaults(value: unknown): Readonly<Record<string, string>> {
  if (!isRecord(value)) return {};

  const defaults: Record<string, string> = {};
  for (const [key, raw] of Object.entries(value)) {
    if (typeof raw === 'string') defaults[key] = raw;
  }
  return defaults;
}

const LAST_RESULT_STATES = new Set<LastResultState>(['ok', 'empty', 'error', 'unknown']);

function parseLastResult(value: unknown): LastResult | undefined {
  if (!isRecord(value)) return undefined;
  const state = value.state;
  if (typeof state !== 'string' || !LAST_RESULT_STATES.has(state as LastResultState)) {
    return undefined;
  }
  const code = value.code;
  if (!(code === null || typeof code === 'string' || code === undefined)) return undefined;
  const at = value.at;
  if (!(at === null || typeof at === 'string' || at === undefined)) return undefined;
  return {
    state: state as LastResultState,
    ...(typeof code === 'string' && { code }),
    ...(typeof at === 'string' && { at }),
  };
}

function parseStarterIds(value: unknown): readonly string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((id): id is string => typeof id === 'string' && id.trim().length > 0);
}

function isFailingState(state: LastResultState): boolean {
  return state === 'empty' || state === 'error';
}

function starterRank(entry: CatalogEntry): number {
  switch (entry.lastResult.state) {
    case 'ok': {
      return 0;
    }
    case 'unknown': {
      return 1;
    }
    case 'empty': {
      return 2;
    }
    case 'error': {
      return 3;
    }
    default: {
      return 4;
    }
  }
}

/**
 * Maps a catalog API envelope to domain entries + meta.starters.
 * Fail-closed on catalog_version other than 2; invalid rows are dropped.
 */
export function parseCatalog(payload: unknown): CatalogSnapshot {
  if (!isRecord(payload)) return { entries: [], starters: [] };
  const envelope = payload as CatalogEnvelope;
  if (envelope.meta?.catalog_version !== SUPPORTED_CATALOG_VERSION) {
    return { entries: [], starters: [] };
  }

  const configs = envelope.data?.configs;
  if (!Array.isArray(configs)) return { entries: [], starters: parseStarterIds(envelope.meta?.starters) };

  const entries: CatalogEntry[] = [];
  for (const row of configs) {
    if (!isRecord(row)) continue;
    const wire = row as CatalogWireEntry;
    const id = asString(wire.id);
    const path = asString(wire.path);
    const channelUrl = asString(wire.channel?.url);
    const lastResult = parseLastResult(wire.last_result);
    if (!id || !path || !channelUrl || !lastResult) continue;

    entries.push({
      id,
      path,
      title: asString(wire.directory?.title) ?? id,
      description: asString(wire.directory?.summary) ?? '',
      channelUrl,
      parameterDefaults: parseParameterDefaults(wire.parameters?.defaults),
      lastResult,
    });
  }

  return { entries, starters: parseStarterIds(envelope.meta?.starters) };
}

/**
 * @deprecated Prefer {@link parseCatalog}; kept as entries-only adapter.
 */
export function parseCatalogEntries(payload: unknown): CatalogEntry[] {
  return parseCatalog(payload).entries;
}

/**
 * Maps server `meta.starters` to entries. Fallback ranks by last_result
 * (ok → unknown → failing) when starter ids are missing or unmatched.
 */
export function selectStarterFeeds(
  entries: readonly CatalogEntry[],
  starterIds: readonly string[] = []
): CatalogEntry[] {
  if (starterIds.length > 0) {
    const selected = starterIds
      .map((id) => entries.find((entry) => entry.id === id))
      .filter((entry): entry is CatalogEntry => Boolean(entry));
    if (selected.length > 0) return selected;
  }

  const preferred = entries.filter((entry) => !isFailingState(entry.lastResult.state));
  const pool = preferred.length > 0 ? preferred : entries;
  return (
    [...pool]
      // eslint-disable-next-line unicorn/no-array-sort -- TS lib predates Array#toSorted
      .sort((a, b) => {
        const rank = starterRank(a) - starterRank(b);
        return rank === 0 ? a.id.localeCompare(b.id) : rank;
      })
      .slice(0, STARTER_LIMIT)
  );
}
