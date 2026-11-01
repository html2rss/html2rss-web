import { COPY } from '../journey/copy';
import type { RefineFailureKind, RefineIssue } from './refineService';
import { issueField, type RefineFieldId } from './selectorDraft';

export const FIELD_LABELS: Record<'items' | RefineFieldId, string> = {
  items: COPY.refineItemsLabel,
  title: COPY.refineTitleLabel,
  link: COPY.refineLinkLabel,
  published: COPY.refinePublishedLabel,
};

/** One plain sentence that names the problem and the next step. */
export function describeFailure(kind: RefineFailureKind): string {
  switch (kind) {
    case 'schema': {
      return COPY.refineFailureSchema;
    }
    case 'execution': {
      return COPY.refineFailureExecution;
    }
    case 'min_items': {
      return COPY.refineFailureMinItems;
    }
    case 'quality': {
      return COPY.refineFailureQuality;
    }
  }
}

export function groupIssues(issues: readonly RefineIssue[]) {
  const groups: Partial<Record<'items' | RefineFieldId | 'other', RefineIssue[]>> = {};
  for (const issue of issues) {
    const place = issueField(issue.path) ?? 'other';
    (groups[place] ??= []).push(issue);
  }
  return groups;
}

export function describeIssue(issue: RefineIssue): string {
  return issue.message;
}
