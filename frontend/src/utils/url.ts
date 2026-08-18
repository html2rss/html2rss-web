const SCHEME_PATTERN = /^[a-z][\d+.a-z-]*:\/\//i;
const HOST_LIKE_PATTERN =
  /^(localhost(?::\d+)?|(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?|(?:[\da-z-]+\.)+[a-z]{2,}(?::\d+)?)(?:[#/?].*)?$/i;

export function normalizeUserUrl(rawValue: string): string {
  const value = rawValue.trim();
  if (!value) return '';

  if (value.startsWith('//')) return `https:${value}`;
  if (SCHEME_PATTERN.test(value)) return value;
  if (HOST_LIKE_PATTERN.test(value)) return `https://${value}`;

  return value;
}

export function isNormalizedHttpUrl(rawValue: string): boolean {
  const normalized = normalizeUserUrl(rawValue);
  if (!normalized) return false;

  try {
    const url = new URL(normalized);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

/** Sole create-time URL expansion: normalize + http(s) gate. */
export type ExpandCreateUrlResult = { ok: string } | { error: 'empty' | 'invalid' };

export function expandCreateUrl(raw: string): ExpandCreateUrlResult {
  const normalized = normalizeUserUrl(raw);
  if (!normalized) return { error: 'empty' };
  if (!isNormalizedHttpUrl(normalized)) return { error: 'invalid' };
  return { ok: normalized };
}
