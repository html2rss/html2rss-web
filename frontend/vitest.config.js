import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/__tests__/setup.ts'],
    globals: true,
    testTimeout: 10000,
    hookTimeout: 10000,
  },
  esbuild: {
    jsx: 'automatic',
    jsxImportSource: 'preact',
  },
});
