import { describe, expect, it } from 'vitest';
import { expandCreateUrl, isNormalizedHttpUrl, normalizeUserUrl } from '../utils/url';

describe('url', () => {
  it('normalizes host-like values to https', () => {
    expect(normalizeUserUrl('example.com/articles')).toBe('https://example.com/articles');
    expect(normalizeUserUrl('//example.com')).toBe('https://example.com');
  });

  it('accepts only http(s) after normalization', () => {
    expect(isNormalizedHttpUrl('example.com')).toBe(true);
    expect(isNormalizedHttpUrl('https://example.com/path')).toBe(true);
    expect(isNormalizedHttpUrl('ftp://example.com')).toBe(false);
    expect(isNormalizedHttpUrl('not a url')).toBe(false);
    expect(isNormalizedHttpUrl('')).toBe(false);
  });

  it('expandCreateUrl returns ok for host-like and http(s) urls', () => {
    expect(expandCreateUrl('example.com/articles')).toEqual({
      ok: 'https://example.com/articles',
    });
    expect(expandCreateUrl('https://example.com/path')).toEqual({
      ok: 'https://example.com/path',
    });
  });

  it('expandCreateUrl maps empty and invalid inputs', () => {
    expect(expandCreateUrl('')).toEqual({ error: 'empty' });
    expect(expandCreateUrl('   ')).toEqual({ error: 'empty' });
    expect(expandCreateUrl('ftp://example.com')).toEqual({ error: 'invalid' });
    expect(expandCreateUrl('not a url')).toEqual({ error: 'invalid' });
  });
});
