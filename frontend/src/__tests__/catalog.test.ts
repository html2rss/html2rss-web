import { describe, expect, it } from 'vitest';
import { catalogFeedHref, findCatalogEntries, parseCatalogEntries, selectStarterFeeds } from '../catalog';
import type { CatalogEntry } from '../catalog';

const baseEntry = (
  overrides: Partial<CatalogEntry> & Pick<CatalogEntry, 'id' | 'channelUrl'>
): CatalogEntry => ({
  path: `/${overrides.id}.rss`,
  title: overrides.title ?? overrides.id,
  description: overrides.description ?? '',
  parameterDefaults: overrides.parameterDefaults ?? {},
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
});

describe('parseCatalogEntries', () => {
  it('maps wire rows with parameterDefaults and drops invalid ones', () => {
    const entries = parseCatalogEntries({
      data: {
        configs: [
          {
            id: 'anthropic.com/news',
            path: '/anthropic.com/news.rss',
            channel: { url: 'https://www.anthropic.com/news' },
            directory: { title: 'Anthropic — News', summary: 'Announcements.' },
            parameters: { schema: {}, defaults: {} },
          },
          {
            id: 'bbc.co.uk/available_episodes',
            path: '/bbc.co.uk/available_episodes.rss',
            channel: { url: 'https://www.bbc.co.uk/programmes/%<id>s/episodes/player' },
            directory: { title: 'BBC Sounds — Programme episodes', summary: 'Episodes.' },
            parameters: { schema: { id: { type: 'string' } }, defaults: { id: 'b006wkfp' } },
          },
          { id: 'broken' },
        ],
      },
    });

    expect(entries).toEqual([
      {
        id: 'anthropic.com/news',
        path: '/anthropic.com/news.rss',
        title: 'Anthropic — News',
        description: 'Announcements.',
        channelUrl: 'https://www.anthropic.com/news',
        parameterDefaults: {},
      },
      {
        id: 'bbc.co.uk/available_episodes',
        path: '/bbc.co.uk/available_episodes.rss',
        title: 'BBC Sounds — Programme episodes',
        description: 'Episodes.',
        channelUrl: 'https://www.bbc.co.uk/programmes/%<id>s/episodes/player',
        parameterDefaults: { id: 'b006wkfp' },
      },
    ]);
  });
});

describe('selectStarterFeeds', () => {
  it('prefers known starter ids then falls back to the first three', () => {
    const azure = baseEntry({ id: 'microsoft.com/azure-products', channelUrl: 'https://azure.example' });
    const other = baseEntry({ id: 'other.com/feed', channelUrl: 'https://other.example' });
    expect(selectStarterFeeds([other, azure]).map((entry) => entry.id)).toEqual([
      'microsoft.com/azure-products',
    ]);
    expect(selectStarterFeeds([other]).map((entry) => entry.id)).toEqual(['other.com/feed']);
  });

  it('exports STARTER_FEED_IDS for lockstep assertions', async () => {
    const { STARTER_FEED_IDS } = await import('../catalog');
    expect(STARTER_FEED_IDS).toEqual([
      'microsoft.com/azure-products',
      'phys.org/weekly',
      'softwareleadweekly.com/issues',
    ]);
  });
});
