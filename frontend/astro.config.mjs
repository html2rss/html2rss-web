import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import preact from "@astrojs/preact";

export default defineConfig({
  output: "static",
  server: {
    port: 3001,
    host: true,
  },
  vite: {
    server: {
      proxy: {
        "/api": "http://localhost:3000",
        "/feeds": "http://localhost:3000",
        "/rss.xsl": "http://localhost:3000",
      },
    },
  },
  integrations: [
    preact(),
    starlight({
      title: "html2rss-web",
      description: "Convert websites to RSS feeds instantly",
      logo: {
        src: "./src/assets/logo.png",
        replacesTitle: true,
      },
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/html2rss",
        },
      ],
      pagefind: false,
      head: [
        {
          tag: "meta",
          attrs: {
            name: "robots",
            content: "noindex, nofollow",
          },
        },
      ],
      sidebar: [
        {
          label: "Home",
          link: "/",
        },
      ],
    }),
  ],
});
