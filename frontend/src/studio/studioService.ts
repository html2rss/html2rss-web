/**
 * Studio transport — sole unwrap of `{ success, data }`.
 */
import type { ValidateFeedConfigResponses } from '../api/generated';
import { isAbortError, type HttpEnvelope } from '../api/http/client';
import { postPreviewFeed, postSuggestSelectors, postValidateFeed } from '../api/http/feeds';
import { COPY } from '../journey/copy';
import {
  draftFromSelectors,
  isPlainRecord,
  selectorsFromDraft,
  type StudioDraft,
  type StudioSelectors,
} from './selectorDraft';
import {
  normalizePreviewFailure,
  suggestionResult,
  type StudioCandidates,
  type StudioIssue,
  type StudioPreviewFailure,
  type StudioSuggestionResult,
} from './studioModel';

type GeneratedIssue = ValidateFeedConfigResponses[200]['data']['report']['issues'][number];
export type StudioIssueCode = GeneratedIssue['code'];

export interface StudioValidationOutcome {
  readonly valid: boolean;
  readonly issues: readonly StudioIssue[];
  readonly draft: StudioDraft | undefined;
  readonly yaml: string | undefined;
}

export interface StudioSampleItem {
  readonly title: string;
  readonly url: string | undefined;
  readonly publishedAt: string | undefined;
  readonly imageUrl: string | undefined;
}

export interface StudioPreview {
  readonly items: readonly StudioSampleItem[];
  readonly nativeFeedUrl: string | undefined;
  readonly failure: StudioPreviewFailure | undefined;
}

type StudioPayloadField =
  | 'report'
  | 'selectors'
  | 'yaml'
  | 'issues'
  | 'sample_items'
  | 'quality_report'
  | 'failure_kind'
  | 'candidates';

export class StudioRequestError extends Error {
  readonly field: StudioPayloadField | undefined;

  constructor(message: string, field?: StudioPayloadField) {
    super(message);
    this.name = 'StudioRequestError';
    this.field = field;
  }
}

function invalidStudioField(field: StudioPayloadField): never {
  throw new StudioRequestError(COPY.unableToCompleteCreation, field);
}

function expectRecord(value: unknown, field: StudioPayloadField): Record<string, unknown> {
  if (!isPlainRecord(value)) invalidStudioField(field);
  return value;
}

function expectString(value: unknown, field: StudioPayloadField): string {
  if (typeof value !== 'string') invalidStudioField(field);
  return value;
}

function expectArray(value: unknown, field: StudioPayloadField): readonly unknown[] {
  if (!Array.isArray(value)) invalidStudioField(field);
  return value;
}

function listedIssueCodes<const T extends readonly StudioIssueCode[]>(
  codes: [StudioIssueCode] extends [T[number]] ? T : never
): T {
  return codes;
}

const STUDIO_ISSUE_CODES = listedIssueCodes([
  'constraint',
  'invalid_value',
  'missing_key',
  'parse',
  'type_mismatch',
  'unknown_value',
]);

export function validateStudioSelectors(
  token: string,
  url: string,
  draft: StudioDraft,
  signal?: AbortSignal
): Promise<StudioValidationOutcome> {
  return validateStudio(token, url, selectorsFromDraft(draft), signal);
}

export async function previewStudioFeed(
  token: string,
  url: string,
  draft: StudioDraft,
  signal?: AbortSignal
): Promise<StudioPreview> {
  const data = await studioData(await postPreviewFeed(token, url, selectorsFromDraft(draft), signal));
  return parsePreview(data);
}

export async function suggestStudioSelectors(
  token: string,
  url: string,
  signal?: AbortSignal
): Promise<StudioSuggestionResult> {
  const data = await studioData(await postSuggestSelectors(token, url, signal));
  return parseSuggestion(data);
}

async function validateStudio(
  token: string,
  url: string,
  selectors: StudioSelectors,
  signal?: AbortSignal
): Promise<StudioValidationOutcome> {
  return parseValidation(await studioData(await postValidateFeed(token, url, selectors, signal)));
}

async function studioData(envelope: HttpEnvelope): Promise<unknown> {
  const payload = envelope.body;
  if (isAbortError(payload)) throw payload;
  if (!envelope.ok || !isPlainRecord(payload) || payload.success !== true) {
    throw new StudioRequestError(errorMessage(payload) ?? COPY.unableToCompleteCreation);
  }

  return payload.data;
}

function errorMessage(payload: unknown): string | undefined {
  if (!isPlainRecord(payload) || !isPlainRecord(payload.error)) return;
  const message = payload.error.message;
  return typeof message === 'string' && message.trim() ? message : undefined;
}

