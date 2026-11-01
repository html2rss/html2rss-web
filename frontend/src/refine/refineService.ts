import {
  buildCreateHeaders,
  normalizeFeedCreationErrorFromResponse,
  readJsonResponse,
  resolveApiUrl,
} from '../feeds/feedsService';
import type { RefineFieldId, RefineSelectors } from './selectorDraft';

export interface RefineCandidate {
  readonly selector: string;
  readonly sample: string;
  readonly enhance: boolean;
}

export interface RefineCandidates {
  /** The request strategy that fetched the page; replayed on previews so they do not re-run the fallback chain. */
  readonly strategy?: string;
  readonly items: readonly RefineCandidate[];
  readonly fields: Readonly<Record<RefineFieldId, readonly RefineCandidate[]>>;
}

export interface RefineIssue {
  readonly path: readonly string[];
  readonly message: string;
}

export type RefineFailureKind = 'schema' | 'execution' | 'min_items' | 'quality';

interface RefineSampleItem {
  readonly title: string;
  readonly url: string;
  /** Locale date of `published_at`, empty when the item has none. */
  readonly publishedLabel: string;
}

export interface RefinePreview {
  readonly itemCount: number;
  readonly items: readonly RefineSampleItem[];
  readonly failureKind?: RefineFailureKind;
}

const FAILURE_KINDS = new Set<string>(['schema', 'execution', 'min_items', 'quality']);

export async function suggestSelectors(url: string, token: string, signal?: AbortSignal) {
  return parseCandidates(await post('suggest_selectors', { url }, token, signal));
}

export async function validateSelectors(selectors: RefineSelectors, token: string, signal?: AbortSignal) {
  return parseIssues(await post('validate', { selectors }, token, signal));
}

export async function previewSelectors(
  url: string,
  selectors: RefineSelectors,
  token: string,
  signal?: AbortSignal,
  strategy?: string
) {
  return parsePreview(await post('preview', { url, selectors, strategy }, token, signal));
}

async function post(path: string, body: object, token: string, signal?: AbortSignal): Promise<unknown> {
  const response = await fetch(resolveApiUrl(`refine/${path}`), {
    method: 'POST',
    headers: buildCreateHeaders(token),
    body: JSON.stringify(body),
    signal,
  });
  const payload = await readJsonResponse<{ data?: unknown; error?: unknown }>(response);

  if (!response.ok) throw normalizeFeedCreationErrorFromResponse(response.status, payload?.error, payload);

  return payload?.data;
}

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {};
}

function asList(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function parseCandidateList(value: unknown): RefineCandidate[] {
  return asList(value).flatMap((entry) => {
    const { selector, sample, enhance } = asRecord(entry);
    if (typeof selector !== 'string' || !selector) return [];
    return [{ selector, sample: typeof sample === 'string' ? sample : '', enhance: enhance === true }];
  });
}

function parseCandidates(data: unknown): RefineCandidates {
  const { candidates, strategy } = asRecord(data);
  const buckets = asRecord(candidates);
  return {
    strategy: typeof strategy === 'string' ? strategy : undefined,
    items: parseCandidateList(buckets.items),
    fields: {
      title: parseCandidateList(buckets.title),
      link: parseCandidateList(buckets.link),
      published: parseCandidateList(buckets.published),
    },
  };
}

function parseIssues(data: unknown): RefineIssue[] {
  const { report } = asRecord(data);
  return asList(asRecord(report).issues).flatMap((issue) => {
    const { path, message } = asRecord(issue);
    if (typeof message !== 'string') return [];
    return [{ path: asList(path).filter((part): part is string => typeof part === 'string'), message }];
  });
}

function dateLabel(value: unknown): string {
  const date = typeof value === 'string' ? new Date(value) : undefined;
  return date && !Number.isNaN(date.getTime())
    ? date.toLocaleDateString(undefined, { dateStyle: 'medium' })
    : '';
}

function parsePreview(data: unknown): RefinePreview {
  const { item_count: itemCount, sample_items: samples, failure_kind: kind } = asRecord(data);
  return {
    itemCount: typeof itemCount === 'number' ? itemCount : 0,
    items: asList(samples).flatMap((sample) => {
      const { title, url, published_at: publishedAt } = asRecord(sample);
      if (typeof title !== 'string') return [];
      return [{ title, url: typeof url === 'string' ? url : '', publishedLabel: dateLabel(publishedAt) }];
    }),
    failureKind:
      typeof kind === 'string' && FAILURE_KINDS.has(kind) ? (kind as RefineFailureKind) : undefined,
  };
}
