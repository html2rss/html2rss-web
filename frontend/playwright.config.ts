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