function parseValidation(data: unknown): StudioValidationOutcome {
  const root = expectRecord(data, 'report');
  const report = expectRecord(root.report, 'report');
  if (typeof report.success !== 'boolean') invalidStudioField('report');

  return {
    valid: report.success,
    issues: expectArray(report.issues, 'issues').map((item) => parseIssue(item)),
    draft: parseSelectorsField(root.selectors),
    yaml: parseYamlField(root.yaml),
  };
}

function parseSelectorsField(value: unknown): StudioDraft | undefined {
  if (isAbsent(value)) return;
  const draft = draftFromSelectors(value);
  if (!draft) invalidStudioField('selectors');
  return draft;
}

function parseYamlField(value: unknown): string | undefined {
  if (isAbsent(value)) return;
  return expectString(value, 'yaml');
}

function parseIssue(value: unknown): StudioIssue {
  const record = expectRecord(value, 'issues');
  const message = expectString(record.message, 'issues');
  const code = knownIssueCode(record.code);
  if (!code) invalidStudioField('issues');

  const path = Array.from(expectArray(record.path, 'issues'), (segment) => expectString(segment, 'issues'));
  return { path, code, message };
}

function knownIssueCode(value: unknown): StudioIssueCode | undefined {
  if (typeof value !== 'string') return;
  return STUDIO_ISSUE_CODES.find((code) => code === value);
}

function parsePreview(data: unknown): StudioPreview {
  const root = expectRecord(data, 'sample_items');
  if (typeof root.item_count !== 'number') invalidStudioField('sample_items');

  return {
    items: expectArray(root.sample_items, 'sample_items').map((item) => parseSampleItem(item)),
    nativeFeedUrl: parseNativeFeed(root.quality_report),
    failure: parseFailureKind(root.failure_kind),
  };
}

function parseSampleItem(value: unknown): StudioSampleItem {
  const record = expectRecord(value, 'sample_items');
  return {
    title: expectString(record.title, 'sample_items'),
    url: optionalText(record.url, 'sample_items'),
    publishedAt: optionalText(record.published_at, 'sample_items'),
    imageUrl: optionalImageUrl(record.image),
  };
}

function parseNativeFeed(value: unknown): string | undefined {
  if (isAbsent(value)) return;
  const report = expectRecord(value, 'quality_report');
  if (!Object.hasOwn(report, 'native_feed') || isAbsent(report.native_feed)) return;
  return optionalText(report.native_feed, 'quality_report');
}

function optionalImageUrl(value: unknown): string | undefined {
  if (typeof value !== 'string') return;
  const trimmed = value.trim();
  if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) return trimmed;
  return;
}

function optionalText(value: unknown, field: StudioPayloadField): string | undefined {
  if (isAbsent(value)) return;
  const trimmed = expectString(value, field).trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function parseFailureKind(value: unknown): StudioPreviewFailure | undefined {
  if (isAbsent(value)) return;
  return normalizePreviewFailure(expectString(value, 'failure_kind'));
}

function parseSuggestion(data: unknown): StudioSuggestionResult {
  const root = expectRecord(data, 'candidates');
  const buckets = expectRecord(root.candidates, 'candidates');
  const candidates: StudioCandidates = {
    items: parseCandidates(buckets.items, true),
    fields: {
      title: parseCandidates(buckets.title, false),
      link: parseCandidates(buckets.link, false),
      published: parseCandidates(buckets.published, false),
    },
  };
  return suggestionResult(candidates);
}

function parseCandidates(value: unknown, isItems: boolean): StudioCandidates['items'] {
  return expectArray(value, 'candidates').map((entry) => parseCandidate(entry, isItems));
}

function parseCandidate(value: unknown, isItems: boolean): StudioCandidates['items'][number] {
  const record = expectRecord(value, 'candidates');
  const allowedKeys = isItems ? new Set(['selector', 'enhance', 'sample']) : new Set(['selector', 'sample']);
  if (Object.keys(record).some((key) => !allowedKeys.has(key))) invalidStudioField('candidates');
  const selector = expectString(record.selector, 'candidates').trim();
  const sample = expectString(record.sample, 'candidates').trim();
  if (isItems && typeof record.enhance !== 'boolean') invalidStudioField('candidates');
  if (selector.length === 0 || sample.length === 0) invalidStudioField('candidates');
  return { selector, sample };
}

function isAbsent(value: unknown): boolean {
  return value === undefined || value === null;
}
