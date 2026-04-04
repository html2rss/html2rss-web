import { createClient, createConfig } from './generated/client';

const resolveBaseUrl = (): string => {
  if (globalThis.window === undefined) return 'http://localhost/api/v1';

  const origin = globalThis.location?.origin;
  if (!origin || origin === 'null') return 'http://localhost/api/v1';

  return `${origin}/api/v1`;
};

export const apiClient = createClient(
  createConfig({
    baseUrl: resolveBaseUrl(),
  })
);

export const bearerHeaders = (token?: string): Record<string, string> =>
  token ? { Authorization: `Bearer ${token}` } : {};
