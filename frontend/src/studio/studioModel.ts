import { issuePlace, STUDIO_FIELDS, type StudioDraft, type StudioFieldId } from './selectorDraft';

export type StudioEditorMode = 'ready' | 'unresolved';

export interface StudioIssue {
  readonly path: readonly string[];
  readonly code: string;
  readonly message: string;
}

/** One ranked selector candidate. Best match is first in its bucket. */
export interface StudioFieldCandidate {
  readonly selector: string;
  readonly sample: string;
}
export interface StudioCandidates {
  readonly items: readonly StudioFieldCandidate[];
  readonly fields: Readonly<Record<StudioFieldId, readonly StudioFieldCandidate[]>>;
}

export type StudioSuggestionResult =
  { readonly status: 'empty' } | { readonly status: 'ready'; readonly candidates: StudioCandidates };

export type StudioSuggestionState =
  | StudioSuggestionResult
  | { readonly status: 'loading' }
  | { readonly status: 'failed'; readonly message: string };

export interface GroupedStudioIssues {
  readonly items: readonly StudioIssue[];
  readonly enhance: readonly StudioIssue[];
  readonly fields: Readonly<Record<StudioFieldId, readonly StudioIssue[]>>;
  readonly hidden: readonly StudioIssue[];
}

export type OptionalFieldEvidence = 'selector' | 'candidate' | 'issue' | 'manual';

export type OptionalFieldSurface =
  | { readonly status: 'dormant' }
  | { readonly status: 'visible'; readonly evidence: readonly OptionalFieldEvidence[] };

export type StudioFieldSurfaces = Readonly<Record<StudioFieldId, OptionalFieldSurface>>;

export interface StudioSavePresentation {
  readonly enabled: boolean;
  readonly className: 'btn btn--primary' | 'btn btn--ghost';
}

export type StudioPreviewFailure =
  | { readonly kind: 'known'; readonly code: 'execution' | 'min_items' }
  | { readonly kind: 'unknown'; readonly code: string };

export function suggestionResult(candidates: StudioCandidates): StudioSuggestionResult {
  if (
    candidates.items.length === 0 &&
    STUDIO_FIELDS.every((field) => candidates.fields[field].length === 0)
  ) {
    return { status: 'empty' };
  }
  return { status: 'ready', candidates };
}

export function groupStudioIssues(issues: readonly StudioIssue[]): GroupedStudioIssues {
  const items: StudioIssue[] = [];
  const enhance: StudioIssue[] = [];
  const fields: Record<StudioFieldId, StudioIssue[]> = {
    title: [],
    link: [],
    published: [],
  };
  const hidden: StudioIssue[] = [];

  for (const issue of issues) {
    addGroupedIssue(issue, { items, enhance, fields, hidden });
  }

  return { items, enhance, fields, hidden };
}

export function studioFieldSurfaces(
  draft: StudioDraft,
  suggestion: StudioSuggestionState,
  issues: GroupedStudioIssues,
  manualFields: ReadonlySet<StudioFieldId> = new Set()
): StudioFieldSurfaces {
  const surfaces: Record<StudioFieldId, OptionalFieldSurface> = {
    title: { status: 'dormant' },
    link: { status: 'dormant' },
    published: { status: 'dormant' },
  };

  for (const field of STUDIO_FIELDS) {
    const evidence: OptionalFieldEvidence[] = [];
    if (draft.fields[field].selector.trim()) evidence.push('selector');
    if (suggestion.status === 'ready' && suggestion.candidates.fields[field].length > 0) {
      evidence.push('candidate');
    }
    if (issues.fields[field].length > 0) evidence.push('issue');
    if (manualFields.has(field)) evidence.push('manual');
    surfaces[field] = evidence.length === 0 ? { status: 'dormant' } : { status: 'visible', evidence };
  }

  return surfaces;
}

/** Optional fields still waiting on selector, candidate, issue, or manual evidence. */
export function dormantStudioFields(surfaces: StudioFieldSurfaces): readonly StudioFieldId[] {
  return STUDIO_FIELDS.filter((field) => surfaces[field].status === 'dormant');
}

export function studioSavePresentation(
  mode: StudioEditorMode,
  canSave: boolean,
  isDirty: boolean
): StudioSavePresentation {
  const isPrimary = mode === 'unresolved' || isDirty;
  return {
    enabled: canSave && isPrimary,
    className: isPrimary ? 'btn btn--primary' : 'btn btn--ghost',
  };
}

export function normalizePreviewFailure(value: string | undefined): StudioPreviewFailure | undefined {
  const code = value?.trim();
  if (!code) return;
  if (code === 'execution' || code === 'min_items') return { kind: 'known', code };
  return { kind: 'unknown', code };
}

function addGroupedIssue(
  issue: StudioIssue,
  groups: {
    items: StudioIssue[];
    enhance: StudioIssue[];
    fields: Record<StudioFieldId, StudioIssue[]>;
    hidden: StudioIssue[];
  }
) {
  const place = issuePlace(issue.path);
  switch (place.kind) {
    case 'items': {
      groups.items.push(issue);
      return;
    }
    case 'enhance': {
      groups.enhance.push(issue);
      return;
    }
    case 'field': {
      groups.fields[place.field].push(issue);
      return;
    }
    case 'hidden': {
      groups.hidden.push(issue);
    }
  }
}
