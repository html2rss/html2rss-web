/** @type {import("prettier").Config} */
export default {
  // Global settings
  printWidth: 110,
  singleQuote: false,
  trailingComma: 'all',
  plugins: ['prettier-plugin-astro'],

  // File-specific overrides
  overrides: [
    {
      // Astro files need special parser
      files: '*.astro',
      options: {
        parser: 'astro',
      },
    },
    {
      // Markdown and prose files should preserve natural line breaks
      files: '*.{html,md,mdx}',
      options: {
        proseWrap: 'preserve', // Don't force rewrapping of prose content
      },
    },
    {
      // JavaScript/TypeScript files use single quotes and ES5 trailing commas
      files: '*.{js,ts,jsx,tsx}',
      options: {
        singleQuote: true,
        trailingComma: 'es5',
      },
    },
  ],
};
