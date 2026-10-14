import { getApiMetadata } from '../generated/sdk.gen';
import type { GetApiMetadataResponse } from '../generated/types.gen';
import { jsonBaseUrl, unwrap } from './client';

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export function isApiMetadataResponse(value: unknown): value is GetApiMetadataResponse {
  return isRecord(value) && value.success === true && isRecord(value.data) && isRecord(value.data.instance);
}

export async function requestApiMetadata(): Promise<GetApiMetadataResponse | undefined> {
  const result = await unwrap(getApiMetadata({ baseUrl: jsonBaseUrl() }));
  if (!result.ok || !isApiMetadataResponse(result.body)) return;
  return result.body;
}
