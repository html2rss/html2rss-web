#!/usr/bin/env node

// Test script for URL restrictions
const https = require('https');
const http = require('http');

const BASE_URL = 'http://localhost:4321';
const AUTH = Buffer.from('admin:changeme').toString('base64');

async function testUrlRestrictions() {
  console.log('🧪 Testing Auto Source URL Restrictions...\n');

  // Test 1: URL in whitelist should be allowed
  console.log('Test 1: URL in whitelist (should be allowed)');
  try {
    const encodedUrl = Buffer.from('https://github.com/user/repo').toString('base64');
    const response = await makeRequest(`/api/auto-source/${encodedUrl}`);
    console.log(`Status: ${response.status}`);
    if (response.status === 403) {
      console.log('❌ FAILED: Allowed URL was blocked');
    } else {
      console.log('✅ PASSED: Allowed URL was accepted');
    }
  } catch (error) {
    console.log(`❌ ERROR: ${error.message}`);
  }

  // Test 2: URL not in whitelist should be blocked
  console.log('\nTest 2: URL not in whitelist (should be blocked)');
  try {
    const encodedUrl = Buffer.from('https://malicious-site.com').toString('base64');
    const response = await makeRequest(`/api/auto-source/${encodedUrl}`);
    console.log(`Status: ${response.status}`);
    if (response.status === 403) {
      console.log('✅ PASSED: Blocked URL was correctly rejected');
    } else {
      console.log('❌ FAILED: Blocked URL was allowed');
    }
  } catch (error) {
    console.log(`❌ ERROR: ${error.message}`);
  }

  // Test 3: Authentication required
  console.log('\nTest 3: Authentication required');
  try {
    const encodedUrl = Buffer.from('https://example.com').toString('base64');
    const response = await makeRequest(`/api/auto-source/${encodedUrl}`, false);
    console.log(`Status: ${response.status}`);
    if (response.status === 401) {
      console.log('✅ PASSED: Authentication correctly required');
    } else {
      console.log('❌ FAILED: Authentication not required');
    }
  } catch (error) {
    console.log(`❌ ERROR: ${error.message}`);
  }

  console.log('\n🏁 URL restriction tests completed!');
}

function makeRequest(path, includeAuth = true) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: 'GET',
      headers: {
        'Host': 'localhost:4321'
      }
    };

    if (includeAuth) {
      options.headers['Authorization'] = `Basic ${AUTH}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.end();
  });
}

// Set environment variables for testing
process.env.AUTO_SOURCE_ENABLED = 'true';
process.env.AUTO_SOURCE_USERNAME = 'admin';
process.env.AUTO_SOURCE_PASSWORD = 'changeme';
process.env.AUTO_SOURCE_ALLOWED_ORIGINS = 'localhost:4321';
process.env.AUTO_SOURCE_ALLOWED_URLS = 'https://github.com/*,https://example.com/*';

testUrlRestrictions().catch(console.error);
