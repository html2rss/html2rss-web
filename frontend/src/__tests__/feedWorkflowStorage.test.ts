import { beforeEach, describe, expect, it } from 'vitest';
import { clearFeedDraftState, loadFeedDraftState, saveFeedDraftState } from '../utils/feedWorkflowStorage';

describe('feedWorkflowStorage', () => {
  beforeEach(() => {
    globalThis.localStorage.clear();
    globalThis.sessionStorage.clear();
  });

  it('persists and hydrates the create draft state from the url only', () => {
    saveFeedDraftState({ url: 'https://example.com/articles' });

    expect(loadFeedDraftState()).toEqual({
      url: 'https://example.com/articles',
    });
    expect(globalThis.localStorage.getItem('html2rss_feed_draft_state')).toBe(
      JSON.stringify({ url: 'https://example.com/articles' })
    );

    clearFeedDraftState();
    expect(loadFeedDraftState()).toBeUndefined();
  });

  it('ignores extra draft properties beyond the canonical shape', () => {
    globalThis.localStorage.setItem(
      'html2rss_feed_draft_state',
      JSON.stringify({
        url: 'https://example.com/articles',
        extra: 'ignored',
      })
    );

    expect(loadFeedDraftState()).toEqual({
      url: 'https://example.com/articles',
    });
  });
});
