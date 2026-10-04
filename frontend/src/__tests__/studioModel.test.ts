import { describe, expect, it } from 'vitest';
import { emptyDraft, withFieldSelector } from '../studio/selectorDraft';
import {
  groupStudioIssues,
  normalizePreviewFailure,
  dormantStudioFields,
  studioFieldSurfaces,
  studioSavePresentation,
  suggestionResult,
  type StudioCandidates,
  type StudioIssue,
} from '../studio/studioModel';

const emptyCandidates: StudioCandidates = {
  items: [],
  fields: { title: [], link: [], published: [] },
};

describe('studioModel', () => {
  it('separates a valid empty suggestion from ranked candidates', () => {
    expect(suggestionResult(emptyCandidates)).toEqual({ status: 'empty' });

    const candidates: StudioCandidates = {
      ...emptyCandidates,
      fields: {
        ...emptyCandidates.fields,
        title: [{ selector: 'h2', sample: 'Headline' }],
      },
    };
    expect(suggestionResult(candidates)).toEqual({ status: 'ready', candidates });
  });

  it('groups issues by the editor control that owns them', () => {
    const issues: readonly StudioIssue[] = [
      { path: ['selectors', 'items', 'selector'], code: 'constraint', message: 'items' },
      { path: ['selectors', 'items', 'enhance'], code: 'constraint', message: 'enhance' },
      { path: ['selectors', 'url', 'selector'], code: 'constraint', message: 'link' },
      { path: ['selectors', 'pagination'], code: 'constraint', message: 'hidden' },
    ];

    const grouped = groupStudioIssues(issues);

    expect(grouped.items.map(({ message }) => message)).toEqual(['items']);
    expect(grouped.enhance.map(({ message }) => message)).toEqual(['enhance']);
    expect(grouped.fields.link.map(({ message }) => message)).toEqual(['link']);
    expect(grouped.hidden.map(({ message }) => message)).toEqual(['hidden']);
  });

  it('projects optional fields from selector, candidate, issue, and manual evidence', () => {
    const draft = withFieldSelector(emptyDraft(), 'title', 'h2');
    const suggestion = suggestionResult({
      ...emptyCandidates,
      fields: {
        ...emptyCandidates.fields,
        link: [{ selector: 'a', sample: 'Link' }],
      },
    });
    const issues = groupStudioIssues([
      { path: ['selectors', 'published_at'], code: 'missing_key', message: 'published' },
    ]);

    expect(studioFieldSurfaces(draft, suggestion, issues, new Set(['link']))).toEqual({
      title: { status: 'visible', evidence: ['selector'] },
      link: { status: 'visible', evidence: ['candidate', 'manual'] },
      published: { status: 'visible', evidence: ['issue'] },
    });
    expect(studioFieldSurfaces(emptyDraft(), { status: 'empty' }, groupStudioIssues([]))).toEqual({
      title: { status: 'dormant' },
      link: { status: 'dormant' },
      published: { status: 'dormant' },
    });
    const emptySurfaces = studioFieldSurfaces(emptyDraft(), { status: 'empty' }, groupStudioIssues([]));
    expect(dormantStudioFields(emptySurfaces)).toEqual(['title', 'link', 'published']);
  });

  it('owns ready and unresolved Save presentation', () => {
    expect(studioSavePresentation('unresolved', true, false)).toEqual({
      enabled: true,
      className: 'btn btn--primary',
    });
    expect(studioSavePresentation('ready', true, false)).toEqual({
      enabled: false,
      className: 'btn btn--ghost',
    });
    expect(studioSavePresentation('ready', true, true)).toEqual({
      enabled: true,
      className: 'btn btn--primary',
    });
  });

  it('normalizes known and future preview failure codes without casting', () => {
    expect(normalizePreviewFailure(undefined)).toBeUndefined();
    expect(normalizePreviewFailure('min_items')).toEqual({ kind: 'known', code: 'min_items' });
    expect(normalizePreviewFailure('future_kind')).toEqual({ kind: 'unknown', code: 'future_kind' });
  });
});
