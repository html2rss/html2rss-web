import type { FeedRecord } from '../api/contracts';
import { postCreateFeed } from '../api/http/feeds';
import type { StudioSelectors } from '../studio/selectorDraft';
import { COPY } from '../journey/copy';
import {
  buildStructuredError,
  normalizeFeedCreationErrorFromResponse,
  type RawApiResponse,
} from './feedErrors';
import { normalizeString } from './feedParsers';

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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function feedApiResponse(body: unknown): RawApiResponse | undefined {
  if (!isRecord(body)) return;
  return { success: body.success, data: body.data, error: body.error };
}

function rawFeedRecord(body: unknown): RawFeedRecord | undefined {
  const payload = feedApiResponse(body);
  if (!isRecord(payload?.data)) return;
  const feed = payload.data.feed;
  return isRecord(feed) ? feed : undefined;
}

export async function requestFeedCreation(
  url: string,
  token: string,
  selectors?: StudioSelectors
): Promise<FeedRecord> {
  const envelope = await postCreateFeed(url, token, selectors);
  const payload = feedApiResponse(envelope.body);

  if (!envelope.ok) {
    throw normalizeFeedCreationErrorFromResponse(envelope.status, payload?.error, payload);
  }

  const feed = normalizeFeedRecord(rawFeedRecord(envelope.body));
  if (!feed) {
    throw buildStructuredError(
      'server',
      'INVALID_RESPONSE',
      true,
      'retry',
      'primary',
      COPY.unableToStartCreation,
      envelope.status
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
