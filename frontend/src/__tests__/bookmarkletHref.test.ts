import { describe, expect, it } from 'vitest';
import { buildBookmarkletHref } from '../routes/bookmarkletHref';

describe('buildBookmarkletHref', () => {
  it('builds a javascript assign to the create route with encoded current href', () => {
    const href = buildBookmarkletHref('http://localhost:3000/');
    expect(href).toBe(
      'javascript:window.location.assign("http://localhost:3000/#/create?url="+encodeURIComponent(window.location.href));'
    );
    expect(href).not.toContain('%27+encodeURIComponent');
  });

  it('returns a hash placeholder when window is unavailable and no base is given', () => {
    expect(buildBookmarkletHref()).toBe('#');
  });
});
