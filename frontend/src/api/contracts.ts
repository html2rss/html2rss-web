import type { GetApiMetadataResponses } from './generated';

export interface FeedRecord {
  id: string;
  name: string;
  url: string;
  feed_token: string;
  public_url: string;
  json_public_url: string;
  created_at: string;
  updated_at: string;
}

export type FeedPreviewStatus = 'created' | 'preview_loading' | 'preview_ready' | 'preview_failed';
export type FeedRetryAction = 'alternate' | 'primary' | 'none';
export type FeedNextAction = 'enter_token' | 'correct_input' | 'retry' | 'wait' | 'none';
export type FeedErrorKind = 'auth' | 'input' | 'network' | 'server' | 'client';

export type FeedCreationErrorCode =
  | 'EXTRACTION_EMPTY'
  | 'BLOCKED_SURFACE'
  | 'SCRAPER_UNAVAILABLE'
  | 'UNAUTHORIZED'
  | 'BAD_REQUEST'
  | 'FORBIDDEN'
  | 'TOO_MANY_REQUESTS'
  | 'SERVICE_UNAVAILABLE'
  | 'GATEWAY_TIMEOUT'
  | 'INTERNAL_SERVER_ERROR'
  | 'INVALID_RESPONSE'
  | 'NETWORK_ERROR'
  | 'UNKNOWN_ERROR'
  | (string & {});

export interface FeedPreviewItem {
  title: string;
  excerpt: string;
  publishedLabel: string;
  url?: string;
}

export interface FeedPreviewWarning {
  code: FeedCreationErrorCode;
  message: string;
  retryable: boolean;
  nextAction: FeedNextAction;
}

export interface FeedPreviewState {
  status: FeedPreviewStatus;
  items: FeedPreviewItem[];
  isLoading: boolean;
}

export interface CreatedFeedResult {
  feed: FeedRecord;
  preview: FeedPreviewState;
  warnings: FeedPreviewWarning[];
}

export interface FeedCreationError {
  kind: FeedErrorKind;
  code: FeedCreationErrorCode;
  retryable: boolean;
  nextAction: FeedNextAction;
  retryAction: FeedRetryAction;
  message: string;
  status?: number;
}

export interface ApiMetadataRecord {
  api: GetApiMetadataResponses[200]['data']['api'];
  instance: {
    feed_creation: {
      enabled: boolean;
      access_token_required: boolean;
    };
    catalog?: {
      enabled: boolean;
      url: string;
    };
  };
}
