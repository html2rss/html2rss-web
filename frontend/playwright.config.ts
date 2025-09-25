import { defineConfig } from '@playwright/test';
import path from 'node:path';

const PROJECT_ROOT = path.resolve(__dirname, '..');

export default defineConfig({
  testDir: './tests/smoke',
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['html', { open: 'never' }], ['list']] : 'list',
  use: {
    baseURL: process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3000',
    trace: 'retain-on-failure',
    headless: true,
  },
  webServer: [
    {
      command: 'bundle exec puma -p 3000',
      cwd: PROJECT_ROOT,
      env: {
        ...process.env,
        RACK_ENV: 'test',
        AUTO_SOURCE_ENABLED: 'true',
        AUTO_SOURCE_USERNAME: 'admin',
        AUTO_SOURCE_PASSWORD: 'changeme',
        AUTO_SOURCE_ALLOWED_ORIGINS: '127.0.0.1:3000,localhost:3000',
        AUTO_SOURCE_ALLOWED_URLS: 'https://example.com/*,https://test.com/*',
        HEALTH_CHECK_TOKEN: 'health-check-token-xyz789',
        HTML2RSS_SECRET_KEY: process.env.HTML2RSS_SECRET_KEY ?? 'test-secret-key-for-smoke',
      },
      reuseExistingServer: !process.env.CI,
      stdout: 'pipe',
      stderr: 'pipe',
      port: 3000,
      timeout: 60_000,
    },
  ],
});
