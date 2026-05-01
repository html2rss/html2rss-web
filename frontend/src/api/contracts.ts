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

export type FeedWorkflowState = 'created' | 'preview_loading' | 'preview_ready' | 'preview_failed';
export type FeedRetryAction = 'alternate' | 'primary' | 'none';
export type FeedNextAction = 'enter_token' | 'correct_input' | 'retry' | 'wait' | 'none';

export interface FeedPreviewItem {
  title: string;
  excerpt: string;
  publishedLabel: string;
  url?: string;
}

export interface FeedPreviewWarning {
  code: string;
  message: string;
  retryable: boolean;
  nextAction: FeedNextAction;
}

export interface FeedPreviewState {
  items: FeedPreviewItem[];
  isLoading: boolean;
}

export interface CreatedFeedResult {
  feed: FeedRecord;
  preview: FeedPreviewState;
  workflowState: FeedWorkflowState;
  warnings: FeedPreviewWarning[];
}

export interface FeedCreationError {
  kind: 'auth' | 'input' | 'network' | 'server';
  code: string;
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
    featured_feeds?: Array<{
      path: string;
      title: string;
      description: string;
    }>;
  };
}
