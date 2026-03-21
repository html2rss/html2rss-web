import { defineConfig } from 'vite';
import preact from '@preact/preset-vite';

export default defineConfig({
  base: '/',
  publicDir: '../public',
  plugins: [preact()],
  server: {
    host: true,
    port: 4001,
    proxy: {
      '/api': 'http://localhost:4000',
      '/rss.xsl': 'http://localhost:4000',
    },
  },
  preview: {
    host: true,
    port: 4001,
  },
  optimizeDeps: {
    exclude: ['msw/node'],
  },
  build: {
    outDir: './dist',
    emptyOutDir: true,
  },
});
