// Unit tests for URL restrictions functionality
import { describe, it, expect } from 'vitest';
import {
  isUrlAllowed,
  isOriginAllowed,
  validateBasicAuth,
  validateAndDecodeBase64,
  validUrl,
} from '../lib/url-restrictions.js';

describe('URL Restrictions', () => {
  describe('isUrlAllowed', () => {
    it('should allow exact URL matches', () => {
      const allowedUrls = 'https://example.com';
      expect(isUrlAllowed('https://example.com', allowedUrls)).toBe(true);
    });

    it('should reject URLs not in whitelist', () => {
      const allowedUrls = 'https://example.com';
      expect(isUrlAllowed('https://malicious-site.com', allowedUrls)).toBe(false);
    });

    it('should allow wildcard pattern matches', () => {
      const allowedUrls = 'https://github.com/*';
      expect(isUrlAllowed('https://github.com/user/repo', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://github.com/another/user', allowedUrls)).toBe(true);
    });

    it('should reject URLs that do not match wildcard patterns', () => {
      const allowedUrls = 'https://github.com/*';
      expect(isUrlAllowed('https://bitbucket.com/user/repo', allowedUrls)).toBe(false);
    });

    it('should allow domain wildcard patterns', () => {
      const allowedUrls = 'https://*.example.com/*';
      expect(isUrlAllowed('https://subdomain.example.com/path', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://api.example.com/data', allowedUrls)).toBe(true);
    });

    it('should reject URLs that do not match domain wildcard patterns', () => {
      const allowedUrls = 'https://*.example.com/*';
      expect(isUrlAllowed('https://other-site.com/path', allowedUrls)).toBe(false);
    });

    it('should handle multiple allowed URLs', () => {
      const allowedUrls = 'https://github.com/*,https://news.ycombinator.com/*,https://example.com';

      expect(isUrlAllowed('https://github.com/user/repo', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://news.ycombinator.com/item?id=123', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://example.com', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://malicious-site.com', allowedUrls)).toBe(false);
    });

    it('should allow all URLs when whitelist is empty', () => {
      const allowedUrls = '';
      expect(isUrlAllowed('https://any-site.com', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://malicious-site.com', allowedUrls)).toBe(true);
    });

    it('should allow all URLs when whitelist is undefined', () => {
      expect(isUrlAllowed('https://any-site.com', undefined)).toBe(true);
      expect(isUrlAllowed('https://malicious-site.com', undefined)).toBe(true);
    });

    it('should handle invalid regex patterns gracefully', () => {
      const allowedUrls = 'https://example.com/*,invalid[regex';

      // Should fall back to string inclusion for invalid regex
      expect(isUrlAllowed('https://example.com/path', allowedUrls)).toBe(true);
      expect(isUrlAllowed('invalid[regex', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://other-site.com', allowedUrls)).toBe(false);
    });

    it('should handle complex wildcard patterns', () => {
      const allowedUrls = 'https://*.github.com/*/issues,https://api.*.com/v1/*';

      expect(isUrlAllowed('https://api.github.com/user/repo/issues', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://api.example.com/v1/data', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://github.com/user/repo/issues', allowedUrls)).toBe(false);
      expect(isUrlAllowed('https://api.example.com/v2/data', allowedUrls)).toBe(false);
    });

    it('should handle URLs with query parameters and fragments', () => {
      const allowedUrls = 'https://example.com/*';

      expect(isUrlAllowed('https://example.com/path?query=value', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://example.com/path#fragment', allowedUrls)).toBe(true);
      expect(isUrlAllowed('https://example.com/path?query=value#fragment', allowedUrls)).toBe(true);
    });
  });

  describe('isOriginAllowed', () => {
    it('should allow exact origin matches', () => {
      const allowedOrigins = 'localhost:4321,example.com';
      expect(isOriginAllowed('localhost:4321', allowedOrigins)).toBe(true);
      expect(isOriginAllowed('example.com', allowedOrigins)).toBe(true);
    });

    it('should reject origins not in whitelist', () => {
      const allowedOrigins = 'localhost:4321';
      expect(isOriginAllowed('malicious-site.com', allowedOrigins)).toBe(false);
    });

    it('should allow all origins when whitelist is empty', () => {
      const allowedOrigins = '';
      expect(isOriginAllowed('any-origin.com', allowedOrigins)).toBe(true);
    });

    it('should allow all origins when whitelist is undefined', () => {
      expect(isOriginAllowed('any-origin.com', undefined)).toBe(true);
    });

    it('should handle whitespace in allowed origins', () => {
      const allowedOrigins = ' localhost:4321 , example.com ';
      expect(isOriginAllowed('localhost:4321', allowedOrigins)).toBe(true);
      expect(isOriginAllowed('example.com', allowedOrigins)).toBe(true);
    });

    it('should handle empty strings in allowed origins', () => {
      const allowedOrigins = 'localhost:4321,,example.com,';
      expect(isOriginAllowed('localhost:4321', allowedOrigins)).toBe(true);
      expect(isOriginAllowed('example.com', allowedOrigins)).toBe(true);
    });
  });

  describe('validateBasicAuth', () => {
    it('should validate correct credentials', () => {
      const authHeader = 'Basic ' + Buffer.from('admin:changeme').toString('base64');
      expect(validateBasicAuth(authHeader, 'admin', 'changeme')).toBe(true);
    });

    it('should reject incorrect username', () => {
      const authHeader = 'Basic ' + Buffer.from('wronguser:changeme').toString('base64');
      expect(validateBasicAuth(authHeader, 'admin', 'changeme')).toBe(false);
    });

    it('should reject incorrect password', () => {
      const authHeader = 'Basic ' + Buffer.from('admin:wrongpass').toString('base64');
      expect(validateBasicAuth(authHeader, 'admin', 'changeme')).toBe(false);
    });

    it('should reject malformed auth header', () => {
      expect(validateBasicAuth('Bearer token', 'admin', 'changeme')).toBe(false);
      expect(validateBasicAuth('Basic invalid-base64', 'admin', 'changeme')).toBe(false);
      expect(validateBasicAuth('', 'admin', 'changeme')).toBe(false);
      expect(validateBasicAuth(null, 'admin', 'changeme')).toBe(false);
      expect(validateBasicAuth(undefined, 'admin', 'changeme')).toBe(false);
    });

    it('should handle credentials with special characters', () => {
      const authHeader = 'Basic ' + Buffer.from('user:pass:word').toString('base64');
      expect(validateBasicAuth(authHeader, 'user', 'pass:word')).toBe(true);
    });

    it('should handle empty credentials', () => {
      const authHeader = 'Basic ' + Buffer.from(':').toString('base64');
      expect(validateBasicAuth(authHeader, '', '')).toBe(true);
    });
  });

  describe('validateAndDecodeBase64', () => {
    it('should decode valid Base64 strings', () => {
      const validBase64 = Buffer.from('hello world').toString('base64');
      expect(validateAndDecodeBase64(validBase64)).toBe('hello world');
    });

    it('should handle empty string', () => {
      expect(validateAndDecodeBase64('')).toBe(null);
    });

    it('should handle null/undefined input', () => {
      expect(validateAndDecodeBase64(null)).toBe(null);
      expect(validateAndDecodeBase64(undefined)).toBe(null);
    });

    it('should reject invalid Base64 characters', () => {
      expect(validateAndDecodeBase64('hello@world')).toBe(null);
      expect(validateAndDecodeBase64('hello world')).toBe(null);
      expect(validateAndDecodeBase64('hello!world')).toBe(null);
    });

    it('should reject malformed Base64', () => {
      expect(validateAndDecodeBase64('aGVsbG8gd29ybGQ=')).toBe('hello world'); // valid
      expect(validateAndDecodeBase64('aGVsbG8gd29ybGQ')).toBe('hello world'); // missing padding (Node.js is lenient)
      expect(validateAndDecodeBase64('aGVsbG8gd29ybGQ===')).toBe(null); // too much padding
    });

    it('should handle non-string input', () => {
      expect(validateAndDecodeBase64(123)).toBe(null);
      expect(validateAndDecodeBase64({})).toBe(null);
      expect(validateAndDecodeBase64([])).toBe(null);
    });
  });
});
