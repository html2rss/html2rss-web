/** @type {import("stylelint").Config} */
export default {
  extends: ["stylelint-config-standard"],
  ignoreFiles: ["dist/**/*.css", "node_modules/**/*.css"],
  rules: {
    // Keep this PR scoped to toolchain migration; don't force legacy CSS rewrites yet.
    "alpha-value-notation": null,
    "color-function-alias-notation": null,
    "color-function-notation": null,
    "media-feature-range-notation": null,
    "no-descending-specificity": null,
    "selector-class-pattern": [
      "^[a-z][a-z0-9]*(?:-[a-z0-9]+)*(?:__(?:[a-z0-9]+(?:-[a-z0-9]+)*))?(?:--(?:[a-z0-9]+(?:-[a-z0-9]+)*))?$",
      {
        resolveNestedSelectors: true,
      },
    ],
  },
};
