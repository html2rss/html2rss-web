// URL restriction utilities for auto source
/**
 * Check if a URL is allowed based on the allowed URLs configuration
 * @param {string} url - The URL to check
 * @param {string} allowedUrlsEnv - Comma-separated list of allowed URL patterns
 * @returns {boolean} - True if URL is allowed, false otherwise
 */
export function isUrlAllowed(url, allowedUrlsEnv) {
  const allowedUrls = allowedUrlsEnv ? allowedUrlsEnv.split(",").map((u) => u.trim()) : []

  if (allowedUrls.length === 0) return true

  return allowedUrls.some((allowedUrl) => {
    try {
      const allowedPattern = new RegExp(allowedUrl.replace(/\*/g, ".*"))
      return allowedPattern.test(url)
    } catch {
      return url.includes(allowedUrl)
    }
  })
}

/**
 * Check if an origin is allowed based on the allowed origins configuration
 * @param {string} origin - The origin to check
 * @param {string} allowedOriginsEnv - Comma-separated list of allowed origins
 * @returns {boolean} - True if origin is allowed, false otherwise
 */
export function isOriginAllowed(origin, allowedOriginsEnv) {
  const allowedOrigins = (allowedOriginsEnv || "")
    .split(",")
    .map((o) => o.trim())
    .filter((o) => o.length > 0)

  if (allowedOrigins.length === 0) return true

  return allowedOrigins.includes(origin)
}

/**
 * Validate basic authentication credentials
 * @param {string} authHeader - The Authorization header value
 * @param {string} expectedUsername - Expected username
 * @param {string} expectedPassword - Expected password
 * @returns {boolean} - True if credentials are valid, false otherwise
 */
export function validateBasicAuth(authHeader, expectedUsername, expectedPassword) {
  if (!authHeader || !authHeader.startsWith("Basic ")) {
    return false
  }

  const credentials = Buffer.from(authHeader.slice(6), "base64").toString()
  const colonIndex = credentials.indexOf(":")
  if (colonIndex === -1) return false

  const username = credentials.slice(0, colonIndex)
  const password = credentials.slice(colonIndex + 1)

  return username === expectedUsername && password === expectedPassword
}
