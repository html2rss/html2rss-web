import type { CatalogEntry } from './types';

interface CatalogWireEntry {
  id?: unknown;
  path?: unknown;
  channel?: { url?: unknown };
  directory?: { title?: unknown; summary?: unknown };
  parameters?: { defaults?: unknown };
}

interface CatalogEnvelope {
  data?: { configs?: unknown };
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

/**
 * Maps a catalog API envelope to domain entries. Invalid rows are dropped.
 */
export function parseCatalogEntries(payload: unknown): CatalogEntry[] {
  if (!isRecord(payload)) return [];
  const envelope = payload as CatalogEnvelope;
  const configs = envelope.data?.configs;
  if (!Array.isArray(configs)) return [];

  const entries: CatalogEntry[] = [];
  for (const row of configs) {
    if (!isRecord(row)) continue;
    const wire = row as CatalogWireEntry;
    const id = asString(wire.id);
    const path = asString(wire.path);
    const channelUrl = asString(wire.channel?.url);
    if (!id || !path || !channelUrl) continue;

    entries.push({
      id,
      path,
      title: asString(wire.directory?.title) ?? id,
      description: asString(wire.directory?.summary) ?? '',
      channelUrl,
      parameterDefaults: parseParameterDefaults(wire.parameters?.defaults),
    });
  }

  return entries;
}

/**
 * Preferred included-feed starters (empty Create URL / creation-disabled Notice).
 * Keep in lockstep with `Html2rss::Web::Catalog::Merge::STARTER_FEED_IDS`.
 */
export const STARTER_FEED_IDS = [
  'fao.org/newsroom',
  'ftc.gov/press-releases',
  'icrc.org/news',
] as const;

/**
 * Picks up to three starter feeds by preferred id, else the first catalog rows.
 */
export function selectStarterFeeds(entries: readonly CatalogEntry[]): CatalogEntry[] {
  const selected = STARTER_FEED_IDS.map((id) => entries.find((entry) => entry.id === id)).filter(
    (entry): entry is CatalogEntry => Boolean(entry)
  );
  return selected.length > 0 ? selected : entries.slice(0, 3);
}
