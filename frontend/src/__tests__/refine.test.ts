import { describe, expect, it } from 'vitest';
import { COPY } from '../journey/copy';
import { describeFailure, describeIssue, groupIssues } from '../refine/refineModel';
import {
  emptyDraft,
  isDraftComplete,
  issueField,
  selectorsFromDraft,
  withField,
  withItems,
} from '../refine/selectorDraft';

describe('selectorDraft', () => {
  it('needs an items selector to be complete', () => {
    const blank = emptyDraft();
    const spaces = withItems(blank, ' '.repeat(3));
    const filled = withItems(blank, 'article');

    expect(isDraftComplete(blank)).toBe(false);
    expect(isDraftComplete(spaces)).toBe(false);
    expect(isDraftComplete(filled)).toBe(true);
  });

  it('maps filled fields to the signed selector shape and omits blank ones', () => {
    const base = withItems(emptyDraft(), ' article ', true);
    const withTitle = withField(base, 'title', ' h2 ');
    const draft = withField(withTitle, 'link', 'a');

    expect(selectorsFromDraft(draft)).toEqual({
      items: { selector: 'article', enhance: true },
      title: { selector: 'h2', extractor: 'text' },
      url: { selector: 'a', extractor: 'href' },
    });
  });

  it('keeps enhance when only the selector changes, and replaces it when given', () => {
    const enhanced = withItems(emptyDraft(), 'article', true);

    expect(withItems(enhanced, 'li').enhance).toBe(true);
    expect(withItems(enhanced, 'li', false).enhance).toBe(false);
  });

  it('maps the date field to published_at', () => {
    const base = withItems(emptyDraft(), 'article');
    const draft = withField(base, 'published', 'time');

    expect(selectorsFromDraft(draft).published_at).toEqual({ selector: 'time', extractor: 'text' });
  });

  it.each([
    [['selectors', 'items', 'selector'], 'items'],
    [['selectors', 'title', 'selector'], 'title'],
    [['selectors', 'url', 'selector'], 'link'],
    [['selectors', 'published_at'], 'published'],
    [['selectors', 'summary'], undefined],
    [[], undefined],
  ] as const)('places issue path %j on %s', (path, field) => {
    expect(issueField(path)).toBe(field);
  });
});

describe('refineModel', () => {
  it.each(['schema', 'execution', 'min_items', 'quality'] as const)(
    'gives a human next step for %s without schema jargon',
    (kind) => {
      expect(describeFailure(kind)).not.toMatch(/schema_|_items|invalid_value/);
      expect(describeFailure(kind).length).toBeGreaterThan(20);
    }
  );

  it('points an execution failure at blocking or browser rendering', () => {
    expect(describeFailure('execution')).toBe(COPY.refineFailureExecution);
    expect(COPY.refineFailureExecution).toMatch(/browser/);
  });

  it('groups issues by the control they belong to', () => {
    const items = { path: ['selectors', 'items', 'selector'], message: 'is blank' };
    const title = { path: ['selectors', 'title', 'selector'], message: 'is blank' };
    const other = { path: ['channel'], message: 'odd' };

    expect(groupIssues([items, title, other])).toEqual({ items: [items], title: [title], other: [other] });
  });

  it('prefixes a placed issue with its field label', () => {
    expect(describeIssue({ path: ['selectors', 'title', 'selector'], message: 'is blank' })).toBe(
      `${COPY.refineTitleLabel}: is blank`
    );
    expect(describeIssue({ path: [], message: 'odd' })).toBe('odd');
  });
});
