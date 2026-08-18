import type { FeedRecord } from '../api/contracts';
import { COPY } from '../journey/copy';
import {
  buildStructuredError,
  normalizeFeedCreationErrorFromResponse,
  type RawApiResponse,
} from './feedErrors';
import { normalizeString } from './feedParsers';
import { readJsonResponse } from './feedPreviewClient';

export * from './feedErrors';
export * from './feedParsers';
export * from './feedPreviewClient';

interface RawFeedRecord {
  id?: unknown;
  name?: unknown;
  url?: unknown;
  feed_token?: unknown;
  public_url?: unknown;
  json_public_url?: unknown;
  created_at?: unknown;
  updated_at?: unknown;
}

interface RawFeedPayload {
  feed?: RawFeedRecord;
}

interface RawFeedApiResponse extends RawApiResponse {
  data?: RawFeedPayload;
}

export async function requestFeedCreation(url: string, token: string): Promise<FeedRecord> {
  const response = await fetch(resolveApiUrl('feeds'), {
    method: 'POST',
    headers: buildCreateHeaders(token),
    body: JSON.stringify({ url }),
  });

  const payload = await readJsonResponse<RawFeedApiResponse>(response);

  if (!response.ok) {
    throw normalizeFeedCreationErrorFromResponse(response.status, payload?.error, payload);
  }

  const feed = normalizeFeedRecord(payload?.data?.feed);
  if (!feed) {
    throw buildStructuredError(
      'server',
      'INVALID_RESPONSE',
      true,
      'retry',
      'primary',
      COPY.unableToStartCreation,
      response.status
    );
  }

  return feed;
}

export function normalizeFeedRecord(raw?: RawFeedRecord): FeedRecord | undefined {
  if (!raw) return undefined;

  const feedToken = normalizeString(raw.feed_token);
  const publicUrl = normalizeString(raw.public_url);
  const jsonPublicUrl = normalizeString(raw.json_public_url);
  const url = normalizeString(raw.url);

  if (!feedToken || !publicUrl || !jsonPublicUrl || !url) return undefined;

  return {
    id: normalizeString(raw.id) || feedToken,
    name: normalizeString(raw.name) || url,
    url,
    feed_token: feedToken,
    public_url: publicUrl,
    json_public_url: jsonPublicUrl,
    created_at: normalizeString(raw.created_at) || new Date().toISOString(),
    updated_at: normalizeString(raw.updated_at) || new Date().toISOString(),
  };
}

export function resolveApiUrl(path: string): string {
  return `/api/v1/${path.replace(/^\/+/, '')}`;
}

export function buildCreateHeaders(token: string): HeadersInit {
  const normalizedToken = token.trim();
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };

  if (normalizedToken) {
    headers.Authorization = `Bearer ${normalizedToken}`;
  }

  return headers;
}
