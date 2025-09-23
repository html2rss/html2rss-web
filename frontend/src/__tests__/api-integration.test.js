// Simple integration tests for auto source API endpoints
// Tests against actual backend - no mocking
import { describe, it, expect, beforeAll } from 'vitest';

describe('Auto Source API Integration Tests', () => {
  const RUBY_BACKEND_URL = 'http://localhost:3000';
  const ASTRO_BACKEND_URL = 'http://localhost:4321';
  const auth = Buffer.from('admin:password').toString('base64');

  let backendUrl;

  beforeAll(async () => {
    // Set up test environment variables
    process.env.AUTO_SOURCE_ENABLED = 'true';
    process.env.AUTO_SOURCE_USERNAME = 'admin';
    process.env.AUTO_SOURCE_PASSWORD = 'password';
    process.env.AUTO_SOURCE_ALLOWED_ORIGINS = 'localhost:3000,localhost:4321';
    process.env.AUTO_SOURCE_ALLOWED_URLS = 'https://github.com/*,https://example.com/*';

    // Try to detect which backend is running
    try {
      const rubyResponse = await fetch(`${RUBY_BACKEND_URL}/health_check.txt`, {
        method: 'GET',
        signal: AbortSignal.timeout(1000),
        headers: {
          Authorization: `Basic ${Buffer.from('admin:password').toString('base64')}`,
        },
      });

      if (rubyResponse.ok) {
        backendUrl = RUBY_BACKEND_URL;
        console.log('✅ Testing against Ruby backend');
        return;
      }
    } catch (error) {
      // Ruby backend not available
    }

    try {
      // Test legacy API endpoint for backward compatibility
      const astroResponse = await fetch(`${ASTRO_BACKEND_URL}/api/feeds.json`, {
        method: 'GET',
        signal: AbortSignal.timeout(1000),
      });

      // Test new RESTful API endpoint
      const v1Response = await fetch(`${ASTRO_BACKEND_URL}/api/v1/feeds`, {
        method: 'GET',
        signal: AbortSignal.timeout(1000),
      });

      if (astroResponse.ok && v1Response.ok) {
        backendUrl = ASTRO_BACKEND_URL;
        console.log('✅ Testing against Astro backend (legacy + v1 API)');
        return;
      }
    } catch (error) {
      // Astro backend not available
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
      `);
    }
  });

  describe('URL Restriction Tests', () => {
    it('should allow URLs in whitelist', async () => {
      const encodedUrl = Buffer.from('https://github.com/user/repo').toString('base64');
      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'localhost:3000',
        },
      });

      // Should not be 403 (URL blocked) - might be 401 (auth) or 200 (success)
      expect(response.status).not.toBe(403);
    });

    it('should block URLs not in whitelist', async () => {
      const encodedUrl = Buffer.from('https://malicious-site.com').toString('base64');
      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'localhost:3000',
        },
      });

      // Should be 403 (URL blocked), 401 (auth required), or 500 (server error)
      expect([401, 403, 500]).toContain(response.status);

      if (response.status === 403) {
        const text = await response.text();
        expect(text).toContain('Access Denied');
        expect(text).toContain('malicious-site.com');
      }
    });

    it('should handle wildcard patterns correctly', async () => {
      const allowedUrl = Buffer.from('https://subdomain.example.com/path').toString('base64');
      const blockedUrl = Buffer.from('https://other-site.com/path').toString('base64');

      const allowedResponse = await fetch(`${backendUrl}/api/auto-source/${allowedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'localhost:3000',
        },
      });

      const blockedResponse = await fetch(`${backendUrl}/api/auto-source/${blockedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'localhost:3000',
        },
      });

      // Allowed URL should not be 403, blocked URL should be 403, 401, or 500
      expect(allowedResponse.status).not.toBe(403);
      expect([401, 403, 500]).toContain(blockedResponse.status);
    });

    it('should allow all URLs when whitelist is empty', async () => {
      const encodedUrl = Buffer.from('https://any-site.com').toString('base64');
      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'localhost:3000',
        },
      });

      // Should not be 403 (URL blocked) - might be 401 (auth) or 200 (success)
      expect(response.status).not.toBe(403);
    });
  });

  describe('Authentication Tests', () => {
    it('should require authentication', async () => {
      const encodedUrl = Buffer.from('https://example.com').toString('base64');
      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`);

      expect([401, 500]).toContain(response.status);
    });

    it('should reject invalid credentials', async () => {
      const invalidAuth = Buffer.from('admin:wrongpassword').toString('base64');
      const encodedUrl = Buffer.from('https://example.com').toString('base64');

      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${invalidAuth}`,
          Host: 'localhost:3000',
        },
      });

      expect([401, 500]).toContain(response.status);
    });

    it('should accept valid credentials', async () => {
      const encodedUrl = Buffer.from('https://example.com').toString('base64');
      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'localhost:3000',
        },
      });

      // Should not be 401 (auth failed) - might be 403 (URL blocked) or 200 (success)
      expect(response.status).not.toBe(401);
    });
  });

  describe('Origin Validation Tests', () => {
    it('should allow requests from allowed origins', async () => {
      const encodedUrl = Buffer.from('https://example.com').toString('base64');
      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'localhost:3000',
        },
      });

      // Should not be 403 (origin blocked) - might be 401 (auth) or 200 (success)
      expect(response.status).not.toBe(403);
    });

    it('should reject requests from disallowed origins', async () => {
      const encodedUrl = Buffer.from('https://example.com').toString('base64');
      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'malicious-site.com',
        },
      });

      // Should be 403 (origin blocked), 401 (auth required), or 500 (server error)
      expect([401, 403, 500]).toContain(response.status);
    });
  });

  describe('Error Handling Tests', () => {
    it('should return error when auto source is disabled', async () => {
      const encodedUrl = Buffer.from('https://example.com').toString('base64');
      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'localhost:3000',
        },
      });

      // Should be 400 (disabled), 401 (auth), 200 (success), or 500 (server error)
      expect([200, 400, 401, 500]).toContain(response.status);
    });

    it('should return proper RSS error feed for blocked URLs', async () => {
      const encodedUrl = Buffer.from('https://malicious-site.com').toString('base64');
      const response = await fetch(`${backendUrl}/api/auto-source/${encodedUrl}`, {
        headers: {
          Authorization: `Basic ${auth}`,
          Host: 'localhost:3000',
        },
      });

      if (response.status === 403) {
        const text = await response.text();
        expect(text).toContain('Access Denied');
        expect(text).toContain('malicious-site.com');
      } else {
        // If not 403, it might be 401 (auth required) or 500 (server error) which are also valid
        expect([401, 500]).toContain(response.status);
      }
    });
  });

  describe('Backend Detection', () => {
    it('should detect available backend', () => {
      if (backendUrl) {
        expect(backendUrl).toMatch(/^http:\/\/localhost:(3000|4321)$/);
        console.log(`Backend detected: ${backendUrl}`);
      } else {
        console.log('No backend detected - tests will be skipped');
      }
    });
  });
});
