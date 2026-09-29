import { client } from '../generated/client.gen';
import type {
  CreateFeedData,
  PreviewFeedData,
  SuggestSelectorsData,
  ValidateFeedConfigData,
} from '../generated/types.gen';
import type { StudioSelectors } from '../../studio/selectorDraft';
import { isAbortError, jsonBaseUrl, unwrap, type HttpEnvelope } from './client';

type CreateFeedBody = NonNullable<CreateFeedData['body']>;
type PreviewFeedBody = NonNullable<PreviewFeedData['body']>;
type ValidateFeedBody = NonNullable<ValidateFeedConfigData['body']>;

const FEED_WRITE_URL = {
  create: '/feeds',
  preview: '/feeds/preview',
  suggest: '/feeds/suggest_selectors',
  validate: '/feeds/validate',
} as const satisfies {
  create: CreateFeedData['url'];
  preview: PreviewFeedData['url'];
  suggest: SuggestSelectorsData['url'];
  validate: ValidateFeedConfigData['url'];
};

function bearerAuth(token: string): string | undefined {
  const trimmed = token.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

async function jsonWrite(
  url: (typeof FEED_WRITE_URL)[keyof typeof FEED_WRITE_URL],
  token: string,
  body: unknown,
  signal?: AbortSignal
): Promise<HttpEnvelope> {
  const envelope = await unwrap(
    client.post({
      url,
      baseUrl: jsonBaseUrl(),
      body,
      auth: bearerAuth(token),
      security: [{ scheme: 'bearer', type: 'http' }],
      headers: { 'Content-Type': 'application/json' },
      signal,
    })
  );
  if (isAbortError(envelope.body)) throw envelope.body;
  return envelope;
}

/** Single HTTP boundary: narrow studio outbound becomes the wire selectors document. */
export function postCreateFeed(
  url: string,
  token: string,
  selectors?: StudioSelectors
): Promise<HttpEnvelope> {
  const body: CreateFeedBody = selectors ? { url, selectors } : { url };
  return jsonWrite(FEED_WRITE_URL.create, token, body);
}

export function postValidateFeed(
  token: string,
  url: string,
  selectors: StudioSelectors,
  signal?: AbortSignal
): Promise<HttpEnvelope> {
  const body: ValidateFeedBody = { selectors, url };
  return jsonWrite(FEED_WRITE_URL.validate, token, body, signal);
}

export function postPreviewFeed(
  token: string,
  url: string,
  selectors: StudioSelectors,
  signal?: AbortSignal
): Promise<HttpEnvelope> {
  const body: PreviewFeedBody = { url, selectors };
  return jsonWrite(FEED_WRITE_URL.preview, token, body, signal);
}

export function postSuggestSelectors(
  token: string,
  url: string,
  signal?: AbortSignal
): Promise<HttpEnvelope> {
  return jsonWrite(FEED_WRITE_URL.suggest, token, { url }, signal);
}
