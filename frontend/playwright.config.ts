import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'list',
  use: {
    baseURL: 'http://127.0.0.1:4001',
    headless: true,
    trace: 'on-first-retry',
    launchOptions: {
      executablePath: '/usr/bin/chromium-browser',
      args: ['--no-sandbox'],
    },
  },
  webServer: {
    command: 'npm run dev -- --host 0.0.0.0 --port 4001',
    url: 'http://127.0.0.1:4001',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
