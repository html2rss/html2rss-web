import type { CreateFeedResponses, GetApiMetadataResponses, ListStrategiesResponses } from './generated';

export type FeedRecord = CreateFeedResponses[201]['data']['feed'];
export type StrategyRecord = ListStrategiesResponses[200]['data']['strategies'][number];

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
