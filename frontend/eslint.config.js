import js from '@eslint/js';
import globals from 'globals';
import reactHooks from 'eslint-plugin-react-hooks';
import eslintPluginUnicorn from 'eslint-plugin-unicorn';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['.astro/**', 'dist/**', 'node_modules/**', 'src/api/generated/**', 'test-results/**'],
  },
  {
    files: ['src/**/*.{js,jsx,ts,tsx}', 'e2e/**/*.ts', './*.{js,ts}'],
    extends: [
      js.configs.recommended,
      ...tseslint.configs.recommended,
      eslintPluginUnicorn.configs.recommended,
    ],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.browser,
        ...globals.node,
        ...globals.vitest,
      },
    },
    plugins: {
      'react-hooks': reactHooks,
    },
    rules: {
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'off',
      '@typescript-eslint/no-explicit-any': 'off',
      'unicorn/filename-case': 'off',
      'unicorn/better-regex': 'warn',
    },
  }
);
