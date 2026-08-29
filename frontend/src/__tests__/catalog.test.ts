import { describe, expect, it } from 'vitest';
import { catalogFeedHref, findCatalogEntries, parseCatalog, selectStarterFeeds } from '../catalog';
import type { CatalogEntry } from '../catalog';
import { UNKNOWN_LAST_RESULT } from '../catalog';

const baseEntry = (
  overrides: Partial<CatalogEntry> & Pick<CatalogEntry, 'id' | 'channelUrl'>
): CatalogEntry => ({
  path: `/${overrides.id}.rss`,
  title: overrides.title ?? overrides.id,
  description: overrides.description ?? '',
  parameterDefaults: overrides.parameterDefaults ?? {},
  lastResult: overrides.lastResult ?? UNKNOWN_LAST_RESULT,
  ...overrides,
});

describe('findCatalogEntries', () => {
  const mundo = baseEntry({
    id: 'bbc.com/mundo',
    channelUrl: 'https://www.bbc.com/mundo',
    title: 'BBC — Mundo',
    description: 'Spanish-language news from BBC Mundo.',
  });
  const sounds = baseEntry({
    id: 'bbc.co.uk/available_episodes',
    channelUrl: 'https://www.bbc.co.uk/programmes/%<id>s/episodes/player',
    title: 'BBC Sounds — Programme episodes',
    description: 'Available episodes for a BBC programme on Sounds.',
    parameterDefaults: { id: 'b006wkfp' },
  });
  const anthropic = baseEntry({
    id: 'anthropic.com/news',
    channelUrl: 'https://www.anthropic.com/news',
    title: 'Anthropic — News',
  });

  it('returns BBC text hits including Sounds with defaults href', () => {
    const hits = findCatalogEntries('bbc', [mundo, sounds, anthropic]);
    expect(hits.map((entry) => entry.id)).toEqual(['bbc.co.uk/available_episodes', 'bbc.com/mundo']);
    expect(findCatalogEntries('BBC', [mundo, sounds]).map((entry) => entry.id)).toEqual([
      'bbc.co.uk/available_episodes',
      'bbc.com/mundo',
    ]);
    expect(catalogFeedHref(sounds)).toBe('/bbc.co.uk/available_episodes.rss?id=b006wkfp');
    expect(catalogFeedHref(mundo)).toBe('/bbc.com/mundo.rss');
  });

  it('matches URL equivalence across www, scheme, and case', () => {
    expect(findCatalogEntries('anthropic.com/news', [anthropic]).map((entry) => entry.id)).toEqual([
      'anthropic.com/news',
    ]);
    expect(
      findCatalogEntries('https://www.anthropic.com/news/', [anthropic]).map((entry) => entry.id)
    ).toEqual(['anthropic.com/news']);
    expect(
      findCatalogEntries('HTTPS://WWW.ANTHROPIC.COM/NEWS', [anthropic]).map((entry) => entry.id)
    ).toEqual(['anthropic.com/news']);
  });

  it('matches bare host to all entries on that host key', () => {
    expect(findCatalogEntries('bbc.com', [mundo, sounds]).map((entry) => entry.id)).toEqual([
      'bbc.com/mundo',
    ]);
  });

  it('includes parameterized entries and returns empty below min length', () => {
    expect(findCatalogEntries('b', [mundo])).toEqual([]);
    expect(findCatalogEntries('available_episodes', [sounds]).map((entry) => entry.id)).toEqual([
      'bbc.co.uk/available_episodes',
    ]);
  });

  it('caps results at 5 and prefers URL hits before text hits', () => {
    const many = Array.from({ length: 8 }, (_, index) =>
      baseEntry({
        id: `news.example/feed-${index}`,
        channelUrl: `https://news.example/feed-${index}`,
        title: `News item ${index}`,
      })
    );
    const exact = baseEntry({
      id: 'exact.example/path',
      channelUrl: 'https://exact.example/path',
      title: 'Unrelated',
    });
    const hits = findCatalogEntries('exact.example/path', [exact, ...many]);
    expect(hits[0]?.id).toBe('exact.example/path');
    expect(findCatalogEntries('news', many)).toHaveLength(5);
  });

  it('demotes empty/error text hits below ok/unknown', () => {
    const failing = baseEntry({
      id: 'bbc.com/broken',
      channelUrl: 'https://www.bbc.com/broken',
      title: 'BBC Broken',
      lastResult: { state: 'error', code: 'UPSTREAM', at: '2026-08-29T08:00:00Z' },
    });
    const hits = findCatalogEntries('bbc', [failing, mundo]);
    expect(hits.map((entry) => entry.id)).toEqual(['bbc.com/mundo', 'bbc.com/broken']);
  });
});

