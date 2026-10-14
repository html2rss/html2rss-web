import { describe, expect, it } from 'vitest';
import { buildDirectoryIssueBody, buildDirectoryIssueHref } from '../studio/directoryHandoff';

describe('directoryHandoff', () => {
  it('builds a GitHub issue URL with channel, selectors, and blank directory fields', () => {
    const channelUrl = 'https://example.com/articles';
    const selectorsYaml = `channel:\n  url: ${channelUrl}\nselectors:\n  items:\n    selector: article\n`;
    const href = buildDirectoryIssueHref(channelUrl, selectorsYaml);
    const url = new URL(href);

    expect(url.origin + url.pathname).toBe('https://github.com/html2rss/html2rss-configs/issues/new');
    expect(url.searchParams.get('title')).toBe(`Add feed: ${channelUrl}`);

    const body = url.searchParams.get('body') ?? '';
    expect(body).toContain('channel:');
    expect(body).toContain(`url: ${channelUrl}`);
    expect(body).toContain('selectors:');
    expect(body).toContain('selector: article');
    expect(body).toContain('directory:');
    expect(body).toContain('title:');
    expect(body).toContain('topics:');
    expect(body).not.toMatch(/access.?token/i);
    expect(body).not.toMatch(/feed.?token/i);
    expect(body).not.toContain('Authorization');
  });

  it('falls back to channel.url when studio yaml is empty', () => {
    const body = buildDirectoryIssueBody('https://example.com/list', '');
    expect(body).toBe(
      'channel:\n  url: https://example.com/list\nselectors: {}\n\ndirectory:\n  title:\n  topics:\n'
    );
  });
});
