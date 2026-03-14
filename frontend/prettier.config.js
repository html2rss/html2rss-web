/** @type {import("prettier").Config} */
export default {
  printWidth: 110,
  singleQuote: false,
  trailingComma: 'all',
  overrides: [
    {
      files: '*.{html,md,mdx}',
      options: {
        proseWrap: 'preserve',
      },
    },
    {
      files: '*.{js,ts,jsx,tsx}',
      options: {
        singleQuote: true,
        trailingComma: 'es5',
      },
    },
  ],
};
