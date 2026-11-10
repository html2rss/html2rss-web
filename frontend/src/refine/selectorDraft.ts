export const REFINE_FIELDS = ['title', 'link', 'published'] as const;
export type RefineFieldId = (typeof REFINE_FIELDS)[number];

export interface RefineDraft {
  readonly items: string;
  readonly enhance: boolean;
  readonly fields: Readonly<Record<RefineFieldId, string>>;
}

/** Selector map signed into the feed token; the server (SelectorsDocument) is the authority on shape. */
export type RefineSelectors = {
  items: { selector: string; enhance: boolean };
} & Partial<Record<'title' | 'url' | 'published_at', { selector: string; extractor: 'text' | 'href' }>>;

const FIELD_WIRE = {
  title: { key: 'title', extractor: 'text' },
  link: { key: 'url', extractor: 'href' },
  published: { key: 'published_at', extractor: 'text' },
} as const;

export function emptyDraft(): RefineDraft {
  return { items: '', enhance: false, fields: { title: '', link: '', published: '' } };
}

export function withItems(draft: RefineDraft, items: string, enhance = draft.enhance): RefineDraft {
  return { ...draft, items, enhance };
}

export function withEnhance(draft: RefineDraft, isEnhanced: boolean): RefineDraft {
  return { ...draft, enhance: isEnhanced };
}

export function withField(draft: RefineDraft, field: RefineFieldId, selector: string): RefineDraft {
  return { ...draft, fields: { ...draft.fields, [field]: selector } };
}

export function isDraftComplete(draft: RefineDraft): boolean {
  return draft.items.trim().length > 0;
}

export function selectorsFromDraft(draft: RefineDraft): RefineSelectors {
  const selectors: RefineSelectors = { items: { selector: draft.items.trim(), enhance: draft.enhance } };

  for (const field of REFINE_FIELDS) {
    const selector = draft.fields[field].trim();
    if (!selector) continue;
    const { key, extractor } = FIELD_WIRE[field];
    selectors[key] = { selector, extractor };
  }

  return selectors;
}

/** Which draft control a gem validation issue belongs to; unplaced issues are shown in the summary. */
export function issueField(path: readonly string[]): 'items' | RefineFieldId | undefined {
  const head = path[path.indexOf('selectors') + 1];
  if (head === 'items') return 'items';
  return REFINE_FIELDS.find((field) => FIELD_WIRE[field].key === head);
}
