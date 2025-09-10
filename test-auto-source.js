#!/usr/bin/env node

// Simple test script for auto-source functionality
// Tests against actual backend - no mocking, no complex setup

const https = require('https');
const http = require('http');

const BACKEND_URLS = [
  'http://localhost:3000',  // Ruby backend
  'http://localhost:4321'   // Astro backend
];

const AUTH = Buffer.from('admin:changeme').toString('base64');

async function testAutoSource() {
  console.log('🧪 Testing Auto Source URL Restrictions...\n');

  // Find available backend
  let backendUrl = null;
  for (const url of BACKEND_URLS) {
    try {
      const response = await makeRequest(`${url}/health_check.txt`).catch(() =>
        makeRequest(`${url}/api/feeds.json`)
      );

      if (response.status === 200) {
        backendUrl = url;
        console.log(`✅ Found backend at ${url}`);
        break;
      }
    } catch (error) {
      // Backend not available
    }
  }

  if (!backendUrl) {
    console.log('❌ No backend available. Please start the server with:');
    console.log('   make dev  (for both Ruby + Astro)');
    console.log('   or');
    console.log('   cd frontend && npm run dev  (for Astro only)');
    return;
  }

  // Test 1: URL in whitelist should be allowed
  console.log('\n📝 Test 1: URL in whitelist (should be allowed)');
  try {
    const encodedUrl = Buffer.from('https://github.com/user/repo').toString('base64');
    const response = await makeRequest(`${backendUrl}/api/auto-source/${encodedUrl}`, {
      'Authorization': `Basic ${AUTH}`,
      'Host': 'localhost:3000'
    });

    console.log(`Status: ${response.status}`);
    if (response.status === 403) {
      console.log('❌ FAILED: Allowed URL was blocked');
    } else if (response.status === 401) {
      console.log('⚠️  SKIPPED: Authentication required (expected)');
    } else {
      console.log('✅ PASSED: Allowed URL was accepted');
    }
  } catch (error) {
    console.log(`❌ ERROR: ${error.message}`);
  }

  // Test 2: URL not in whitelist should be blocked
  console.log('\n📝 Test 2: URL not in whitelist (should be blocked)');
  try {
    const encodedUrl = Buffer.from('https://malicious-site.com').toString('base64');
    const response = await makeRequest(`${backendUrl}/api/auto-source/${encodedUrl}`, {
      'Authorization': `Basic ${AUTH}`,
      'Host': 'localhost:3000'
    });

    console.log(`Status: ${response.status}`);
    if (response.status === 403) {
      console.log('✅ PASSED: Blocked URL was correctly rejected');
    } else if (response.status === 401) {
      console.log('⚠️  SKIPPED: Authentication required (expected)');
    } else {
      console.log('❌ FAILED: Blocked URL was allowed');
    }
  } catch (error) {
    console.log(`❌ ERROR: ${error.message}`);
  }

  // Test 3: Authentication required
  console.log('\n📝 Test 3: Authentication required');
  try {
    const encodedUrl = Buffer.from('https://example.com').toString('base64');
    const response = await makeRequest(`${backendUrl}/api/auto-source/${encodedUrl}`);

    console.log(`Status: ${response.status}`);
    if (response.status === 401) {
      console.log('✅ PASSED: Authentication correctly required');
    } else {
      console.log('❌ FAILED: Authentication not required');
    }
  } catch (error) {
    console.log(`❌ ERROR: ${error.message}`);
  }

  // Test 4: Invalid credentials
  console.log('\n📝 Test 4: Invalid credentials');
  try {
    const invalidAuth = Buffer.from('admin:wrongpassword').toString('base64');
    const encodedUrl = Buffer.from('https://example.com').toString('base64');
    const response = await makeRequest(`${backendUrl}/api/auto-source/${encodedUrl}`, {
      'Authorization': `Basic ${invalidAuth}`,
      'Host': 'localhost:3000'
    });

    console.log(`Status: ${response.status}`);
    if (response.status === 401) {
      console.log('✅ PASSED: Invalid credentials correctly rejected');
    } else {
      console.log('❌ FAILED: Invalid credentials were accepted');
    }
  } catch (error) {
    console.log(`❌ ERROR: ${error.message}`);
  }

  console.log('\n🏁 Auto source tests completed!');
  console.log(`\n💡 To run these tests automatically:`);
  console.log(`   cd frontend && npm test`);
}

function makeRequest(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method: 'GET',
      headers: {
        'Host': 'localhost:3000',
        ...headers
      }
    };

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
process.env.AUTO_SOURCE_ALLOWED_ORIGINS = 'localhost:3000';
process.env.AUTO_SOURCE_ALLOWED_URLS = 'https://github.com/*,https://example.com/*';

testAutoSource().catch(console.error);
