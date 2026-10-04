import { defineConfig, configDefaults } from 'vitest/config';

const sharedExclude = [...configDefaults.exclude, 'tests/**', 'e2e/**'];

const unitInclude = [
  'src/__tests__/decideJourney.test.ts',
  'src/__tests__/catalog.test.ts',
  'src/__tests__/selectorDraft.test.ts',
  'src/__tests__/studioModel.test.ts',
  'src/__tests__/url.test.ts',
  'src/__tests__/feedCreationError.test.ts',
  'src/__tests__/feedWorkflowStorage.test.ts',
  'src/__tests__/studioService.test.ts',
  'src/__tests__/directoryHandoff.test.ts',
  'src/__tests__/previewHydration.test.ts',
  'src/__tests__/apiHttp.test.ts',
  'src/__tests__/persistentStorage.test.ts',
  'src/__tests__/bookmarkletHref.test.ts',
];

const integrationInclude = [
  'src/__tests__/App.integration.test.tsx',
  'src/__tests__/ConfigStudio.test.tsx',
  'src/__tests__/ResultDisplay.test.tsx',
  'src/__tests__/useStudio.test.ts',
  'src/__tests__/useFeedCreation.test.ts',
  'src/__tests__/appRoute.test.ts',
];

export default defineConfig({
  test: {
    globals: false,
    testTimeout: 10_000,
    hookTimeout: 10_000,
    exclude: sharedExclude,
    projects: [
      {
        extends: true,
        test: {
          name: 'unit',
          environment: 'node',
          include: unitInclude,
          setupFiles: ['./src/__tests__/setup.unit.ts'],
        },
      },
      {
        extends: true,
        test: {
          name: 'integration',
          environment: 'jsdom',
          include: integrationInclude,
          setupFiles: ['./src/__tests__/setup.ts'],
        },
      },
    ],
  },
  esbuild: {
    jsx: 'automatic',
    jsxImportSource: 'preact',
  },
});
