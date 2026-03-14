import type { CreateFeedResponses, GetApiMetadataResponses, ListStrategiesResponses } from './generated';

export type FeedRecord = CreateFeedResponses[201]['data']['feed'];
export type ApiMetadataRecord = GetApiMetadataResponses[200]['data'];
export type DemoRecord = ApiMetadataRecord['demo'];
export type DemoSourceRecord = DemoRecord['sources'][number];
export type StrategyRecord = ListStrategiesResponses[200]['data']['strategies'][number];
