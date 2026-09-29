import { describe, expect, it } from 'vitest';
import {
  draftFromSelectors,
  emptyDraft,
  hasEverySelectorPart,
  selectorsFromDraft,
  splitSelectorParts,
  toggleSelectorParts,
  withFieldSelector,
} from '../studio/selectorDraft';

describe('selectorDraft', () => {
  it('starts the items selector at the gem default a[href]', () => {
    expect(emptyDraft().itemsSelector).toBe('a[href]');
  });

  it('splits on commas outside parens, brackets, and quotes, and drops empty parts', () => {
    expect(splitSelectorParts('a[href], article, div')).toEqual(['a[href]', 'article', 'div']);
    expect(splitSelectorParts('article,,  div')).toEqual(['article', 'div']);
    expect(splitSelectorParts('  article , div  ')).toEqual(['article', 'div']);
    expect(splitSelectorParts('div:not(.a, .b), article')).toEqual(['div:not(.a, .b)', 'article']);
    expect(splitSelectorParts('div:has(a[href]), article')).toEqual(['div:has(a[href])', 'article']);
    expect(splitSelectorParts('a[href="foo, bar"], main')).toEqual(['a[href="foo, bar"]', 'main']);
    expect(splitSelectorParts("a[href='foo, bar'], main")).toEqual(["a[href='foo, bar']", 'main']);
    expect(splitSelectorParts('')).toEqual([]);
  });

  it('treats a candidate as used when every part is present, not only on a whole-string match', () => {
    expect(hasEverySelectorPart('a[href], article, div, main', 'article, div')).toBe(true);
    expect(hasEverySelectorPart('article, div', 'article, div, main')).toBe(false);
    expect(hasEverySelectorPart('article', 'article, div')).toBe(false);
  });

  it('adds candidate parts in order, dedupes exact parts, and removes one part without the others', () => {
    const added = toggleSelectorParts(toggleSelectorParts('a[href]', 'article, div'), 'main');
    expect(added).toBe('a[href], article, div, main');
    expect(hasEverySelectorPart(added, 'article, div')).toBe(true);
    expect(hasEverySelectorPart(added, 'main')).toBe(true);

    const removed = toggleSelectorParts(added, 'article');
    expect(removed).toBe('a[href], div, main');
    expect(removed.includes('article')).toBe(false);

    expect(toggleSelectorParts('article', 'article, div')).toBe('article, div');
    expect(toggleSelectorParts('a[href], article, div', 'article, div')).toBe('a[href]');
  });

  it('refuses to hydrate documents outside StudioSelectors', () => {
    expect(
      draftFromSelectors({
        items: { selector: 'article', enhance: true, order: 'reverse' },
        guid: ['title'],
        title: { selector: 'h2', extractor: 'text' },
      })
    ).toBeUndefined();
    expect(draftFromSelectors({ items: { selector: 'article', pagination: 2 } })).toBeUndefined();
    expect(
      draftFromSelectors({
        items: { selector: 'article' },
        title: {
          selector: 'h2',
          extractor: 'text',
          post_process: [{ name: 'gsub', pattern: 'x', replacement: '' }],
        },
      })
    ).toBeUndefined();
  });

  it('always emits enhance boolean so uncheck disables gem enrichment', () => {
    const unchecked = emptyDraft();
    expect(unchecked.enhance).toBe(false);
    expect(selectorsFromDraft(unchecked)).toEqual({
      items: { selector: 'a[href]', enhance: false },
    });

    const checked = { ...unchecked, enhance: true };
    expect(selectorsFromDraft(checked)).toEqual({
      items: { selector: 'a[href]', enhance: true },
    });
  });

  it('round-trips pure StudioSelectors without silent drop', () => {
    const drafted = draftFromSelectors({
      items: { selector: 'article', enhance: true },
      title: { selector: 'h2', extractor: 'text' },
    });
    expect(drafted).toBeDefined();
    if (!drafted) return;

    expect(drafted.itemsSelector).toBe('article');
    expect(drafted.enhance).toBe(true);
    expect(drafted.fields.title.selector).toBe('h2');

    const withLink = withFieldSelector(drafted, 'link', 'a');
    const withDate = withFieldSelector(withLink, 'published', 'time');
    const wire = selectorsFromDraft(withDate);
    expect(wire).toEqual({
      items: { selector: 'article', enhance: true },
      title: { selector: 'h2', extractor: 'text' },
      url: { selector: 'a', extractor: 'href' },
      published_at: { selector: 'time', extractor: 'text' },
    });

    const again = draftFromSelectors(wire);
    expect(again?.fields.title.selector).toBe('h2');
    expect(again?.fields.link.selector).toBe('a');
    expect(again?.fields.published.selector).toBe('time');
    expect(selectorsFromDraft(again ?? withDate)).toEqual(wire);
  });
});
