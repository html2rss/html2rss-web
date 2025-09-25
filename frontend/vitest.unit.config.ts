import { mergeConfig } from 'vitest/config';
import baseConfig from './vitest.config';

export default mergeConfig(baseConfig, {
  test: {
    exclude: [...(baseConfig.test?.exclude ?? []), 'src/__tests__/**/*.contract.test.*'],
  },
});
