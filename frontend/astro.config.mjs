import { defineConfig } from "astro/config"

export default defineConfig({
  output: "static",
  server: {
    port: 3001,
    host: true,
  },
  vite: {
    server: {
      proxy: {
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
