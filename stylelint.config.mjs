/** @type {import("stylelint").Config} */
export default {
  extends: ["./frontend/stylelint.config.mjs"],
  ignoreFiles: [
    "coverage/**/*.css",
    "frontend/dist/**/*.css",
    "frontend/node_modules/**/*.css",
  ],
};
