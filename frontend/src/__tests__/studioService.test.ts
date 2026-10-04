import { beforeEach, describe, expect, it, vi } from 'vitest';
import { postPreviewFeed, postSuggestSelectors } from '../api/http/feeds';
import { COPY } from '../journey/copy';
import { emptyDraft } from '../studio/selectorDraft';
import { previewStudioFeed, StudioRequestError, suggestStudioSelectors } from '../studio/studioService';

vi.mock('../api/http/feeds', () => ({
  postPreviewFeed: vi.fn(),
  postSuggestSelectors: vi.fn(),
  postValidateFeed: vi.fn(),
}));

const pageUrl = 'https://example.com/articles';
const token = 'studio-token';

function okEnvelope(data: unknown) {
  return { ok: true, status: 200, body: { success: true, data } };
}

async function fieldOnFailure(work: Promise<unknown>): Promise<string | undefined> {
  try {
    await work;
  } catch (error) {
    expect(error).toBeInstanceOf(StudioRequestError);
    if (!(error instanceof StudioRequestError)) return;
    expect(error.message).toBe(COPY.unableToCompleteCreation);
    return error.field;
  }
  expect.fail('expected a studio parse error');
}

describe('studio payload parsing', () => {
  beforeEach(() => {
    vi.mocked(postPreviewFeed).mockReset();
    vi.mocked(postSuggestSelectors).mockReset();
  });

  it('names sample_items when the preview sample list is not an array', async () => {
    vi.mocked(postPreviewFeed).mockResolvedValue(okEnvelope({ item_count: 0, sample_items: 'nope' }));

    const field = await fieldOnFailure(previewStudioFeed(token, pageUrl, emptyDraft()));
    expect(field).toBe('sample_items');
  });

  it('names sample_items when one sample is missing a title', async () => {
    vi.mocked(postPreviewFeed).mockResolvedValue(
      okEnvelope({ item_count: 1, sample_items: [{ url: 'https://example.com/a' }] })
    );

    const field = await fieldOnFailure(previewStudioFeed(token, pageUrl, emptyDraft()));
    expect(field).toBe('sample_items');
  });

  it('names candidates when the suggestion buckets are missing', async () => {
    vi.mocked(postSuggestSelectors).mockResolvedValue(okEnvelope({}));

    const field = await fieldOnFailure(suggestStudioSelectors(token, pageUrl));
    expect(field).toBe('candidates');
  });

  it('returns a ready candidate result without leaking wire enhance', async () => {
    vi.mocked(postSuggestSelectors).mockResolvedValue(
      okEnvelope({
        candidates: {
          items: [{ selector: 'article', enhance: true, sample: 'Story' }],
          title: [{ selector: 'h2', sample: 'Headline' }],
          link: [],
          published: [],
        },
      })
    );

    await expect(suggestStudioSelectors(token, pageUrl)).resolves.toEqual({
      status: 'ready',
      candidates: {
        items: [{ selector: 'article', sample: 'Story' }],
        fields: {
          title: [{ selector: 'h2', sample: 'Headline' }],
          link: [],
          published: [],
        },
      },
    });
  });

  it('returns an explicit empty result for valid empty buckets', async () => {
    vi.mocked(postSuggestSelectors).mockResolvedValue(
      okEnvelope({ candidates: { items: [], title: [], link: [], published: [] } })
    );

    await expect(suggestStudioSelectors(token, pageUrl)).resolves.toEqual({ status: 'empty' });
  });

  it('rejects malformed item enhance instead of leaking or applying it', async () => {
    vi.mocked(postSuggestSelectors).mockResolvedValue(
      okEnvelope({
        candidates: {
          items: [{ selector: 'article', enhance: 'yes', sample: 'Story' }],
          title: [],
          link: [],
          published: [],
        },
      })
    );

    expect(await fieldOnFailure(suggestStudioSelectors(token, pageUrl))).toBe('candidates');
  });

  it.each([
    [401, 'Authentication required'],
    [403, 'Studio is disabled'],
    [429, 'Too many requests'],
  ])('preserves the server decision for a %i suggestion response', async (status, message) => {
    vi.mocked(postSuggestSelectors).mockResolvedValue({
      ok: false,
      status,
      body: { success: false, error: { message } },
    });

    await expect(suggestStudioSelectors(token, pageUrl)).rejects.toThrow(message);
  });

  it('uses owned fallback copy when a failed suggestion has no message', async () => {
    vi.mocked(postSuggestSelectors).mockResolvedValue({
      ok: false,
      status: 500,
      body: { success: false, error: {} },
    });

    await expect(suggestStudioSelectors(token, pageUrl)).rejects.toThrow(COPY.unableToCompleteCreation);
  });
});
