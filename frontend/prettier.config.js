export const config = {
  tabWidth: 2,
  useTabs: false,
  semi: false,
  printWidth: 110,
  plugins: ["prettier-plugin-astro"],
  overrides: [
    {
      files: "*.astro",
      options: {
        parser: "astro"
      }
    }
  ]
}

export default config
