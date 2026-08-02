import { describe, expect, it } from 'vitest';
import { isNormalizedHttpUrl, normalizeUserUrl } from '../utils/url';

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
});
