import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { previewSelectors, suggestSelectors, validateSelectors } from '../refine/refineService';
import { buildStructuredErrorResponse, server } from './mocks/server';

const selectors = { items: { selector: 'article', enhance: false } };

describe('refineService', () => {
  it('posts the page URL with bearer auth and parses ranked candidates', async () => {
    let seen: { auth: string | null; body: unknown } | undefined;
    server.use(
      http.post('/api/v1/refine/suggest_selectors', async ({ request }) => {
        seen = { auth: request.headers.get('authorization'), body: await request.json() };
        return HttpResponse.json({
          success: true,
          data: {
            candidates: {
              items: [{ selector: 'article', enhance: true, sample: 'Hello' }, { selector: '' }, 'junk'],
              title: [{ selector: 'h2', sample: 'Hello' }],
              link: [],
            },
          },
        });
      })
    );

    const candidates = await suggestSelectors('https://example.com/a', ' tok ');

    expect(seen).toEqual({ auth: 'Bearer tok', body: { url: 'https://example.com/a' } });
    expect(candidates.items).toEqual([{ selector: 'article', enhance: true, sample: 'Hello' }]);
    expect(candidates.fields).toEqual({
      title: [{ selector: 'h2', sample: 'Hello', enhance: false }],
      link: [],
      published: [],
    });
  });

  it('parses a validation report into issues', async () => {
    server.use(
      http.post('/api/v1/refine/validate', async ({ request }) => {
        expect(await request.json()).toEqual({ selectors });
        return HttpResponse.json({
          success: true,
          data: {
            report: {
              success: false,
              issues: [
                { path: ['selectors', 'items', 'selector'], code: 'invalid_value', message: 'is blank' },
                { code: 'parse' },
              ],
            },
          },
        });
      })
    );

    expect(await validateSelectors(selectors, 'tok')).toEqual([
      { path: ['selectors', 'items', 'selector'], message: 'is blank' },
    ]);
  });

  it('treats a missing report as no issues', async () => {
    server.use(http.post('/api/v1/refine/validate', () => HttpResponse.json({ success: true, data: {} })));

    expect(await validateSelectors(selectors, 'tok')).toEqual([]);
  });

  it('parses a preview with samples and a known failure kind', async () => {
    server.use(
      http.post('/api/v1/refine/preview', async ({ request }) => {
        expect(await request.json()).toEqual({ url: 'https://example.com/a', selectors });
        return HttpResponse.json({
          success: true,
          data: {
            item_count: 2,
            sample_items: [{ title: 'A', url: 'https://example.com/1' }, { url: 'x' }],
            failure_kind: 'min_items',
          },
        });
      })
    );

    expect(await previewSelectors('https://example.com/a', selectors, 'tok')).toEqual({
      itemCount: 2,
      items: [{ title: 'A', url: 'https://example.com/1' }],
      failureKind: 'min_items',
    });
  });

  it('ignores unknown failure kinds and malformed data', async () => {
    server.use(
      http.post('/api/v1/refine/preview', () =>
        HttpResponse.json({ success: true, data: { item_count: 'many', failure_kind: 'mystery' } })
      )
    );

    expect(await previewSelectors('https://example.com/a', selectors, 'tok')).toEqual({
      itemCount: 0,
      items: [],
      failureKind: undefined,
    });
  });

  it('throws a structured error for rejected requests', async () => {
    server.use(
      http.post('/api/v1/refine/preview', () =>
        HttpResponse.json(
          buildStructuredErrorResponse({
            code: 'UNAUTHORIZED',
            message: 'nope',
            kind: 'auth',
            next_action: 'enter_token',
          }),
          { status: 401 }
        )
      )
    );

    await expect(previewSelectors('https://example.com/a', selectors, 'bad')).rejects.toMatchObject({
      kind: 'auth',
      nextAction: 'enter_token',
    });
  });
});
