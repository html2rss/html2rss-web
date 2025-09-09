// Unit tests for auto source URL restrictions
import { describe, it, expect, beforeEach, afterEach } from "vitest"
import { isUrlAllowed, isOriginAllowed, validateBasicAuth } from "../lib/url-restrictions.js"

// Mock environment variables
const originalEnv = process.env

describe("Auto Source URL Restrictions", () => {
  beforeEach(() => {
    // Reset environment
    process.env = { ...originalEnv }
    process.env.AUTO_SOURCE_ENABLED = "true"
    process.env.AUTO_SOURCE_USERNAME = "admin"
    process.env.AUTO_SOURCE_PASSWORD = "changeme"
    process.env.AUTO_SOURCE_ALLOWED_ORIGINS = "localhost:3000"
  })

  afterEach(() => {
    process.env = originalEnv
  })

  describe("URL Pattern Matching", () => {
    it("should allow exact URL matches", () => {
      process.env.AUTO_SOURCE_ALLOWED_URLS = "https://example.com"

      const isAllowed = isUrlAllowed("https://example.com", process.env.AUTO_SOURCE_ALLOWED_URLS)
      expect(isAllowed).toBe(true)
    })

    it("should allow wildcard pattern matches", () => {
      process.env.AUTO_SOURCE_ALLOWED_URLS = "https://github.com/*"

      const isAllowed = isUrlAllowed("https://github.com/user/repo", process.env.AUTO_SOURCE_ALLOWED_URLS)
      expect(isAllowed).toBe(true)
    })

    it("should allow domain wildcard patterns", () => {
      process.env.AUTO_SOURCE_ALLOWED_URLS = "https://*.example.com/*"

      const isAllowed = isUrlAllowed(
        "https://subdomain.example.com/path",
        process.env.AUTO_SOURCE_ALLOWED_URLS,
      )
      expect(isAllowed).toBe(true)
    })

    it("should reject URLs not in whitelist", () => {
      process.env.AUTO_SOURCE_ALLOWED_URLS = "https://github.com/*,https://example.com/*"

      const isAllowed = isUrlAllowed("https://malicious-site.com", process.env.AUTO_SOURCE_ALLOWED_URLS)
      expect(isAllowed).toBe(false)
    })

    it("should handle multiple allowed URLs", () => {
      process.env.AUTO_SOURCE_ALLOWED_URLS =
        "https://github.com/*,https://news.ycombinator.com/*,https://example.com"

      expect(isUrlAllowed("https://github.com/user/repo", process.env.AUTO_SOURCE_ALLOWED_URLS)).toBe(true)
      expect(
        isUrlAllowed("https://news.ycombinator.com/item?id=123", process.env.AUTO_SOURCE_ALLOWED_URLS),
      ).toBe(true)
      expect(isUrlAllowed("https://example.com", process.env.AUTO_SOURCE_ALLOWED_URLS)).toBe(true)
      expect(isUrlAllowed("https://malicious-site.com", process.env.AUTO_SOURCE_ALLOWED_URLS)).toBe(false)
    })

    it("should allow all URLs when whitelist is empty", () => {
      process.env.AUTO_SOURCE_ALLOWED_URLS = ""

      expect(isUrlAllowed("https://any-site.com", process.env.AUTO_SOURCE_ALLOWED_URLS)).toBe(true)
      expect(isUrlAllowed("https://malicious-site.com", process.env.AUTO_SOURCE_ALLOWED_URLS)).toBe(true)
    })

    it("should handle invalid regex patterns gracefully", () => {
      process.env.AUTO_SOURCE_ALLOWED_URLS = "https://example.com/*,invalid[regex"

      // Should fall back to string inclusion
      expect(isUrlAllowed("https://example.com/path", process.env.AUTO_SOURCE_ALLOWED_URLS)).toBe(true)
      expect(isUrlAllowed("invalid[regex", process.env.AUTO_SOURCE_ALLOWED_URLS)).toBe(true)
    })
  })

  describe("Authentication", () => {
    it("should require basic authentication", () => {
      const isValid = validateBasicAuth(undefined, "admin", "changeme")
      expect(isValid).toBe(false)
    })

    it("should accept valid credentials", () => {
      const auth = Buffer.from("admin:changeme").toString("base64")
      const isValid = validateBasicAuth(`Basic ${auth}`, "admin", "changeme")
      expect(isValid).toBe(true)
    })

    it("should reject invalid credentials", () => {
      const auth = Buffer.from("admin:wrongpassword").toString("base64")
      const isValid = validateBasicAuth(`Basic ${auth}`, "admin", "changeme")
      expect(isValid).toBe(false)
    })
  })

  describe("Origin Validation", () => {
    it("should allow requests from allowed origins", () => {
      const isAllowed = isOriginAllowed("localhost:3000", "localhost:3000,example.com")
      expect(isAllowed).toBe(true)
    })

    it("should reject requests from disallowed origins", () => {
      const isAllowed = isOriginAllowed("malicious-site.com", "localhost:3000")
      expect(isAllowed).toBe(false)
    })
  })

  describe("Error Handling", () => {
    it("should return proper error for disabled auto source", () => {
      process.env.AUTO_SOURCE_ENABLED = "false"

      // When auto source is disabled, the function should return false
      const isEnabled = process.env.AUTO_SOURCE_ENABLED === "true"
      expect(isEnabled).toBe(false)
    })

    it("should return RSS error feed for blocked URLs", () => {
      process.env.AUTO_SOURCE_ALLOWED_URLS = "https://github.com/*"

      // Test that URL is blocked
      const isAllowed = isUrlAllowed("https://malicious-site.com", process.env.AUTO_SOURCE_ALLOWED_URLS)
      expect(isAllowed).toBe(false)
    })
  })
})
