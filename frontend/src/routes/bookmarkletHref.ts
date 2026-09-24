import { buildAppRouteHref } from './appRoute';

/**
 * Builds the `javascript:` bookmarklet href that opens create with the current page URL.
 * @param baseHref - Origin used for the create route (defaults to the current location).
 * @returns Bookmarklet href, or `#` when `window` is unavailable.
 */
export function buildBookmarkletHref(baseHref?: string): string {
  if (globalThis.window === undefined && baseHref === undefined) return '#';

  const createHref = buildAppRouteHref({ kind: 'create' }, baseHref);
  const targetPrefix = `${createHref}?url=`;
  return `javascript:window.location.assign(${JSON.stringify(targetPrefix)}+encodeURIComponent(window.location.href));`;
}
