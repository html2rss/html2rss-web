import { expandCreateUrl } from '../utils/url';
import type { CatalogEntry } from './types';

const FIND_MIN_LENGTH = 2;
const FIND_CAP = 5;

/**
 * Lowercases hostname and strips one leading `www.`.
 */
function hostKey(hostname: string): string {
  const lower = hostname.toLowerCase();
  return lower.startsWith('www.') ? lower.slice(4) : lower;
}

/**
 * Strips trailing slash on non-root paths.
 */
function stripTrailingSlash(pathname: string): string {
  if (pathname.length > 1 && pathname.endsWith('/')) {
    return pathname.slice(0, -1);
  }
  return pathname;
}

/**
 * Host+path+search key for URL equivalence (scheme ignored, hash dropped).
 * Channel URLs may include Ruby-style placeholders (`%<id>s`); those are
 * replaced with `_` so `URL` can parse.
 */
function equivalenceKey(rawHref: string): string | undefined {
  const sanitized = rawHref.replaceAll(/%<[^>]+>/g, '_').replaceAll(/%\{[^}]+\}/g, '_');
  try {
    const url = new URL(sanitized);
    url.hash = '';
    const host = hostKey(url.hostname);
    const path = stripTrailingSlash(url.pathname);
    return `${host}${path}${url.search}`;
  } catch {
    return undefined;
  }
}

function channelHostKey(channelUrl: string): string | undefined {
  const match = /^https?:\/\/([^/?#]+)/i.exec(channelUrl);
  if (!match?.[1]) return undefined;
  return hostKey(match[1]);
}

function parseExpandedQuery(raw: string): URL | undefined {
  const expanded = expandCreateUrl(raw);
  if (!('ok' in expanded)) return undefined;
  try {
    const url = new URL(expanded.ok);
    url.hash = '';
    return url;
  } catch {
    return undefined;
  }
}

function isBareHostQuery(url: URL): boolean {
  const path = stripTrailingSlash(url.pathname);
  return path === '/' || path === '';
}

function isTextMatch(entry: CatalogEntry, needle: string): boolean {
  const haystacks = [entry.title, entry.description, entry.id, entry.channelUrl];
  return haystacks.some((value) => value.toLowerCase().includes(needle));
}

/**
 * Relative feed href with `parameters.defaults` applied as query params.
 */
export function catalogFeedHref(entry: CatalogEntry): string {
  const parameters = new URLSearchParams(entry.parameterDefaults);
  const query = parameters.toString();
  return query ? `${entry.path}?${query}` : entry.path;
}

/**
 * Finds catalog entries for a create-field query: URL equivalence hits first,
 * then case-insensitive substring text hits. Deduped by `id`, capped at 5.
 */
export function findCatalogEntries(query: string, entries: readonly CatalogEntry[]): readonly CatalogEntry[] {
  const trimmed = query.trim();
  if (trimmed.length < FIND_MIN_LENGTH) return [];

  const needle = trimmed.toLowerCase();
  const queryUrl = parseExpandedQuery(trimmed);
  const queryKey = queryUrl ? equivalenceKey(queryUrl.href) : undefined;
  const queryHost = queryUrl ? hostKey(queryUrl.hostname) : undefined;
  const isBareHost = queryUrl ? isBareHostQuery(queryUrl) : false;

  const urlHits: CatalogEntry[] = [];
  const textHits: CatalogEntry[] = [];
  const seen = new Set<string>();

  const pushUnique = (bucket: CatalogEntry[], entry: CatalogEntry) => {
    if (seen.has(entry.id)) return;
    seen.add(entry.id);
    bucket.push(entry);
  };

  for (const entry of entries) {
    let isUrlHit = false;
    if (queryUrl && queryHost) {
      if (isBareHost) {
        isUrlHit = channelHostKey(entry.channelUrl) === queryHost;
      } else if (queryKey) {
        isUrlHit = equivalenceKey(entry.channelUrl) === queryKey;
      }
    }

    if (isUrlHit) {
      pushUnique(urlHits, entry);
      continue;
    }

    if (isTextMatch(entry, needle)) {
      pushUnique(textHits, entry);
    }
  }

  urlHits.sort((a, b) => a.id.localeCompare(b.id));
  textHits.sort((a, b) => a.id.localeCompare(b.id));
  return [...urlHits, ...textHits].slice(0, FIND_CAP);
}