describe('parseCatalog', () => {
  it('maps v2 wire rows with last_result and meta.starters', () => {
    const snapshot = parseCatalog({
      data: {
        configs: [
          {
            id: 'anthropic.com/news',
            path: '/anthropic.com/news.rss',
            channel: { url: 'https://www.anthropic.com/news' },
            directory: { title: 'Anthropic — News', summary: 'Announcements.' },
            parameters: { schema: {}, defaults: {} },
            last_result: { state: 'unknown' },
          },
          {
            id: 'bbc.co.uk/available_episodes',
            path: '/bbc.co.uk/available_episodes.rss',
            channel: { url: 'https://www.bbc.co.uk/programmes/%<id>s/episodes/player' },
            directory: { title: 'BBC Sounds — Programme episodes', summary: 'Episodes.' },
            parameters: { schema: { id: { type: 'string' } }, defaults: { id: 'b006wkfp' } },
            last_result: { state: 'ok', at: '2026-08-29T08:00:00Z' },
          },
          { id: 'broken' },
        ],
      },
      meta: {
        total: 2,
        catalog_version: 2,
        starters: ['bbc.co.uk/available_episodes', 'anthropic.com/news'],
      },
    });

    expect(snapshot.starters).toEqual(['bbc.co.uk/available_episodes', 'anthropic.com/news']);
    expect(snapshot.entries).toEqual([
      {
        id: 'anthropic.com/news',
        path: '/anthropic.com/news.rss',
        title: 'Anthropic — News',
        description: 'Announcements.',
        channelUrl: 'https://www.anthropic.com/news',
        parameterDefaults: {},
        lastResult: { state: 'unknown' },
      },
      {
        id: 'bbc.co.uk/available_episodes',
        path: '/bbc.co.uk/available_episodes.rss',
        title: 'BBC Sounds — Programme episodes',
        description: 'Episodes.',
        channelUrl: 'https://www.bbc.co.uk/programmes/%<id>s/episodes/player',
        parameterDefaults: { id: 'b006wkfp' },
        lastResult: { state: 'ok', at: '2026-08-29T08:00:00Z' },
      },
    ]);
  });

  it('fail-closes on catalog_version 1', () => {
    expect(
      parseCatalog({
        data: { configs: [{ id: 'x', path: '/x.rss', channel: { url: 'https://x' } }] },
        meta: { total: 1, catalog_version: 1 },
      })
    ).toEqual({ entries: [], starters: [] });
  });
});

describe('selectStarterFeeds', () => {
  it('maps meta.starters ids onto entries', () => {
    const fao = baseEntry({ id: 'fao.org/newsroom', channelUrl: 'https://fao.example' });
    const other = baseEntry({ id: 'other.com/feed', channelUrl: 'https://other.example' });
    expect(selectStarterFeeds([other, fao], ['fao.org/newsroom']).map((entry) => entry.id)).toEqual([
      'fao.org/newsroom',
    ]);
  });

  it('falls back to last_result ranking and skips failing when alternatives exist', () => {
    const ok = baseEntry({
      id: 'ok.com/feed',
      channelUrl: 'https://ok.example',
      lastResult: { state: 'ok' },
    });
    const failing = baseEntry({
      id: 'bad.com/feed',
      channelUrl: 'https://bad.example',
      lastResult: { state: 'error', code: 'X' },
    });
    const unknown = baseEntry({ id: 'cold.com/feed', channelUrl: 'https://cold.example' });
    expect(selectStarterFeeds([failing, unknown, ok], []).map((entry) => entry.id)).toEqual([
      'ok.com/feed',
      'cold.com/feed',
    ]);
  });
});
