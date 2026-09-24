import { defineConfig } from '@hey-api/openapi-ts';

export default defineConfig({
  input: '../public/openapi.yaml',
  output: 'src/api/generated',
  plugins: [
    {
      name: '@hey-api/client-fetch',
      baseUrl: '/api/v1',
    },
  ],
});
