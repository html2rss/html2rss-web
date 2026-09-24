/**
 * Closed studio draft for selector authoring.
 * {@link selectorsFromDraft} yields the studio subset; HTTP widens at one boundary.
 * Hydrate fails closed on keys outside the subset.
 */

export const STUDIO_FIELDS = ['title', 'link', 'published'] as const;
export type StudioFieldId = (typeof STUDIO_FIELDS)[number];

const STUDIO_FIELD_WIRE = [
  { field: 'title', key: 'title', extractor: 'text' },
  { field: 'link', key: 'url', extractor: 'href' },
  { field: 'published', key: 'published_at', extractor: 'text' },
] as const satisfies readonly {
  field: StudioFieldId;
  key: 'title' | 'url' | 'published_at';
  extractor: 'text' | 'href';
}[];

/** Root keys {@link draftFromSelectors} accepts. */
const STUDIO_ROOT_KEYS = new Set(['items', ...STUDIO_FIELD_WIRE.map(({ key }) => key)]);

/** Items keys the studio draft owns. */
const STUDIO_ITEMS_KEYS = new Set(['selector', 'enhance']);

export interface FieldDraft {
  readonly selector: string;
}

export interface StudioDraft {
  readonly itemsSelector: string;
  readonly enhance: boolean;
  readonly fields: Readonly<Record<StudioFieldId, FieldDraft>>;
}

/** Narrow outbound selectors the studio authors. */
export type StudioSelectors = {
  readonly items: {
    readonly selector: string;
    /** Always sent — omitting `false` lets the gem default `enhance: true`. */
    readonly enhance: boolean;
  };
  readonly title?: {
    readonly selector: string;
    readonly extractor: 'text';
  };
  readonly url?: {
    readonly selector: string;
    readonly extractor: 'href';
  };
  readonly published_at?: {
    readonly selector: string;
    readonly extractor: 'text';
  };
};

type StudioSelectorsBuilder = {
  items: StudioSelectors['items'];
  title?: StudioSelectors['title'];
  url?: StudioSelectors['url'];
  published_at?: StudioSelectors['published_at'];
};

export type IssuePlace =
  | { readonly kind: 'items' }
  | { readonly kind: 'enhance' }
  | { readonly kind: 'field'; readonly field: StudioFieldId; readonly control: 'selector' }
  | { readonly kind: 'hidden' };

/** Wire spelling of Html2rss::Selectors::DEFAULT_ITEMS_SELECTOR. */
export const DEFAULT_ITEMS_SELECTOR = 'a[href]';

export function isPlainRecord(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === 'object' && value instanceof Object && Object.getPrototypeOf(value) === Object.prototype
  );
}

export function emptyDraft(): StudioDraft {
  return {
    itemsSelector: DEFAULT_ITEMS_SELECTOR,
    enhance: false,
    fields: emptyFields(),
  };
}

export function selectorsFromDraft(draft: StudioDraft): StudioSelectors {
  const selectors: StudioSelectorsBuilder = {
    items: { selector: draft.itemsSelector, enhance: draft.enhance },
  };

  if (draft.fields.title.selector.length > 0) {
    selectors.title = { selector: draft.fields.title.selector, extractor: 'text' };
  }
  if (draft.fields.link.selector.length > 0) {
    selectors.url = { selector: draft.fields.link.selector, extractor: 'href' };
  }
  if (draft.fields.published.selector.length > 0) {
    selectors.published_at = { selector: draft.fields.published.selector, extractor: 'text' };
  }

  return selectors;
}

export function draftFromSelectors(value: unknown): StudioDraft | undefined {
  if (!isPlainRecord(value)) return;

  for (const key of Object.keys(value)) {
    if (!STUDIO_ROOT_KEYS.has(key)) return;
  }

  let items: Record<string, unknown> | undefined;
  if (Object.hasOwn(value, 'items')) {
    if (!isPlainRecord(value.items)) return;
    for (const key of Object.keys(value.items)) {
      if (!STUDIO_ITEMS_KEYS.has(key)) return;
    }
    items = value.items;
  }

  const fields = emptyFields();
  for (const mapping of STUDIO_FIELD_WIRE) {
    const { key } = mapping;
    if (!Object.hasOwn(value, key)) continue;
    const parsed = parseField(mapping, value[key]);
    if (!parsed) return;
    fields[parsed.field] = parsed.draft;
  }

  return {
    itemsSelector: typeof items?.selector === 'string' ? items.selector : '',
    enhance: items?.enhance === true,
    fields,
  };
}

