import { defineConfig, configDefaults } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/__tests__/setup.ts'],
    globals: true,
    testTimeout: 10_000,
    hookTimeout: 10_000,
    exclude: [...configDefaults.exclude, 'tests/**', 'e2e/**'],
  },
  esbuild: {
    jsx: 'automatic',
    jsxImportSource: 'preact',
  },
});
