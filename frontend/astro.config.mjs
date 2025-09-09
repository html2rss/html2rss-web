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
    },
  },
})
