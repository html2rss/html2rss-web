// URL restriction utilities for auto source
/**
 * Escape special regex characters in a string
 * @param {string} string - String to escape
 * @returns {string} - Escaped string safe for regex
 */
function escapeRegex(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Validate URL format and scheme using browser's built-in URL constructor
 * @param {string} url - URL to validate
 * @returns {boolean} - True if URL is valid and allowed, false otherwise
 */
export function validUrl(url) {
  if (!url || typeof url !== 'string' || url.length === 0) {
    return false;
  }

  try {
    const urlObj = new URL(url);

    // Only allow HTTP and HTTPS schemes
    if (!['http:', 'https:'].includes(urlObj.protocol)) {
      return false;
    }

    // Must have a hostname
    if (!urlObj.hostname || urlObj.hostname.length === 0) {
      return false;
    }

    // Block IP addresses for security (both IPv4 and IPv6)
    if (/^\d+\.\d+\.\d+\.\d+$/.test(urlObj.hostname)) {
      // IPv4
      return false;
    }
    if (/^\[.*\]$/.test(urlObj.hostname)) {
      // IPv6
      return false;
    }

    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Check if a URL is allowed based on the allowed URLs configuration
 * @param {string} url - The URL to check
 * @param {string} allowedUrlsEnv - Comma-separated list of allowed URL patterns
 * @returns {boolean} - True if URL is allowed, false otherwise
 */
export function isUrlAllowed(url, allowedUrlsEnv) {
  const allowedUrls = allowedUrlsEnv ? allowedUrlsEnv.split(',').map((u) => u.trim()) : [];

  if (allowedUrls.length === 0) return true;

  return allowedUrls.some((allowedUrl) => {
    try {
      // Escape special regex characters, then convert wildcards to regex
      const escapedPattern = escapeRegex(allowedUrl).replace(/\\\*/g, '.*');
      const allowedPattern = new RegExp(`^${escapedPattern}$`);
      return allowedPattern.test(url);
    } catch {
      return url.includes(allowedUrl);
    }
  });
}

/**
 * Check if an origin is allowed based on the allowed origins configuration
 * @param {string} origin - The origin to check
 * @param {string} allowedOriginsEnv - Comma-separated list of allowed origins
 * @returns {boolean} - True if origin is allowed, false otherwise
 */
export function isOriginAllowed(origin, allowedOriginsEnv) {
  const allowedOrigins = (allowedOriginsEnv || '')
    .split(',')
    .map((o) => o.trim())
    .filter((o) => o.length > 0);

  if (allowedOrigins.length === 0) return true;

  return allowedOrigins.includes(origin);
}

/**
 * Validate and decode Base64 string safely
 * @param {string} encodedString - Base64 encoded string
 * @returns {string|null} - Decoded string if valid, null if invalid
 */
export function validateAndDecodeBase64(encodedString) {
  if (!encodedString || typeof encodedString !== 'string' || encodedString.length === 0) {
    return null;
  }

  // Check if string contains only valid Base64 characters
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(encodedString)) {
    return null;
  }

  try {
    return Buffer.from(encodedString, 'base64').toString();
  } catch (error) {
    return null;
  }
}

/**
 * Validate basic authentication credentials
 * @param {string} authHeader - The Authorization header value
 * @param {string} expectedUsername - Expected username
 * @param {string} expectedPassword - Expected password
 * @returns {boolean} - True if credentials are valid, false otherwise
 */
export function validateBasicAuth(authHeader, expectedUsername, expectedPassword) {
  if (!authHeader || !authHeader.startsWith('Basic ')) {
    return false;
  }

  const credentials = validateAndDecodeBase64(authHeader.slice(6));
  if (!credentials) return false;

  const colonIndex = credentials.indexOf(':');
  if (colonIndex === -1) return false;

  const username = credentials.slice(0, colonIndex);
  const password = credentials.slice(colonIndex + 1);

  return username === expectedUsername && password === expectedPassword;
}
