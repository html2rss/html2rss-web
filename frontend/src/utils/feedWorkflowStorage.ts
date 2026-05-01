import { getPersistentStorage } from './persistentStorage';

const FEED_DRAFT_KEY = 'html2rss_feed_draft_state';

export interface FeedDraftState {
  url: string;
}

export function loadFeedDraftState(): FeedDraftState | undefined {
  const storedState = parseJson<FeedDraftState>(
    getPersistentStorage().getItem(FEED_DRAFT_KEY),
    isFeedDraftState
  );

  return storedState ? normalizeFeedDraftState(storedState) : undefined;
}

export function saveFeedDraftState(state: FeedDraftState): void {
  const normalizedState = normalizeFeedDraftState(state);
  if (!normalizedState) return;

  getPersistentStorage().setItem(FEED_DRAFT_KEY, JSON.stringify(normalizedState));
}

export function clearFeedDraftState(): void {
  getPersistentStorage().removeItem(FEED_DRAFT_KEY);
}

function normalizeFeedDraftState(state: FeedDraftState): FeedDraftState | undefined {
  const url = state.url.trim();
  if (!url) return undefined;

  return { url };
}

function isFeedDraftState(value: unknown): value is FeedDraftState {
  if (!value || typeof value !== 'object') return false;

  const candidate = value as Partial<FeedDraftState>;
  return typeof candidate.url === 'string';
}

function parseJson<T>(
  value: string | null | undefined,
  guard: (candidate: unknown) => candidate is T
): T | undefined {
  if (!value) return undefined;

  try {
    const parsed = JSON.parse(value) as unknown;
    return guard(parsed) ? parsed : undefined;
  } catch {
    return undefined;
  }
}
