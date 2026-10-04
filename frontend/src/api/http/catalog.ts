import { getConfigCatalog } from '../generated/sdk.gen';
import { jsonBaseUrl, unwrap } from './client';

export async function requestConfigCatalog(): Promise<unknown> {
  const result = await unwrap(getConfigCatalog({ baseUrl: jsonBaseUrl() }));
  if (!result.ok) return;
  return result.body;
}