export function withItemsSelector(draft: StudioDraft, itemsSelector: string): StudioDraft {
  return { ...draft, itemsSelector };
}

export function withEnhance(draft: StudioDraft, isEnhanced: boolean): StudioDraft {
  return { ...draft, enhance: isEnhanced };
}

export function withFieldSelector(draft: StudioDraft, field: StudioFieldId, selector: string): StudioDraft {
  return {
    ...draft,
    fields: { ...draft.fields, [field]: { selector } },
  };
}

/**
 * Selector parts split on commas outside `()`, `[]`, and quotes.
 */
export function splitSelectorParts(selector: string): readonly string[] {
  const parts: string[] = [];
  let start = 0;
  let quote: '"' | "'" | undefined;
  let paren = 0;
  let bracket = 0;

  for (let index = 0; index < selector.length; index += 1) {
    const char = selector[index];
    if (char === '\\') {
      index += 1;
      continue;
    }
    if (quote) {
      if (char === quote) quote = undefined;
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
      continue;
    }
    if (char === '(') {
      paren += 1;
      continue;
    }
    if (char === ')' && paren > 0) {
      paren -= 1;
      continue;
    }
    if (char === '[') {
      bracket += 1;
      continue;
    }
    if (char === ']' && bracket > 0) {
      bracket -= 1;
      continue;
    }
    if (char === ',' && paren === 0 && bracket === 0) {
      pushPart(parts, selector.slice(start, index));
      start = index + 1;
    }
  }

  pushPart(parts, selector.slice(start));
  return parts;
}

function joinParts(parts: readonly string[]): string {
  return parts.join(', ');
}

/** True when every part of `candidate` is already an exact part of `current`. */
export function hasEverySelectorPart(current: string, candidate: string): boolean {
  const wanted = splitSelectorParts(candidate);
  if (wanted.length === 0) return false;
  const present = splitSelectorParts(current);
  return wanted.every((part) => present.includes(part));
}

/** Add missing candidate parts, or remove them when all are present. */
export function toggleSelectorParts(current: string, candidate: string): string {
  const present = splitSelectorParts(current);
  const incoming = splitSelectorParts(candidate);
  if (incoming.length === 0) return joinParts(present);
  if (incoming.every((part) => present.includes(part))) {
    const remove = new Set(incoming);
    return joinParts(present.filter((part) => !remove.has(part)));
  }

  const next = [...present];
  for (const part of incoming) {
    if (!next.includes(part)) next.push(part);
  }
  return joinParts(next);
}

export function issuePlace(path: readonly string[]): IssuePlace {
  const scope = selectorScope(path);
  const head = scope[0];
  if (head === 'items') {
    return scope.includes('enhance') ? { kind: 'enhance' } : { kind: 'items' };
  }

  const field =
    typeof head === 'string' ? STUDIO_FIELD_WIRE.find(({ key }) => key === head)?.field : undefined;
  if (!field) return { kind: 'hidden' };
  return { kind: 'field', field, control: 'selector' };
}

function pushPart(parts: string[], raw: string) {
  const trimmed = raw.trim();
  if (trimmed.length > 0) parts.push(trimmed);
}

function emptyFields(): Record<StudioFieldId, FieldDraft> {
  return {
    title: { selector: '' },
    link: { selector: '' },
    published: { selector: '' },
  };
}

function parseField(
  mapping: (typeof STUDIO_FIELD_WIRE)[number],
  value: unknown
): { readonly field: StudioFieldId; readonly draft: FieldDraft } | undefined {
  if (!isPlainRecord(value) || typeof value.selector !== 'string') return;
  if (value.extractor !== undefined && value.extractor !== mapping.extractor) return;
  for (const nested of Object.keys(value)) {
    if (nested !== 'selector' && nested !== 'extractor') return;
  }
  return { field: mapping.field, draft: { selector: value.selector } };
}

function selectorScope(path: readonly string[]): readonly string[] {
  const index = path.indexOf('selectors');
  return index === -1 ? path : path.slice(index + 1);
}
