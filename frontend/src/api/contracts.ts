import type { CreateFeedResponses, GetApiMetadataResponses, ListStrategiesResponses } from './generated';

export type FeedRecord = CreateFeedResponses[201]['data']['feed'];
export type StrategyRecord = ListStrategiesResponses[200]['data']['strategies'][number];
export interface FeedPreviewItem {
  title: string;
  excerpt: string;
  publishedLabel: string;
  url?: string;
}

export interface FeedPreviewState {
  items: FeedPreviewItem[];
  error?: string;
  isLoading: boolean;
}

export type FeedReadinessPhase = 'link_created' | 'feed_ready' | 'feed_not_ready_yet' | 'preview_unavailable';

export interface FeedRetryState {
  automatic: boolean;
  from: string;
  to: string;
}

export interface CreatedFeedResult {
  feed: FeedRecord;
  preview: FeedPreviewState;
  readinessPhase: FeedReadinessPhase;
  retry?: FeedRetryState;
}

export interface ApiMetadataRecord {
  api: GetApiMetadataResponses[200]['data']['api'];
  instance: {
    feed_creation: {
      enabled: boolean;
      access_token_required: boolean;
    };
    featured_feeds?: Array<{
      path: string;
      title: string;
      description: string;
    }>;
  };
}
