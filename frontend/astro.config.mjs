import { defineConfig } from "astro/config"

export default defineConfig({
  output: "static",
  server: {
    port: 4321,
    host: true,
  },
  vite: {
    server: {
      watch: {
        usePolling: true,
      },
      proxy: {
        '/api': {
          target: 'http://localhost:3000',
          changeOrigin: true,
        },
        '/auto_source': {
          target: 'http://localhost:3000',
          changeOrigin: true,
        },
        '/health_check.txt': {
          target: 'http://localhost:3000',
          changeOrigin: true,
        },
      },
    },
  },
})
