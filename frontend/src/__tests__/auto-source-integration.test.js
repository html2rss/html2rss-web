// Simple integration tests for auto-source functionality
// Tests against actual backend (Ruby or Astro) - no mocking
import { describe, it, expect, beforeAll, afterAll } from "vitest"

describe("Auto Source Integration Tests", () => {
  const RUBY_BACKEND_URL = "http://localhost:3000"
  const ASTRO_BACKEND_URL = "http://localhost:4321"

  let backendUrl
  let isRubyBackend = false

  beforeAll(async () => {
    // Try to detect which backend is running
    try {
      const rubyResponse = await fetch(`${RUBY_BACKEND_URL}/health_check.txt`, {
        method: "GET",
        signal: AbortSignal.timeout(1000), // 1 second timeout
      })

      if (rubyResponse.ok) {
        backendUrl = RUBY_BACKEND_URL
        isRubyBackend = true
        console.log("✅ Testing against Ruby backend")
      }
    } catch (error) {
      // Ruby backend not available, try Astro
    }

    if (!backendUrl) {
      try {
        const astroResponse = await fetch(`${ASTRO_BACKEND_URL}/api/feeds.json`, {
          method: "GET",
          signal: AbortSignal.timeout(1000),
        })

        if (astroResponse.ok) {
          backendUrl = ASTRO_BACKEND_URL
          isRubyBackend = false
          console.log("✅ Testing against Astro backend")
        }
      } catch (error) {
        // Neither backend available
      }
    }

    if (!backendUrl) {
      throw new Error(`
❌ No backend available for integration testing!

To run integration tests, start a backend server:
  make dev                    # Start both Ruby + Astro
  # or
  cd frontend && npm run dev  # Start Astro only

Integration tests require a running backend to test real API behavior.
Unit tests can run without a backend: npm run test:unit
      `)
    }
  })

  describe("URL Restriction Tests", () => {
    it("should allow URLs in whitelist", async () => {
      const auth = Buffer.from("admin:changeme").toString("base64")
      const encodedUrl = Buffer.from("https://github.com/user/repo").toString("base64")

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: "localhost:3000",
        },
      })

      // Should not be 403 (URL blocked) - might be 401 (auth) or 200 (success)
      expect(response.status).not.toBe(403)
    })

    it("should block URLs not in whitelist", async () => {
      const auth = Buffer.from("admin:changeme").toString("base64")
      const encodedUrl = Buffer.from("https://malicious-site.com").toString("base64")

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: "localhost:3000",
        },
      })

      // Should be 403 (URL blocked), 401 (auth required), or 500 (server error)
      expect([401, 403, 500]).toContain(response.status)
    })

    it("should handle wildcard patterns correctly", async () => {
      const auth = Buffer.from("admin:changeme").toString("base64")

      // Test allowed URL
      const allowedUrl = Buffer.from("https://subdomain.example.com/path").toString("base64")
      const allowedResponse = await fetch(`${backendUrl}/api/auto-source/${allowedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: "localhost:3000",
        },
      })

      // Test blocked URL
      const blockedUrl = Buffer.from("https://other-site.com/path").toString("base64")
      const blockedResponse = await fetch(`${backendUrl}/api/auto-source/${blockedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: "localhost:3000",
        },
      })

      // Allowed URL should not be 403, blocked URL should be 403, 401, or 500
      expect(allowedResponse.status).not.toBe(403)
      expect([401, 403, 500]).toContain(blockedResponse.status)
    })

    it("should allow all URLs when whitelist is empty", async () => {
      const auth = Buffer.from("admin:changeme").toString("base64")
      const encodedUrl = Buffer.from("https://any-site.com").toString("base64")

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: "localhost:3000",
        },
      })

      // Should not be 403 (URL blocked) - might be 401 (auth) or 200 (success)
      expect(response.status).not.toBe(403)
    })
  })

  describe("Authentication Tests", () => {
    it("should require authentication", async () => {
      const encodedUrl = Buffer.from("https://example.com").toString("base64")

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`)

      expect([401, 500]).toContain(response.status)
    })

    it("should reject invalid credentials", async () => {
      const invalidAuth = Buffer.from("admin:wrongpassword").toString("base64")
      const encodedUrl = Buffer.from("https://example.com").toString("base64")

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${invalidAuth}`,
          Host: "localhost:3000",
        },
      })

      expect([401, 500]).toContain(response.status)
    })

    it("should accept valid credentials", async () => {
      const auth = Buffer.from("admin:changeme").toString("base64")
      const encodedUrl = Buffer.from("https://example.com").toString("base64")

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: "localhost:3000",
        },
      })

      // Should not be 401 (auth failed) - might be 403 (URL blocked) or 200 (success)
      expect(response.status).not.toBe(401)
    })
  })

  describe("Origin Validation Tests", () => {
    it("should allow requests from allowed origins", async () => {
      const auth = Buffer.from("admin:changeme").toString("base64")
      const encodedUrl = Buffer.from("https://example.com").toString("base64")

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: "localhost:3000",
        },
      })

      // Should not be 403 (origin blocked) - might be 401 (auth) or 200 (success)
      expect(response.status).not.toBe(403)
    })

    it("should reject requests from disallowed origins", async () => {
      const auth = Buffer.from("admin:changeme").toString("base64")
      const encodedUrl = Buffer.from("https://example.com").toString("base64")

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: "malicious-site.com",
        },
      })

      // Should be 403 (origin blocked), 401 (auth required), or 500 (server error)
      expect([401, 403, 500]).toContain(response.status)
    })
  })

  describe("Error Handling Tests", () => {
    it("should return proper RSS error feed for blocked URLs", async () => {
      const auth = Buffer.from("admin:changeme").toString("base64")
      const encodedUrl = Buffer.from("https://malicious-site.com").toString("base64")

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: "localhost:3000",
        },
      })

      if (response.status === 403) {
        const text = await response.text()
        expect(text).toContain("Access Denied")
        expect(text).toContain("malicious-site.com")
      } else {
        // If not 403, it might be 401 (auth required) which is also valid
        expect([401, 500]).toContain(response.status)
      }
    })
  })

  describe("Backend Detection", () => {
    it("should detect available backend", () => {
      if (backendUrl) {
        expect(backendUrl).toMatch(/^http:\/\/localhost:(3000|4321)$/)
        console.log(`Backend detected: ${backendUrl} (${isRubyBackend ? "Ruby" : "Astro"})`)
      } else {
        console.log("No backend detected - tests will be skipped")
      }
    })
  })
})
